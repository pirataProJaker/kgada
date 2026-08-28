extends Node3D
## Streaming de chunks de terreno (Fase 1.5): genera/descarga chunks segun la
## posicion del jugador local, en vez de un unico chunk fijo. Cada chunk es
## deterministico (mismo seed + coordenadas -> mismo terreno), asi que en
## multijugador cada peer lo genera localmente sin transmitir geometria por
## red (ver roadmap: decision tomada desde la planeacion inicial).

# resolution=17 -> 16 celdas por eje. (resolution - 1) * voxel_size debe ser
# el tamano de chunk exacto para que el ultimo punto de un chunk coincida en
# el mundo con el primer punto del siguiente (sin huecos ni costuras).
const CHUNK_RESOLUTION := 17
const VOXEL_SIZE := 2.5
const CHUNK_WORLD_SIZE := (CHUNK_RESOLUTION - 1) * VOXEL_SIZE # 40.0
const EDITOR_CHUNKS_PER_FRAME := 2
const VIEW_DISTANCE_CHUNKS := 3 # radio en chunks alrededor del jugador (7x7 = 49 chunks)
const DEFAULT_WORLD_SEED := 1

const PSX_SHADER := preload("res://shaders/psx_vertex_snap.gdshader")

const LOW_COLOR := Color(0.3, 0.5, 0.25)
const MID_COLOR := Color(0.45, 0.43, 0.4)
const HIGH_COLOR := Color(0.92, 0.94, 0.97)
const GRADIENT_LOW_HEIGHT := 14.0
const GRADIENT_MID_HEIGHT := 24.0
const GRADIENT_HIGH_HEIGHT := 32.0
const TERRAIN_GRID_PRECISION := 260

# Vegetacion (tree_pack_1.1): solo se coloca en zona verde (por debajo de
# VEGETATION_MAX_HEIGHT, la misma zona "llana" del gradiente de color) y en
# pendientes razonables (evita arboles incrustados en laderas empinadas).
# Las texturas se asignan a mano por numero (treeXX.fbx <-> treeXX.png) en
# vez de depender del importador FBX para vincularlas (viven en carpetas
# separadas y el FBX no siempre trae la ruta correcta a la textura).
const TREE_MODELS_DIR := "res://assets/tree_pack_1.1/tree_pack_1.1/models/"
const TREE_TEXTURES_DIR := "res://assets/tree_pack_1.1/tree_pack_1.1/textures/"
const TREE_MODEL_COUNT := 36
const BUSH_MODEL_COUNT := 8
const TREES_PER_CHUNK := 14
const BUSHES_PER_CHUNK := 10
const VEGETATION_MAX_HEIGHT := 18.0
const VEGETATION_MIN_SLOPE_DOT := 0.7 # normal.dot(UP), mas alto = requiere mas plano
const VEGETATION_MARGIN := 3.0 # no colocar pegado al borde del chunk
# Si los modelos se ven gigantes/diminutos al abrir el proyecto (comun con
# FBX exportados en otra unidad, ej. centimetros), ajusta este multiplicador.
const VEGETATION_SCALE_MULTIPLIER := 1.0

const CHOPPABLE_TREE_SCRIPT := preload("res://world/choppable_tree.gd")
const TREE_TRUNK_RADIUS := 0.35 # aproximado (no exacto), alcanza para bloquear/golpear el tronco
const TREE_COLLISION_HEIGHT_RATIO := 0.65 # cobertura vertical relativa a la altura visual total - le alcanza a la altura de la camara del jugador

var _loaded_chunks: Dictionary = {} # Vector2i -> MeshInstance3D
var _ready_chunks: Dictionary = {} # Vector2i -> true, colision activa
var _world_seed := DEFAULT_WORLD_SEED
var _generator = null
var _local_player: Node3D = null
var _last_player_chunk := Vector2i(999999, 999999) # fuerza la primera carga
var _tree_scenes: Array[PackedScene] = []

# Zona de aplanado de la ciudad procedural (ver CityWorldSpawner, que la
# registra UNA vez al iniciar el mundo real, antes de que el jugador pueda
# alejarse lo suficiente para necesitar esos chunks). _city_inner_radius
# <= 0.0 significa "sin ciudad registrada todavia" - generate_chunk() en
# Rust interpreta eso como "sin aplanado", terreno 100% natural.
var _city_center := Vector2.ZERO
var _city_inner_radius := 0.0
var _city_outer_radius := 0.0
var _city_flat_height := 0.0
var _bush_scenes: Array[PackedScene] = []
var _tree_textures: Array[Texture2D] = []
var _bush_textures: Array[Texture2D] = []

# Generacion en hilo aparte (WorkerThreadPool). Requiere que rust_core se
# haya compilado con la feature "experimental-threads" en Cargo.toml - sin
# ella, esto crashea el juego casi de inmediato (ver nota en _load_chunk).
var _pending_task_ids: Dictionary = {} # Vector2i -> int (WorkerThreadPool task id)
var _pending_results: Dictionary = {} # Vector2i -> Dictionary (resultado crudo de generate_chunk)
var _results_mutex := Mutex.new()
var _editor_mode := false
var _heightfield_mode := false
var _editor_heightfield := PackedFloat32Array()
var _editor_grid_size := Vector2i(CHUNK_RESOLUTION, CHUNK_RESOLUTION)
var _editor_dirty_chunks: Dictionary = {} # Vector2i -> true
var _editor_render_queued := false


func _ready() -> void:
	if ClassDB.class_exists("TerrainGenerator"):
		_generator = ClassDB.instantiate("TerrainGenerator")
	else:
		push_warning("[chunk_manager] TerrainGenerator no esta disponible - compila rust_core (cargo build) y reabre el proyecto.")

	_load_vegetation_scenes()
	_create_safety_floor()


## Piso invisible infinito muy por debajo del terreno (que nunca baja de
## ~y=8). Con la generacion de chunks en hilo aparte hay una ventana de
## tiempo en la que el jugador puede estar parado sobre un chunk que aun no
## termino de generarse (sin colision todavia) - sin este piso, se cae al
## vacio. Con el piso, en el peor caso lo atraviesa brevemente el terreno
## visual pero queda sostenido hasta que la colision real este lista.
func _create_safety_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "SafetyFloor"
	var floor_collision := CollisionShape3D.new()
	var floor_shape := WorldBoundaryShape3D.new()
	floor_shape.plane = Plane(Vector3.UP, -5.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	add_child(floor_body)


func set_local_player(player: Node3D) -> void:
	_local_player = player


func set_world_seed(world_seed: int) -> void:
	_world_seed = world_seed


## Modo editor: usa el mismo generador, material, malla y colision del mundo
## jugable, pero con una o varias zonas editables alimentadas por una
## cuadricula global de alturas. Cada zona se divide en chunks reales y no
## crea cubos de reemplazo ni una superficie paralela.
func configure_editor(
	heightfield: PackedFloat32Array,
	grid_size: Vector2i = Vector2i(CHUNK_RESOLUTION, CHUNK_RESOLUTION)
) -> void:
	_editor_mode = true
	_configure_heightfield(heightfield, grid_size)


## Modo de prueba: conserva el gameplay del mundo, pero sustituye el terreno
## procedural por el heightfield guardado por el editor. Se bloquea el
## streaming para que el jugador juegue sobre exactamente el mapa probado.
func configure_playtest(
	heightfield: PackedFloat32Array,
	grid_size: Vector2i = Vector2i(CHUNK_RESOLUTION, CHUNK_RESOLUTION)
) -> void:
	_editor_mode = false
	_configure_heightfield(heightfield, grid_size)


func _configure_heightfield(heightfield: PackedFloat32Array, grid_size: Vector2i) -> void:
	_heightfield_mode = true
	_local_player = null
	_editor_heightfield = heightfield.duplicate()
	_editor_grid_size = Vector2i(maxi(grid_size.x, 2), maxi(grid_size.y, 2))
	_editor_dirty_chunks.clear()
	for coord in _loaded_chunks.keys().duplicate():
		var chunk: MeshInstance3D = _loaded_chunks[coord]
		if is_instance_valid(chunk):
			chunk.free()
		_loaded_chunks.erase(coord)
		_ready_chunks.erase(coord)
	_mark_all_editor_chunks_dirty()
	_queue_editor_render()


## Solicita una regeneracion coalescida. Varias pinceladas en el mismo frame
## solo producen una malla nueva, manteniendo la sensacion de edicion en vivo.
func update_editor_heightfield(
	heightfield: PackedFloat32Array,
	sample_min: Vector2i = Vector2i(-1, -1),
	sample_max: Vector2i = Vector2i(-1, -1)
) -> void:
	if not _editor_mode:
		return
	_editor_heightfield = heightfield.duplicate()
	if sample_min.x < 0 or sample_min.y < 0 or sample_max.x < sample_min.x or sample_max.y < sample_min.y:
		_mark_all_editor_chunks_dirty()
	else:
		_mark_editor_chunks_for_sample_bounds(sample_min, sample_max)
	_queue_editor_render()


func _queue_editor_render() -> void:
	if _editor_render_queued:
		return
	_editor_render_queued = true
	call_deferred("_render_editor_heightfield")


func _render_editor_heightfield() -> void:
	_editor_render_queued = false
	if not _heightfield_mode or _generator == null or _editor_heightfield.is_empty():
		return
	if _editor_grid_size.x < 2 or _editor_grid_size.y < 2:
		return

	var chunk_stride := CHUNK_RESOLUTION - 1
	var rendered_chunks := 0
	for coord_variant in _editor_dirty_chunks.keys():
		if rendered_chunks >= EDITOR_CHUNKS_PER_FRAME:
			break
		var coord: Vector2i = coord_variant
		_editor_dirty_chunks.erase(coord)
		var old_chunk: MeshInstance3D = _loaded_chunks.get(coord)
		if old_chunk != null and is_instance_valid(old_chunk):
			old_chunk.free()
		_loaded_chunks.erase(coord)

		var local_heightfield := _extract_editor_chunk_heightfield(coord, chunk_stride)
		var data: Dictionary = _generator.generate_chunk_from_height_field(
			CHUNK_RESOLUTION, VOXEL_SIZE, local_heightfield
		)
		if data.is_empty():
			push_warning("[chunk_manager] El chunk editado %s devolvio datos vacios." % coord)
			continue
		_loaded_chunks[coord] = _build_chunk_mesh(coord, data)
		rendered_chunks += 1

	if not _editor_dirty_chunks.is_empty():
		_queue_editor_render()


func _mark_all_editor_chunks_dirty() -> void:
	var chunk_stride := CHUNK_RESOLUTION - 1
	var chunk_count_x := ceili(float(_editor_grid_size.x - 1) / float(chunk_stride))
	var chunk_count_z := ceili(float(_editor_grid_size.y - 1) / float(chunk_stride))
	for chunk_z in chunk_count_z:
		for chunk_x in chunk_count_x:
			_editor_dirty_chunks[Vector2i(chunk_x, chunk_z)] = true


func _mark_editor_chunks_for_sample_bounds(sample_min: Vector2i, sample_max: Vector2i) -> void:
	var chunk_stride := CHUNK_RESOLUTION - 1
	var safe_min := Vector2i(
		clampi(sample_min.x - 1, 0, _editor_grid_size.x - 1),
		clampi(sample_min.y - 1, 0, _editor_grid_size.y - 1),
	)
	var safe_max := Vector2i(
		clampi(sample_max.x + 1, 0, _editor_grid_size.x - 1),
		clampi(sample_max.y + 1, 0, _editor_grid_size.y - 1),
	)
	var first_chunk := Vector2i(
		floori(float(safe_min.x) / float(chunk_stride)),
		floori(float(safe_min.y) / float(chunk_stride)),
	)
	var last_chunk := Vector2i(
		floori(float(safe_max.x) / float(chunk_stride)),
		floori(float(safe_max.y) / float(chunk_stride)),
	)
	for chunk_z in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x in range(first_chunk.x, last_chunk.x + 1):
			_editor_dirty_chunks[Vector2i(chunk_x, chunk_z)] = true


func _extract_editor_chunk_heightfield(coord: Vector2i, chunk_stride: int) -> PackedFloat32Array:
	var local_heightfield := PackedFloat32Array()
	local_heightfield.resize(CHUNK_RESOLUTION * CHUNK_RESOLUTION)
	for local_z in CHUNK_RESOLUTION:
		var global_z := mini(coord.y * chunk_stride + local_z, _editor_grid_size.y - 1)
		for local_x in CHUNK_RESOLUTION:
			var global_x := mini(coord.x * chunk_stride + local_x, _editor_grid_size.x - 1)
			var global_index := global_x + global_z * _editor_grid_size.x
			var local_index := local_x + local_z * CHUNK_RESOLUTION
			local_heightfield[local_index] = _editor_heightfield[global_index] if global_index < _editor_heightfield.size() else 10.0
	return local_heightfield


## API publica: CityWorldSpawner la llama UNA vez, al iniciar el mundo real,
## para que todo chunk generado desde ese momento en adelante aplane su
## terreno cerca de (center.x, center.y) hacia flat_height - ver el comentario
## de _city_inner_radius y la logica de mezcla en TerrainGenerator.generate_chunk
## (Rust). Debe llamarse ANTES de que el jugador pueda alejarse lo suficiente
## para que sus chunks cercanos ya se hayan generado sin aplanar.
func set_city_flatten_zone(center: Vector2, inner_radius: float, outer_radius: float, flat_height: float) -> void:
	_city_center = center
	_city_inner_radius = inner_radius
	_city_outer_radius = outer_radius
	_city_flat_height = flat_height


## API publica: altura NATURAL del terreno (sin aplanado de ciudad) en un
## punto del mundo - usada por CityWorldSpawner para decidir a que altura
## poner la plataforma plana de la ciudad, para que combine con el terreno
## real de alrededor en vez de una altura arbitraria.
func sample_terrain_height(world_x: float, world_z: float) -> float:
	if _generator == null:
		return 0.0
	return _generator.sample_height(_world_seed, world_x, world_z)


## API publica: permite a otros scripts (ej. world_test.gd para el spawn
## seguro) saber si el chunk que contiene una posicion ya tiene su malla y
## colision activas, sin depender de detalles internos (_loaded_chunks).
func is_chunk_loaded(coord: Vector2i) -> bool:
	return _ready_chunks.has(coord)


func is_position_ready(world_pos: Vector3) -> bool:
	return _ready_chunks.has(_world_to_chunk_coord(world_pos))


func world_to_chunk_coord(world_pos: Vector3) -> Vector2i:
	return _world_to_chunk_coord(world_pos)


func _process(_delta: float) -> void:
	_poll_pending_tasks()
	if _heightfield_mode:
		return

	if _local_player == null or _generator == null:
		return

	var player_chunk := _world_to_chunk_coord(_local_player.global_position)
	if player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk

	_update_chunks(player_chunk)


func _world_to_chunk_coord(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / CHUNK_WORLD_SIZE),
		floori(world_pos.z / CHUNK_WORLD_SIZE)
	)


func _update_chunks(center: Vector2i) -> void:
	var needed: Dictionary = {}

	for dz in range(-VIEW_DISTANCE_CHUNKS, VIEW_DISTANCE_CHUNKS + 1):
		for dx in range(-VIEW_DISTANCE_CHUNKS, VIEW_DISTANCE_CHUNKS + 1):
			var coord := Vector2i(center.x + dx, center.y + dz)
			needed[coord] = true
			if not _loaded_chunks.has(coord) and not _pending_task_ids.has(coord):
				_load_chunk(coord)

	for coord in _loaded_chunks.keys().duplicate():
		if not needed.has(coord):
			_unload_chunk(coord)


## Encola la generacion de un chunk en un hilo de WorkerThreadPool. No
## bloquea - el resultado se recoge despues en _poll_pending_tasks(). Esto
## SOLO es seguro porque rust_core se compila con la feature Cargo
## "experimental-threads" (ver rust_core/Cargo.toml) - sin ella, llamar a
## _generator.generate_chunk desde otro hilo crashea el juego casi de
## inmediato (nos paso, y se documenta ahi el porque).
func _load_chunk(coord: Vector2i) -> void:
	var origin_x := float(coord.x) * CHUNK_WORLD_SIZE
	var origin_z := float(coord.y) * CHUNK_WORLD_SIZE
	var world_seed := _world_seed
	# Se copian a variables locales (en el hilo principal) ANTES de crear el
	# closure, en vez de leer _city_* directo dentro de _generate_chunk_data_threaded
	# (que corre en un hilo de fondo) - evita cualquier ambiguedad sobre acceso
	# a campos del script entre hilos, igual que ya se hacia con origin_x/origin_z.
	var city_center := _city_center
	var city_inner_radius := _city_inner_radius
	var city_outer_radius := _city_outer_radius
	var city_flat_height := _city_flat_height

	var task_id := WorkerThreadPool.add_task(
		func() -> void: _generate_chunk_data_threaded(
			coord, origin_x, origin_z, world_seed, city_center, city_inner_radius, city_outer_radius, city_flat_height
		),
		true # high_priority: minimiza la ventana sin colision real bajo el jugador
	)
	_pending_task_ids[coord] = task_id


## Corre en un hilo de fondo (WorkerThreadPool). Solo hace calculo puro -
## nada de nodos, arbol de escena ni fisica aqui, eso no es seguro entre
## hilos ni siquiera con experimental-threads (esa feature solo cubre el
## acceso al objeto GDExtension, no al arbol de escena/fisica de Godot).
func _generate_chunk_data_threaded(
	coord: Vector2i,
	origin_x: float,
	origin_z: float,
	world_seed: int,
	city_center: Vector2,
	city_inner_radius: float,
	city_outer_radius: float,
	city_flat_height: float
) -> void:
	var data: Dictionary = _generator.generate_chunk(
		CHUNK_RESOLUTION, VOXEL_SIZE, world_seed, origin_x, origin_z,
		city_center.x, city_center.y, city_inner_radius, city_outer_radius, city_flat_height
	)

	_results_mutex.lock()
	_pending_results[coord] = data
	_results_mutex.unlock()


## Se llama cada frame desde _process, en el hilo principal: revisa que
## tareas de fondo ya terminaron y construye su malla/colision/vegetacion.
func _poll_pending_tasks() -> void:
	for coord in _pending_task_ids.keys().duplicate():
		var task_id: int = _pending_task_ids[coord]
		if not WorkerThreadPool.is_task_completed(task_id):
			continue

		WorkerThreadPool.wait_for_task_completion(task_id)
		_pending_task_ids.erase(coord)

		_results_mutex.lock()
		var data: Dictionary = _pending_results.get(coord, {})
		_pending_results.erase(coord)
		_results_mutex.unlock()

		_finish_chunk(coord, data)


func _is_chunk_needed(coord: Vector2i) -> bool:
	if _local_player == null:
		return false
	var center := _world_to_chunk_coord(_local_player.global_position)
	return abs(coord.x - center.x) <= VIEW_DISTANCE_CHUNKS and abs(coord.y - center.y) <= VIEW_DISTANCE_CHUNKS


## Trabajo que debe correr en el hilo principal: construir el ArrayMesh,
## agregarlo al arbol, crear la colision, y (con un frame de espera) la
## vegetacion. Si el jugador ya se alejo mientras se generaba, se descarta.
func _finish_chunk(coord: Vector2i, data: Dictionary) -> void:
	if data.is_empty() or not _is_chunk_needed(coord):
		return

	var origin_x := float(coord.x) * CHUNK_WORLD_SIZE
	var origin_z := float(coord.y) * CHUNK_WORLD_SIZE
	var mesh_instance := _build_chunk_mesh(coord, data)
	_loaded_chunks[coord] = mesh_instance

	# Se espera un frame de fisica para que la colision recien creada ya este
	# activa en el espacio fisico antes de lanzar los raycasts de vegetacion.
	await get_tree().physics_frame
	if not is_instance_valid(mesh_instance) or _loaded_chunks.get(coord) != mesh_instance:
		return # el chunk se descargo antes de que llegara este frame
	_ready_chunks[coord] = true
	_scatter_vegetation(coord, origin_x, origin_z, mesh_instance)


func _build_chunk_mesh(coord: Vector2i, data: Dictionary) -> MeshInstance3D:
	var origin_x := float(coord.x) * CHUNK_WORLD_SIZE
	var origin_z := float(coord.y) * CHUNK_WORLD_SIZE

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ShaderMaterial.new()
	material.shader = PSX_SHADER
	material.set_shader_parameter("grid_precision", TERRAIN_GRID_PRECISION)
	material.set_shader_parameter("use_height_gradient", true)
	material.set_shader_parameter("low_color", LOW_COLOR)
	material.set_shader_parameter("mid_color", MID_COLOR)
	material.set_shader_parameter("high_color", HIGH_COLOR)
	material.set_shader_parameter("gradient_low_height", GRADIENT_LOW_HEIGHT)
	material.set_shader_parameter("gradient_mid_height", GRADIENT_MID_HEIGHT)
	material.set_shader_parameter("gradient_high_height", GRADIENT_HIGH_HEIGHT)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainChunk_%d_%d" % [coord.x, coord.y]
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(origin_x, 0.0, origin_z)
	add_child(mesh_instance)
	mesh_instance.create_trimesh_collision()
	return mesh_instance


func _load_vegetation_scenes() -> void:
	for i in range(1, TREE_MODEL_COUNT + 1):
		var model_path := "%stree%02d.fbx" % [TREE_MODELS_DIR, i]
		var texture_path := "%stree%02d.png" % [TREE_TEXTURES_DIR, i]
		if ResourceLoader.exists(model_path):
			_tree_scenes.append(load(model_path))
			_tree_textures.append(load(texture_path) if ResourceLoader.exists(texture_path) else null)

	for i in range(1, BUSH_MODEL_COUNT + 1):
		var model_path := "%sbush%02d.fbx" % [TREE_MODELS_DIR, i]
		var texture_path := "%sbush%02d.png" % [TREE_TEXTURES_DIR, i]
		if ResourceLoader.exists(model_path):
			_bush_scenes.append(load(model_path))
			_bush_textures.append(load(texture_path) if ResourceLoader.exists(texture_path) else null)

	if _tree_scenes.is_empty() and _bush_scenes.is_empty():
		push_warning("[chunk_manager] No se encontraron modelos en tree_pack_1.1 - revisa que la carpeta assets/tree_pack_1.1 exista.")


func _scatter_vegetation(coord: Vector2i, origin_x: float, origin_z: float, parent: Node3D) -> void:
	if _tree_scenes.is_empty() and _bush_scenes.is_empty():
		return

	# RNG determinista por chunk: mismas coordenadas + semilla -> misma
	# vegetacion siempre (consistente entre recargas y entre peers en red).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(coord.x, coord.y)) ^ _world_seed

	var space_state := get_world_3d().direct_space_state

	for i in TREES_PER_CHUNK:
		var wx := origin_x + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
		var wz := origin_z + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
		if _is_inside_city_zone(wx, wz):
			continue
		_try_place_vegetation(wx, wz, rng, _tree_scenes, _tree_textures, space_state, parent, true)

	for i in BUSHES_PER_CHUNK:
		var wx := origin_x + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
		var wz := origin_z + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
		if _is_inside_city_zone(wx, wz):
			continue
		_try_place_vegetation(wx, wz, rng, _bush_scenes, _bush_textures, space_state, parent, false)


## El bosque silvestre no sabe nada de calles/lotes/casas - solo tira un
## rayo y revisa altura/pendiente. Sin este corte, cualquier chunk que caiga
## dentro de la plataforma aplanada de la ciudad (ver set_city_flatten_zone)
## termina lleno de arboles silvestres en medio de las calles, porque el
## terreno ahi es perfectamente plano y "valido" para el chequeo de pendiente.
## CityDecoration ya coloca sus propios arboles a mano en patios/lotes
## baldios respetando calles/casas/rejas - este corte simplemente le cede el
## paso dentro de inner_radius (el area real de la ciudad, sin contar el
## margen de transicion hacia el terreno natural).
func _is_inside_city_zone(world_x: float, world_z: float) -> bool:
	if _city_inner_radius <= 0.0:
		return false
	var dx := world_x - _city_center.x
	var dz := world_z - _city_center.y
	return dx * dx + dz * dz <= _city_inner_radius * _city_inner_radius


func _try_place_vegetation(
	world_x: float,
	world_z: float,
	rng: RandomNumberGenerator,
	pool: Array[PackedScene],
	texture_pool: Array[Texture2D],
	space_state: PhysicsDirectSpaceState3D,
	parent: Node3D,
	add_collision: bool
) -> void:
	if pool.is_empty():
		return

	var from := Vector3(world_x, 200.0, world_z)
	var to := Vector3(world_x, -50.0, world_z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]

	if hit_position.y > VEGETATION_MAX_HEIGHT:
		return # zona rocosa/nevada, sin vegetacion
	if hit_normal.dot(Vector3.UP) < VEGETATION_MIN_SLOPE_DOT:
		return # pendiente demasiado inclinada

	var index := rng.randi_range(0, pool.size() - 1)
	var scene: PackedScene = pool[index]
	var instance: Node3D = scene.instantiate()
	parent.add_child(instance)
	instance.global_position = hit_position
	instance.rotate_y(rng.randf_range(0.0, TAU))
	instance.scale = Vector3.ONE * rng.randf_range(0.8, 1.3) * VEGETATION_SCALE_MULTIPLIER

	if add_collision:
		_add_tree_collision(instance)

	var texture: Texture2D = texture_pool[index] if index < texture_pool.size() else null
	if texture != null:
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # consistente con el look PSX del resto del juego
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR # por si las texturas de hojas usan alpha
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED # tarjetas de hojas/ramas visibles desde ambos lados
		_apply_vegetation_material(instance, material)


## Aplica el material recursivamente a todos los MeshInstance3D del modelo
## instanciado (los .fbx pueden traer varias mallas/sub-nodos).
func _apply_vegetation_material(node: Node, material: StandardMaterial3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = material
		_apply_vegetation_material(child, material)


## Agrega la colision "talable" (ChoppableTree, ver world/choppable_tree.gd)
## a un arbol silvestre recien colocado - MeleeController golpea con un
## raycast corto que necesita un StaticBody3D real para llamar
## take_damage(). Se aproxima el tronco con un cilindro (no hace falta la
## forma exacta del follaje, solo bloquear/permitir el golpe) medido a
## partir del AABB visual real del modelo ya colocado (instance.scale ya
## aplicado en este punto, asi que se mide en espacio de mundo y se
## convierte de vuelta a espacio local del arbol).
func _add_tree_collision(tree_instance: Node3D) -> void:
	var world_aabb := _compute_world_aabb(tree_instance)
	if world_aabb.size.y <= 0.01:
		return
	var local_aabb: AABB = tree_instance.global_transform.affine_inverse() * world_aabb
	var height := maxf(local_aabb.size.y * TREE_COLLISION_HEIGHT_RATIO, 0.5)

	var body := CHOPPABLE_TREE_SCRIPT.new() as StaticBody3D
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TREE_TRUNK_RADIUS
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3(
		local_aabb.position.x + local_aabb.size.x * 0.5,
		height * 0.5,
		local_aabb.position.z + local_aabb.size.z * 0.5
	)
	body.add_child(shape)
	tree_instance.add_child(body)


## Combina el AABB (en espacio de MUNDO) de todos los VisualInstance3D bajo
## `node` - usa global_transform de cada uno en vez de acumular transforms
## relativos a mano, mas simple porque este arbol ya esta en el arbol de
## escena (global_transform valido) cuando se llama.
func _compute_world_aabb(node: Node) -> AABB:
	var result := AABB()
	var has_result := false
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		var world_aabb: AABB = visual.global_transform * visual.get_aabb()
		result = world_aabb
		has_result = true
	for child in node.get_children():
		var child_aabb := _compute_world_aabb(child)
		if child_aabb.size == Vector3.ZERO:
			continue
		if not has_result:
			result = child_aabb
			has_result = true
		else:
			result = result.merge(child_aabb)
	return result



func _unload_chunk(coord: Vector2i) -> void:
	var mesh_instance: MeshInstance3D = _loaded_chunks[coord]
	mesh_instance.queue_free()
	_loaded_chunks.erase(coord)
	_ready_chunks.erase(coord)
