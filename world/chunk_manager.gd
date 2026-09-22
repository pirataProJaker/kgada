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
const GRADIENT_LOW_HEIGHT := 8.0
const GRADIENT_MID_HEIGHT := 13.0
const GRADIENT_HIGH_HEIGHT := 18.0
const TERRAIN_GRID_PRECISION := 260
const TERRAIN_PIXEL_SIZE := 0.08

# Vegetación: Los árboles y pinos se generan proceduralmente con ProceduralTree.
# Los arbustos usan modelos FBX de tree_pack_1.1.
const BUSH_MODELS_DIR := "res://assets/tree_pack_1.1/tree_pack_1.1/models/"
const BUSH_TEXTURES_DIR := "res://assets/tree_pack_1.1/tree_pack_1.1/textures/"
const BUSH_MODEL_COUNT := 8
const TREES_PER_CHUNK := 8
const BUSHES_PER_CHUNK := 6
const VEGETATION_MAX_HEIGHT := 22.0
const VEGETATION_MIN_SLOPE_DOT := 0.7 # normal.dot(UP), mas alto = requiere mas plano
const VEGETATION_MARGIN := 3.0 # no colocar pegado al borde del chunk
# Si los modelos se ven gigantes/diminutos al abrir el proyecto (comun con
# FBX exportados en otra unidad, ej. centimetros), ajusta este multiplicador.
const VEGETATION_SCALE_MULTIPLIER := 1.0

const CHOPPABLE_TREE_SCRIPT := preload("res://world/choppable_tree.gd")
const ProceduralTreeProfiles = preload("res://world/procedural_trees/procedural_tree_profiles.gd")
const ProceduralTreeGenerator = preload("res://world/procedural_trees/procedural_tree_generator.gd")
const ProceduralTreeMaterials = preload("res://world/procedural_trees/procedural_tree_materials.gd")
const TREE_TRUNK_RADIUS := 0.35 # aproximado (no exacto), alcanza para bloquear/golpear el tronco
const TREE_COLLISION_HEIGHT_RATIO := 0.65 # cobertura vertical relativa a la altura visual total - le alcanza a la altura de la camara del jugador
const TREE_VARIANTS_PER_SPECIES := 35
const ChunkProfiler = preload("res://autoload/chunk_profiler.gd")
const PSXGrass = preload("res://world/vegetation/grass/psx_grass.gd")
const WildDaisy = preload("res://world/vegetation/daisy/wild_daisy.gd")
const WildLavender = preload("res://world/vegetation/lavender/wild_lavender.gd")
const WildPoppy = preload("res://world/vegetation/poppy/wild_poppy.gd")
const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")
const VEGETATION_SHADER = preload("res://world/vegetation/common/vegetation_shader.gdshader")

## Diagnóstico de rendimiento: desactiva totalmente la generación y colocación de árboles
@export var enable_trees: bool = true
## Fuerza los árboles detallados completos (STANDARD) con copas ricas multicapa
@export var force_detailed_trees: bool = true
## Diagnóstico de rendimiento: desactiva colocación de arbustos
@export var enable_bushes: bool = false
## Diagnóstico de rendimiento: desactiva colocación de pasto FBX (PSXGrass)
@export var enable_grass: bool = true
## Diagnóstico de rendimiento: desactiva colocación de flores silvestres (Margaritas, Lavandas, Amapolas)
@export var enable_wildflowers: bool = true
## Diagnóstico de rendimiento: desactiva colocación de rosales silvestres con LODs (ProceduralFlower)
@export var enable_roses: bool = true

var _tree_archetype_pool: Dictionary = {} # profile_id -> Array[ProceduralTreeGenerator.TreeGenerationResult]
var _rose_archetype_pool: Array[ProceduralFlower.FlowerGenerationPackage] = []
var _bush_materials_cache: Dictionary = {} # index -> StandardMaterial3D (cache global para evitar allocs en streaming)

var _loaded_chunks: Dictionary = {} # Vector2i -> MeshInstance3D
var _ready_chunks: Dictionary = {} # Vector2i -> true, colision activa
var _world_seed := DEFAULT_WORLD_SEED
var _generator = null
var _local_player: Node3D = null
var _last_player_chunk := Vector2i(999999, 999999) # fuerza la primera carga

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

# Colas progresivas para suavizado de carga/descarga (evita cualquier freeze o caida de FPS):
var _chunks_to_load: Array[Vector2i] = []
var _chunks_to_unload: Array[Vector2i] = []
var _tree_attach_queue: Array[Dictionary] = []
var _bush_attach_queue: Array[Dictionary] = []
var _rose_attach_queue: Array[Dictionary] = []
var _chunk_vegetation_data: Dictionary = {} # Vector2i -> Dictionary (tree, bush, rose, grass y flower requests precalculados)
var _chunk_has_trees: Dictionary = {} # Vector2i -> bool
var _chunk_has_bushes: Dictionary = {} # Vector2i -> bool
var _chunk_has_roses: Dictionary = {} # Vector2i -> bool
var _chunk_has_grass: Dictionary = {} # Vector2i -> bool
var _chunk_has_flowers: Dictionary = {} # Vector2i -> bool
var _grass_mesh_cache: Mesh = null
var _flower_mesh_cache: Dictionary = {} # String -> Mesh
var _flower_material: ShaderMaterial = null
var _shared_terrain_material: ShaderMaterial = null


## Ruido determinístico de biomas (idéntico al shader psx_vertex_snap.gdshader):
## < 0.12 = Pradera / Meadow abierta (césped denso, flores abundantes, pocos árboles)
## 0.12 a 0.40 = Transición / Arboleda (copses de árboles agrupados, césped medio)
## >= 0.40 = Bosque denso (masa forestal continua de 10-14 árboles, mantillo de tierra)
static func get_biome_noise(wx: float, wz: float) -> float:
	var b1 = sin(wx * 0.018 + sin(wz * 0.014) * 1.2)
	var b2 = sin(wz * 0.016 + sin(wx * 0.012) * 1.2)
	return (b1 + b2) * 0.5


func _get_grass_mesh() -> Mesh:
	if _grass_mesh_cache == null:
		_grass_mesh_cache = PSXGrass.create_mesh(0.38)
	return _grass_mesh_cache


func _get_flower_mesh(type: String) -> Mesh:
	if not _flower_mesh_cache.has(type):
		match type:
			"daisy":
				_flower_mesh_cache["daisy"] = WildDaisy.create_mesh(12345)
			"lavender":
				_flower_mesh_cache["lavender"] = WildLavender.create_mesh(23456)
			"poppy":
				_flower_mesh_cache["poppy"] = WildPoppy.create_mesh(34567)
	return _flower_mesh_cache.get(type)


func _get_flower_material() -> ShaderMaterial:
	if _flower_material == null:
		_flower_material = ShaderMaterial.new()
		_flower_material.shader = VEGETATION_SHADER
	return _flower_material


func _ready() -> void:
	_init_shared_terrain_material()
	ProceduralTreeMaterials.preload_all_materials()
	_pregenerate_tree_archetypes()
	_pregenerate_rose_archetypes()
	if ClassDB.class_exists("TerrainGenerator"):
		_generator = ClassDB.instantiate("TerrainGenerator")
	else:
		push_warning("[chunk_manager] TerrainGenerator no esta disponible - compila rust_core (cargo build) y reabre el proyecto.")

	_load_vegetation_scenes()
	_create_safety_floor()


func _pregenerate_rose_archetypes() -> void:
	if not enable_roses:
		return
	var t0 := Time.get_ticks_msec()
	for i in range(18):
		var seed_val := hash("rose_archetype") ^ (_world_seed * 1009) ^ (i * 7919)
		var color_idx := i % 6
		var growth := 1.0
		var pkg: ProceduralFlower.FlowerGenerationPackage = ProceduralFlower.generate_package("shrub_rose", seed_val, growth, color_idx)
		_rose_archetype_pool.append(pkg)
	var elapsed := Time.get_ticks_msec() - t0
	print("[chunk_manager] Catálogo de %d rosales procedurales (LOD0/1/2) precalculado en %d ms" % [_rose_archetype_pool.size(), elapsed])


func _init_shared_terrain_material() -> void:
	if _shared_terrain_material != null:
		return
	_shared_terrain_material = ShaderMaterial.new()
	_shared_terrain_material.shader = PSX_SHADER
	_shared_terrain_material.set_shader_parameter("grid_precision", TERRAIN_GRID_PRECISION)
	_shared_terrain_material.set_shader_parameter("use_height_gradient", true)
	_shared_terrain_material.set_shader_parameter("low_color", LOW_COLOR)
	_shared_terrain_material.set_shader_parameter("mid_color", MID_COLOR)
	_shared_terrain_material.set_shader_parameter("high_color", HIGH_COLOR)
	_shared_terrain_material.set_shader_parameter("gradient_low_height", GRADIENT_LOW_HEIGHT)
	_shared_terrain_material.set_shader_parameter("gradient_mid_height", GRADIENT_MID_HEIGHT)
	_shared_terrain_material.set_shader_parameter("gradient_high_height", GRADIENT_HIGH_HEIGHT)

	# Terreno retro PSX con píxeles pequeños y pasto exclusivamente verde
	_shared_terrain_material.set_shader_parameter("use_pixel_terrain", true)
	_shared_terrain_material.set_shader_parameter("pixel_size", TERRAIN_PIXEL_SIZE)
	_shared_terrain_material.set_shader_parameter("use_vertex_dirt", false)
	_shared_terrain_material.set_shader_parameter("use_procedural_biomes", true)


## Pre-genera un catalogo fijo de variaciones procedurales por cada especie al iniciar el mundo.
## Elimina completamente el calculo de ramas y mallas durante la exploracion de chunks (0 ms de coste CPU en streaming).
func _pregenerate_tree_archetypes() -> void:
	if not enable_trees:
		print("[chunk_manager] Generación de árboles deshabilitada para pruebas de rendimiento.")
		return
	var sm = get_node_or_null("/root/SettingsManager")
	var use_low_spec := false
	if not force_detailed_trees and sm and sm.has_method("is_low_spec_foliage"):
		use_low_spec = sm.is_low_spec_foliage()
	
	var mode: int = ProceduralTreeGenerator.FoliageMode.LOW_SPEC_TRIANGLE if use_low_spec else ProceduralTreeGenerator.FoliageMode.STANDARD
	var species := ["classic_oak", "pine_boreal", "autumn_birch", "weeping_willow", "dead_tree"]
	
	var t0 := Time.get_ticks_msec()
	for p_id in species:
		var prof := ProceduralTreeProfiles.get_profile(p_id)
		var list: Array[ProceduralTreeGenerator.TreeGenerationResult] = []
		for v in range(TREE_VARIANTS_PER_SPECIES):
			var seed_v := hash(p_id) ^ (_world_seed * 1009) ^ (v * 7919)
			var res := ProceduralTreeGenerator.generate_tree(prof, seed_v, mode)
			list.append(res)
		_tree_archetype_pool[p_id] = list
	
	var elapsed := Time.get_ticks_msec() - t0
	print("[chunk_manager] Catalogo de %d arboles precalculado en %d ms (Modo: %s)" % [
		TREE_VARIANTS_PER_SPECIES * species.size(),
		elapsed,
		"LOW_SPEC_TRIANGLE" if use_low_spec else "STANDARD"
	])


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
	# 1. Despachar hasta 1 tarea de cálculo en hilo de fondo WorkerThreadPool (prioridad normal)
	_dispatch_pending_chunk_loads()

	# 2. Recoger mallas terminadas del hilo de fondo (máximo 1 chunk por frame)
	var built_chunk: bool = _poll_pending_tasks()

	# 3. Intercalar trabajo en el hilo principal: si se construyó un chunk en este fotograma,
	# no saturar con descargas ni vegetación para garantizar que cada frame esté muy por debajo de 16.6 ms:
	if not built_chunk:
		if not _chunks_to_unload.is_empty():
			_process_chunk_unloads()
		elif not _rose_attach_queue.is_empty():
			_process_rose_attachments()
		elif not _bush_attach_queue.is_empty():
			_process_bush_attachments()
		elif not _tree_attach_queue.is_empty():
			_process_tree_attachments()

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


func _get_view_distance() -> int:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("get_view_distance"):
		return clampi(int(sm.get_view_distance()), 1, 4)
	return VIEW_DISTANCE_CHUNKS


func _update_chunks(center: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var needed: Dictionary = {}
	var view_dist := _get_view_distance()
	var new_loads := 0

	for dz in range(-view_dist, view_dist + 1):
		for dx in range(-view_dist, view_dist + 1):
			var coord := Vector2i(center.x + dx, center.y + dz)
			needed[coord] = true
			if _chunks_to_unload.has(coord):
				_chunks_to_unload.erase(coord)
			elif not _loaded_chunks.has(coord) and not _pending_task_ids.has(coord) and not _chunks_to_load.has(coord):
				_chunks_to_load.append(coord)
				new_loads += 1

	# Ordenar cola de carga por cercanía al jugador: el chunk bajo el jugador y los más cercanos primero
	if new_loads > 0:
		_chunks_to_load.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := (a.x - center.x) * (a.x - center.x) + (a.y - center.y) * (a.y - center.y)
			var db := (b.x - center.x) * (b.x - center.x) + (b.y - center.y) * (b.y - center.y)
			return da < db
		)

	# Cancelar de la cola de carga los chunks que ya quedaron fuera del radio
	for i in range(_chunks_to_load.size() - 1, -1, -1):
		if not needed.has(_chunks_to_load[i]):
			_chunks_to_load.remove_at(i)

	var new_unloads := 0
	for coord in _loaded_chunks.keys():
		if not needed.has(coord) and not _chunks_to_unload.has(coord):
			_chunks_to_unload.append(coord)
			new_unloads += 1

	if new_loads > 0 or new_unloads > 0:
		var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
		ChunkProfiler.record_frame_event("UpdateChunks_%s (+%d, -%d): %.2fms" % [
			center, new_loads, new_unloads, elapsed_ms
		])
		ChunkProfiler.log_event("[MOVIMIENTO] Jugador en chunk %s | +%d chunks a cargar | -%d chunks a descargar (cola: %d, duró %.2f ms)" % [
			center, new_loads, new_unloads, _chunks_to_load.size(), elapsed_ms
		])

	# Actualiza colisiones perezosas: solo el radio 3x3 inmediato alrededor del jugador
	_update_nearby_tree_collisions(center)

	# Actualiza activacion progresiva de vegetacion segun visibilidad real (LOD):
	# Arboles: radio <= 2 chunks (<= 80m, limite estricto de visibilidad)
	# Arbustos: radio <= 1 chunk (<= 40m)
	_update_nearby_vegetation(center)


func _update_nearby_vegetation(center: Vector2i) -> void:
	if not enable_trees and not enable_bushes and not enable_grass and not enable_wildflowers and not enable_roses:
		return
	for coord: Vector2i in _loaded_chunks.keys():
		var chunk_node: Node3D = _loaded_chunks.get(coord)
		if chunk_node == null or not is_instance_valid(chunk_node):
			continue
		var dist := maxi(abs(coord.x - center.x), abs(coord.y - center.y))
		var v_data: Dictionary = _chunk_vegetation_data.get(coord, {})
		if not v_data.is_empty():
			if enable_trees and dist <= 2 and not _chunk_has_trees.has(coord):
				_spawn_chunk_trees(coord, chunk_node, v_data)
			if enable_bushes and dist <= 1 and not _chunk_has_bushes.has(coord):
				_spawn_chunk_bushes(coord, chunk_node, v_data)
			if enable_grass and dist <= 1 and not _chunk_has_grass.has(coord):
				_spawn_chunk_grass(coord, chunk_node, v_data)
			if enable_wildflowers and dist <= 1 and not _chunk_has_flowers.has(coord):
				_spawn_chunk_flowers(coord, chunk_node, v_data)
			if enable_roses and dist <= 1 and not _chunk_has_roses.has(coord):
				_spawn_chunk_roses(coord, chunk_node, v_data)

		# Descargar vegetación fina (pasto, flores y rosales) cuando el chunk se aleja fuera del radio inmediato (dist > 1)
		if dist > 1:
			if _chunk_has_grass.has(coord):
				var grass_node := chunk_node.get_node_or_null("ChunkGrass")
				if grass_node:
					grass_node.queue_free()
				_chunk_has_grass.erase(coord)
			if _chunk_has_flowers.has(coord):
				for child in chunk_node.get_children():
					if child.name.begins_with("ChunkFlowers_"):
						child.queue_free()
				_chunk_has_flowers.erase(coord)
			if _chunk_has_roses.has(coord):
				for child in chunk_node.get_children():
					if child.name.begins_with("ChunkRose"):
						child.queue_free()
				_chunk_has_roses.erase(coord)


func _dispatch_pending_chunk_loads() -> void:
	# EXACTAMENTE 1 SUBPROCESO DE FONDO A LA VEZ (cero saturación de CPU)
	if _pending_task_ids.size() >= 1:
		return
	while not _chunks_to_load.is_empty():
		var coord: Vector2i = _chunks_to_load.pop_front()
		if _loaded_chunks.has(coord) or _pending_task_ids.has(coord):
			continue
		_load_chunk(coord)
		break


func _process_chunk_unloads() -> void:
	if not _chunks_to_unload.is_empty():
		var coord: Vector2i = _chunks_to_unload.pop_front()
		if _loaded_chunks.has(coord):
			var t0 := Time.get_ticks_usec()
			_unload_chunk(coord)
			var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
			ChunkProfiler.record_frame_event("UnloadChunk_%s: %.2fms (pendientes: %d)" % [coord, elapsed_ms, _chunks_to_unload.size()])
			ChunkProfiler.log_event("[DESCARGA_CHUNK] %s liberado en %.2f ms | Restan: %d" % [coord, elapsed_ms, _chunks_to_unload.size()])


func _process_tree_attachments() -> void:
	if not enable_trees:
		_tree_attach_queue.clear()
		return
	# Suavizado de carga adaptable: 2 a 3 árboles por fotograma (<0.15 ms de CPU, cero tirones)
	var count := 0
	var max_per_frame := 3 if _tree_attach_queue.size() > 10 else 2
	var t0 := Time.get_ticks_usec()
	while not _tree_attach_queue.is_empty() and count < max_per_frame:
		var item: Dictionary = _tree_attach_queue.pop_front()
		var parent_ref: WeakRef = item.get("parent_ref")
		if parent_ref == null:
			continue
		var parent: Node3D = parent_ref.get_ref() as Node3D
		if parent == null or not is_instance_valid(parent):
			continue # el chunk se descargo mientras los arboles esperaban su turno
		
		var req: Dictionary = item["req"]
		var res: ProceduralTreeGenerator.TreeGenerationResult = item["res"]
		var tree := ProceduralTree.new()
		tree.apply_generation_result(res)
		parent.add_child(tree)
		tree.global_position = req["pos"]
		
		# Variacion morfologica 3D: escala asimetrica + rotacion 360 + inclinacion organica natural
		var scale_3d: Vector3 = req.get("scale_3d", Vector3.ONE * float(req.get("scale_var", 1.0)))
		tree.scale = scale_3d
		tree.rotate_y(req["rot_y"])
		var tilt_x: float = float(req.get("tilt_x", 0.0))
		var tilt_z: float = float(req.get("tilt_z", 0.0))
		if absf(tilt_x) > 0.001:
			tree.rotate_x(tilt_x)
		if absf(tilt_z) > 0.001:
			tree.rotate_z(tilt_z)
		
		# Colision perezosa: solo instanciar cuerpo fisico si esta en el radio 3x3 del jugador
		var tree_chunk_x := floori(tree.global_position.x / CHUNK_WORLD_SIZE)
		var tree_chunk_z := floori(tree.global_position.z / CHUNK_WORLD_SIZE)
		var is_near: bool = _local_player == null or (abs(tree_chunk_x - _last_player_chunk.x) <= 1 and abs(tree_chunk_z - _last_player_chunk.y) <= 1)
		if is_near:
			_add_tree_collision(tree)
		count += 1
	
	if count > 0:
		var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
		ChunkProfiler.record_frame_event("AttachTrees (%d): %.2fms (cola: %d)" % [count, elapsed_ms, _tree_attach_queue.size()])


func _process_rose_attachments() -> void:
	if not enable_roses:
		_rose_attach_queue.clear()
		return
	# Suavizado de carga: adjunta maximo 2 rosales por fotograma (~0.04 ms de CPU con arquetipos precalculados)
	var count := 0
	var t0 := Time.get_ticks_usec()
	while not _rose_attach_queue.is_empty() and count < 2:
		var item: Dictionary = _rose_attach_queue.pop_front()
		var parent_ref: WeakRef = item.get("parent_ref")
		if parent_ref == null:
			continue
		var parent: Node3D = parent_ref.get_ref() as Node3D
		if parent == null or not is_instance_valid(parent):
			continue # el chunk se descargo mientras esperaba
		
		var req: Dictionary = item["req"]
		var pkg: ProceduralFlower.FlowerGenerationPackage = item["pkg"]
		var rose := ProceduralFlower.new()
		rose.name = "ChunkRose"
		rose.apply_generation_package(pkg)
		parent.add_child(rose)
		rose.global_position = req["pos"]
		rose.scale = req.get("scale", Vector3.ONE)
		rose.rotate_y(req["rot_y"])
		count += 1

	if count > 0:
		var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
		ChunkProfiler.record_frame_event("AttachRoses (%d): %.2fms (cola: %d)" % [count, elapsed_ms, _rose_attach_queue.size()])


func _process_bush_attachments() -> void:
	# Suavizado de carga: adjunta maximo 1 arbusto por fotograma (~0.05 ms de CPU)
	var count := 0
	var t0 := Time.get_ticks_usec()
	while not _bush_attach_queue.is_empty() and count < 1:
		var item: Dictionary = _bush_attach_queue.pop_front()
		var parent_ref: WeakRef = item.get("parent_ref")
		if parent_ref == null:
			continue
		var parent: Node3D = parent_ref.get_ref() as Node3D
		if parent == null or not is_instance_valid(parent):
			continue # el chunk se descargo mientras esperaba
		
		var req: Dictionary = item["req"]
		var model_idx: int = req["model_index"]
		if model_idx >= _bush_scenes.size():
			continue
		var scene: PackedScene = _bush_scenes[model_idx]
		if scene == null:
			continue
		var instance: Node3D = scene.instantiate()
		parent.add_child(instance)
		instance.global_position = req["pos"]
		instance.rotate_y(req["rot_y"])
		instance.scale = req["scale"]
		
		var texture: Texture2D = _bush_textures[model_idx] if model_idx < _bush_textures.size() else null
		if texture != null:
			var material: StandardMaterial3D = _bush_materials_cache.get(model_idx)
			if material == null:
				material = StandardMaterial3D.new()
				material.albedo_texture = texture
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.5
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				_bush_materials_cache[model_idx] = material
			_apply_vegetation_material(instance, material)
		count += 1

	if count > 0:
		var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
		ChunkProfiler.record_frame_event("AttachBushes (%d): %.2fms (cola: %d)" % [count, elapsed_ms, _bush_attach_queue.size()])


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
		false # prioridad normal para no saturar los 8 núcleos ni congelar el hilo principal
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

	# Determinar ecología del chunk según ruido de biomas (idéntico al shader de terreno)
	var chunk_center_x := origin_x + CHUNK_WORLD_SIZE * 0.5
	var chunk_center_z := origin_z + CHUNK_WORLD_SIZE * 0.5
	var center_biome := get_biome_noise(chunk_center_x, chunk_center_z)

	# Precalcular posicion, altura y orientacion de arboles en este MISMO hilo de fondo
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(coord.x, coord.y)) ^ world_seed

	var tree_requests: Array[Dictionary] = []
	if enable_trees:
		var target_tree_count := 0
		var cluster_centers: Array[Vector2] = []
		var cluster_radii: Array[float] = []

		if center_biome >= 0.40:
			# BOSQUE DENSO: 10 a 14 árboles agrupados formando masa forestal continua
			target_tree_count = rng.randi_range(10, 14)
			var c1 := Vector2(
				origin_x + rng.randf_range(VEGETATION_MARGIN + 6.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 6.0),
				origin_z + rng.randf_range(VEGETATION_MARGIN + 6.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 6.0)
			)
			cluster_centers.append(c1)
			cluster_radii.append(rng.randf_range(7.0, 9.5))
			if target_tree_count > 11:
				var c2 := Vector2(
					origin_x + rng.randf_range(VEGETATION_MARGIN + 5.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 5.0),
					origin_z + rng.randf_range(VEGETATION_MARGIN + 5.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 5.0)
				)
				cluster_centers.append(c2)
				cluster_radii.append(rng.randf_range(6.0, 8.5))
		elif center_biome >= 0.12:
			# ARBOLEDA / TRANSICIÓN: 3 a 5 árboles agrupados en un bosquecillo pequeño
			target_tree_count = rng.randi_range(3, 5)
			var c := Vector2(
				origin_x + rng.randf_range(VEGETATION_MARGIN + 5.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 5.0),
				origin_z + rng.randf_range(VEGETATION_MARGIN + 5.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 5.0)
			)
			cluster_centers.append(c)
			cluster_radii.append(rng.randf_range(4.0, 6.5))
		else:
			# PRADERA / MEADOW ABIERTO: claros limpios, casi sin árboles.
			# Ocasionalmente 1 árbol solitario majestuoso en loma alta (probabilidad 35%)
			if rng.randf() < 0.35:
				target_tree_count = 1
				var c := Vector2(
					origin_x + rng.randf_range(VEGETATION_MARGIN + 8.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 8.0),
					origin_z + rng.randf_range(VEGETATION_MARGIN + 8.0, CHUNK_WORLD_SIZE - VEGETATION_MARGIN - 8.0)
				)
				cluster_centers.append(c)
				cluster_radii.append(2.0)
			else:
				target_tree_count = 0

		var attempts := 0
		var max_attempts := target_tree_count * 5 + 10
		while tree_requests.size() < target_tree_count and attempts < max_attempts:
			attempts += 1
			var wx: float
			var wz: float
			if not cluster_centers.is_empty():
				var c_idx := rng.randi_range(0, cluster_centers.size() - 1)
				var center_pt: Vector2 = cluster_centers[c_idx]
				var rad: float = cluster_radii[c_idx]
				var angle := rng.randf() * TAU
				var dist := sqrt(rng.randf()) * rad
				wx = center_pt.x + cos(angle) * dist
				wz = center_pt.y + sin(angle) * dist
			else:
				wx = origin_x + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
				wz = origin_z + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)

			wx = clampf(wx, origin_x + VEGETATION_MARGIN, origin_x + CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
			wz = clampf(wz, origin_z + VEGETATION_MARGIN, origin_z + CHUNK_WORLD_SIZE - VEGETATION_MARGIN)

			if city_inner_radius > 0.0:
				var cdx := wx - city_center.x
				var cdz := wz - city_center.y
				if cdx * cdx + cdz * cdz <= city_inner_radius * city_inner_radius:
					continue

			# Evitar solapamiento de troncos (mínimo 2.2m)
			var too_close := false
			for req in tree_requests:
				var epos: Vector3 = req["pos"]
				var tdx := wx - epos.x
				var tdz := wz - epos.z
				if tdx * tdx + tdz * tdz < 4.84:
					too_close = true
					break
			if too_close:
				continue

			var h: float = _generator.sample_height(world_seed, wx, wz)
			if h > VEGETATION_MAX_HEIGHT or h < 3.0:
				continue

			var eps := 0.5
			var hl: float = _generator.sample_height(world_seed, wx - eps, wz)
			var hr: float = _generator.sample_height(world_seed, wx + eps, wz)
			var hd: float = _generator.sample_height(world_seed, wx, wz - eps)
			var hu: float = _generator.sample_height(world_seed, wx, wz + eps)
			var normal := Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()
			if normal.dot(Vector3.UP) < VEGETATION_MIN_SLOPE_DOT:
				continue

			var selected_profile_id := "classic_oak"
			if center_biome < 0.12:
				selected_profile_id = "pine_boreal" if rng.randf() < 0.60 else "classic_oak"
			elif center_biome >= 0.40:
				var roll := rng.randf()
				if roll < 0.40:
					selected_profile_id = "pine_boreal"
				elif roll < 0.70:
					selected_profile_id = "classic_oak"
				elif roll < 0.88:
					selected_profile_id = "autumn_birch"
				else:
					selected_profile_id = "dead_tree"
			else:
				var roll := rng.randf()
				if roll < 0.35:
					selected_profile_id = "classic_oak"
				elif roll < 0.65:
					selected_profile_id = "autumn_birch"
				elif roll < 0.85:
					selected_profile_id = "weeping_willow"
				else:
					selected_profile_id = "pine_boreal"

			var height_scale := rng.randf_range(0.85, 1.25)
			var canopy_spread := rng.randf_range(0.85, 1.20)
			if center_biome < 0.12 and target_tree_count == 1:
				height_scale *= 1.25
				canopy_spread *= 1.20

			var scale_vec := Vector3(canopy_spread, height_scale, canopy_spread)
			var tilt_x := rng.randf_range(-0.055, 0.055)
			var tilt_z := rng.randf_range(-0.055, 0.055)

			tree_requests.append({
				"profile_id": selected_profile_id,
				"seed": rng.randi(),
				"pos": Vector3(wx, h, wz),
				"rot_y": rng.randf_range(0.0, TAU),
				"scale_3d": scale_vec,
				"tilt_x": tilt_x,
				"tilt_z": tilt_z
			})

	data["tree_requests"] = tree_requests

	# Precalcular instancias de césped FBX (PSX_Grass) en este hilo de fondo (0 ms en hilo principal)
	var grass_requests: Array[Dictionary] = []
	if enable_grass and _generator != null:
		var target_grass_count := 0
		if center_biome < 0.12:
			target_grass_count = rng.randi_range(110, 150)
		elif center_biome < 0.40:
			target_grass_count = rng.randi_range(40, 65)
		else:
			target_grass_count = rng.randi_range(10, 18)

		for i in target_grass_count:
			if _generator == null:
				break
			var wx := origin_x + rng.randf_range(1.0, CHUNK_WORLD_SIZE - 1.0)
			var wz := origin_z + rng.randf_range(1.0, CHUNK_WORLD_SIZE - 1.0)
			if city_inner_radius > 0.0:
				var cdx := wx - city_center.x
				var cdz := wz - city_center.y
				if cdx * cdx + cdz * cdz <= city_inner_radius * city_inner_radius:
					continue

			var h: float = _generator.sample_height(world_seed, wx, wz)
			if h > VEGETATION_MAX_HEIGHT or h < 3.0:
				continue

			var eps := 0.5
			var hl: float = _generator.sample_height(world_seed, wx - eps, wz)
			var hr: float = _generator.sample_height(world_seed, wx + eps, wz)
			var hd: float = _generator.sample_height(world_seed, wx, wz - eps)
			var hu: float = _generator.sample_height(world_seed, wx, wz + eps)
			var normal := Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()
			if normal.dot(Vector3.UP) < 0.65:
				continue

			var g_scale := rng.randf_range(1.10, 1.70)
			var g_rot := rng.randf_range(0.0, TAU)
			var g_tilt_x := deg_to_rad(rng.randf_range(-5.0, 5.0))
			var g_tilt_z := deg_to_rad(rng.randf_range(-5.0, 5.0))

			grass_requests.append({
				"pos": Vector3(wx, h, wz),
				"scale": g_scale,
				"rot_y": g_rot,
				"tilt_x": g_tilt_x,
				"tilt_z": g_tilt_z
			})

	data["grass_requests"] = grass_requests

	# Precalcular flores silvestres (Margaritas, Lavandas, Amapolas) en praderas abiertas
	var flower_requests: Array[Dictionary] = []
	if enable_wildflowers and _generator != null:
		var target_flower_count := 0
		if center_biome < 0.12:
			target_flower_count = rng.randi_range(40, 65)
		elif center_biome < 0.40:
			target_flower_count = rng.randi_range(10, 18)
		else:
			target_flower_count = 0

		for i in target_flower_count:
			if _generator == null:
				break
			var wx := origin_x + rng.randf_range(1.5, CHUNK_WORLD_SIZE - 1.5)
			var wz := origin_z + rng.randf_range(1.5, CHUNK_WORLD_SIZE - 1.5)
			if city_inner_radius > 0.0:
				var cdx := wx - city_center.x
				var cdz := wz - city_center.y
				if cdx * cdx + cdz * cdz <= city_inner_radius * city_inner_radius:
					continue

			var under_tree := false
			for tr in tree_requests:
				var tpos: Vector3 = tr["pos"]
				var fdx := wx - tpos.x
				var fdz := wz - tpos.z
				if fdx * fdx + fdz * fdz < 3.24:
					under_tree = true
					break
			if under_tree:
				continue

			var h: float = _generator.sample_height(world_seed, wx, wz)
			if h > VEGETATION_MAX_HEIGHT or h < 3.0:
				continue

			var eps := 0.5
			var hl: float = _generator.sample_height(world_seed, wx - eps, wz)
			var hr: float = _generator.sample_height(world_seed, wx + eps, wz)
			var hd: float = _generator.sample_height(world_seed, wx, wz - eps)
			var hu: float = _generator.sample_height(world_seed, wx, wz + eps)
			var normal := Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()
			if normal.dot(Vector3.UP) < 0.70:
				continue

			var f_type := "daisy"
			var roll := rng.randf()
			if roll < 0.50:
				f_type = "daisy"
			elif roll < 0.80:
				f_type = "lavender"
			else:
				f_type = "poppy"

			var f_scale := rng.randf_range(1.15, 1.65)
			var f_rot := rng.randf_range(0.0, TAU)

			flower_requests.append({
				"type": f_type,
				"pos": Vector3(wx, h, wz),
				"scale": f_scale,
				"rot_y": f_rot
			})

	data["flower_requests"] = flower_requests

	# Precalcular rosales silvestres (ProceduralFlower) en praderas soleadas y orillas
	var rose_requests: Array[Dictionary] = []
	if enable_roses and _generator != null:
		var target_rose_count := 0
		if center_biome < 0.12:
			target_rose_count = rng.randi_range(2, 4)
		elif center_biome < 0.40:
			target_rose_count = rng.randi_range(1, 2)
		else:
			target_rose_count = 0

		for i in target_rose_count:
			if _generator == null:
				break
			var wx := origin_x + rng.randf_range(2.0, CHUNK_WORLD_SIZE - 2.0)
			var wz := origin_z + rng.randf_range(2.0, CHUNK_WORLD_SIZE - 2.0)
			if city_inner_radius > 0.0:
				var cdx := wx - city_center.x
				var cdz := wz - city_center.y
				if cdx * cdx + cdz * cdz <= city_inner_radius * city_inner_radius:
					continue

			var under_tree := false
			for tr in tree_requests:
				var tpos: Vector3 = tr["pos"]
				var rdx := wx - tpos.x
				var rdz := wz - tpos.z
				if rdx * rdx + rdz * rdz < 6.25:
					under_tree = true
					break
			if under_tree:
				continue

			var h: float = _generator.sample_height(world_seed, wx, wz)
			if h > VEGETATION_MAX_HEIGHT or h < 3.0:
				continue

			var eps := 0.5
			var hl: float = _generator.sample_height(world_seed, wx - eps, wz)
			var hr: float = _generator.sample_height(world_seed, wx + eps, wz)
			var hd: float = _generator.sample_height(world_seed, wx, wz - eps)
			var hu: float = _generator.sample_height(world_seed, wx, wz + eps)
			var normal := Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()
			if normal.dot(Vector3.UP) < 0.70:
				continue

			var r_scale := rng.randf_range(0.9, 1.25)
			var r_rot := rng.randf_range(0.0, TAU)
			var pool_idx := rng.randi_range(0, 17)

			rose_requests.append({
				"pos": Vector3(wx, h, wz),
				"scale": Vector3.ONE * r_scale,
				"rot_y": r_rot,
				"pool_index": pool_idx
			})

	data["rose_requests"] = rose_requests

	# Precalcular posicion, rotacion y escala de arbustos en este MISMO hilo de fondo (0 ms en hilo principal)
	var bush_requests: Array[Dictionary] = []
	if BUSH_MODEL_COUNT > 0 and _generator != null:
		var bush_rng := RandomNumberGenerator.new()
		bush_rng.seed = hash(Vector2i(coord.x, coord.y)) ^ (world_seed + 9999)
		for i in BUSHES_PER_CHUNK:
			if _generator == null:
				break
			var wx := origin_x + bush_rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
			var wz := origin_z + bush_rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
			if city_inner_radius > 0.0:
				var dx := wx - city_center.x
				var dz := wz - city_center.y
				if dx * dx + dz * dz <= city_inner_radius * city_inner_radius:
					continue
			
			var h: float = _generator.sample_height(world_seed, wx, wz)
			if h > VEGETATION_MAX_HEIGHT:
				continue
			
			var eps := 0.5
			var hl: float = _generator.sample_height(world_seed, wx - eps, wz)
			var hr: float = _generator.sample_height(world_seed, wx + eps, wz)
			var hd: float = _generator.sample_height(world_seed, wx, wz - eps)
			var hu: float = _generator.sample_height(world_seed, wx, wz + eps)
			var normal := Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()
			if normal.dot(Vector3.UP) < VEGETATION_MIN_SLOPE_DOT:
				continue
			
			var b_idx := bush_rng.randi_range(0, BUSH_MODEL_COUNT - 1)
			var b_scale := Vector3.ONE * bush_rng.randf_range(0.8, 1.3) * VEGETATION_SCALE_MULTIPLIER
			var b_rot := bush_rng.randf_range(0.0, TAU)
			bush_requests.append({
				"pos": Vector3(wx, h, wz),
				"model_index": b_idx,
				"scale": b_scale,
				"rot_y": b_rot
			})
	data["bush_requests"] = bush_requests

	_results_mutex.lock()
	_pending_results[coord] = data
	_results_mutex.unlock()


## Se llama cada frame desde _process, en el hilo principal: revisa que
## tareas de fondo ya terminaron y construye su malla/colision/vegetacion.
## Retorna true si proceso un chunk en este fotograma.
func _poll_pending_tasks() -> bool:
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
		return true # Escalonar: procesar maximo 1 chunk por fotograma para garantizar 60 FPS estables
	return false


func _is_chunk_needed(coord: Vector2i) -> bool:
	if _local_player == null:
		return false
	var center := _world_to_chunk_coord(_local_player.global_position)
	var view_dist := _get_view_distance()
	return abs(coord.x - center.x) <= view_dist and abs(coord.y - center.y) <= view_dist


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

	# En modo editor/playtest por heightfield se espera un frame para raycasts fisicos
	if _heightfield_mode:
		await get_tree().physics_frame
		if not is_instance_valid(mesh_instance) or _loaded_chunks.get(coord) != mesh_instance:
			return # el chunk se descargo antes de que llegara este frame
	
	_ready_chunks[coord] = true
	_scatter_vegetation(coord, origin_x, origin_z, mesh_instance, data)


func _build_chunk_mesh(coord: Vector2i, data: Dictionary) -> MeshInstance3D:
	var t_arr0 := Time.get_ticks_usec()
	var origin_x := float(coord.x) * CHUNK_WORLD_SIZE
	var origin_z := float(coord.y) * CHUNK_WORLD_SIZE

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainChunk_%d_%d" % [coord.x, coord.y]
	mesh_instance.mesh = array_mesh
	if _shared_terrain_material == null:
		_init_shared_terrain_material()
	mesh_instance.material_override = _shared_terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = Vector3(origin_x, 0.0, origin_z)

	var t_col0 := Time.get_ticks_usec()
	mesh_instance.create_trimesh_collision()
	var t_col1 := Time.get_ticks_usec()

	add_child(mesh_instance)
	var t_arr1 := Time.get_ticks_usec()

	var mesh_ms := (t_arr1 - t_arr0) / 1000.0
	var col_ms := (t_col1 - t_col0) / 1000.0
	ChunkProfiler.record_frame_event("BuildChunk_%s: Malla=%.2fms, ColisionTrimesh=%.2fms" % [coord, mesh_ms, col_ms])
	ChunkProfiler.log_event("[CARGA_CHUNK] %s -> ArrayMesh: %.2f ms | TrimeshCollision: %.2f ms | Total: %.2f ms" % [
		coord, mesh_ms, col_ms, mesh_ms + col_ms
	])
	return mesh_instance


func _load_vegetation_scenes() -> void:
	for i in range(1, BUSH_MODEL_COUNT + 1):
		var model_path := "%sbush%02d.fbx" % [BUSH_MODELS_DIR, i]
		var texture_path := "%sbush%02d.png" % [BUSH_TEXTURES_DIR, i]
		if ResourceLoader.exists(model_path):
			_bush_scenes.append(load(model_path))
			_bush_textures.append(load(texture_path) if ResourceLoader.exists(texture_path) else null)

	if _bush_scenes.is_empty():
		push_warning("[chunk_manager] No se encontraron modelos de arbustos en tree_pack_1.1.")


func _scatter_vegetation(coord: Vector2i, origin_x: float, origin_z: float, parent: Node3D, data: Dictionary = {}) -> void:
	var t_veg0 := Time.get_ticks_usec()
	if _heightfield_mode:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(coord.x, coord.y)) ^ _world_seed
		var space_state := get_world_3d().direct_space_state
		for i in BUSHES_PER_CHUNK:
			var wx := origin_x + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
			var wz := origin_z + rng.randf_range(VEGETATION_MARGIN, CHUNK_WORLD_SIZE - VEGETATION_MARGIN)
			if _is_inside_city_zone(wx, wz):
				continue
			_try_place_vegetation(wx, wz, rng, _bush_scenes, _bush_textures, space_state, parent, false)
		return

	_chunk_vegetation_data[coord] = data
	var center: Vector2i = _world_to_chunk_coord(_local_player.global_position) if _local_player != null else _last_player_chunk
	var dist := maxi(abs(coord.x - center.x), abs(coord.y - center.y))
	
	# Activacion de vegetacion segun visibilidad real:
	# Arboles: radio <= 2 chunks (<= 80m, limite de visibilidad LOD)
	# Arbustos, Pasto, Flores y Rosales: radio <= 1 chunk (<= 40m)
	var spawned_trees := 0
	var spawned_bushes := 0
	var spawned_grass := 0
	var spawned_flowers := 0
	var spawned_roses := 0
	if enable_trees and dist <= 2:
		spawned_trees = _spawn_chunk_trees(coord, parent, data)
	if enable_bushes and dist <= 1:
		spawned_bushes = _spawn_chunk_bushes(coord, parent, data)
	if enable_grass and dist <= 1:
		spawned_grass = _spawn_chunk_grass(coord, parent, data)
	if enable_wildflowers and dist <= 1:
		spawned_flowers = _spawn_chunk_flowers(coord, parent, data)
	if enable_roses and dist <= 1:
		spawned_roses = _spawn_chunk_roses(coord, parent, data)

	var t_veg1 := Time.get_ticks_usec()
	var veg_ms := (t_veg1 - t_veg0) / 1000.0
	ChunkProfiler.record_frame_event("ScatterVeg_%s (Arboles:%d, Arbustos:%d, Pasto:%d, Flores:%d, Rosas:%d): %.2fms" % [coord, spawned_trees, spawned_bushes, spawned_grass, spawned_flowers, spawned_roses, veg_ms])
	ChunkProfiler.log_event("[VEGETACION] %s -> %d arboles, %d arbustos, %d pasto, %d flores, %d rosas en %.2f ms (dist:%d)" % [coord, spawned_trees, spawned_bushes, spawned_grass, spawned_flowers, spawned_roses, veg_ms, dist])


func _spawn_chunk_roses(coord: Vector2i, parent: Node3D, data: Dictionary) -> int:
	if not enable_roses:
		return 0
	if _chunk_has_roses.has(coord):
		return 0
	var rose_requests: Array = data.get("rose_requests", [])
	if rose_requests.is_empty():
		return 0
	if _rose_archetype_pool.is_empty():
		return 0
	_chunk_has_roses[coord] = true
	var parent_ref: WeakRef = weakref(parent)
	var rose_items: Array[Dictionary] = []
	for req: Dictionary in rose_requests:
		var p_idx: int = clampi(int(req.get("pool_index", 0)), 0, _rose_archetype_pool.size() - 1)
		var pkg: ProceduralFlower.FlowerGenerationPackage = _rose_archetype_pool[p_idx]
		rose_items.append({
			"parent_ref": parent_ref,
			"req": req,
			"pkg": pkg
		})
	_rose_attach_queue.append_array(rose_items)
	return rose_requests.size()


func _spawn_chunk_trees(coord: Vector2i, parent: Node3D, data: Dictionary) -> int:
	if not enable_trees:
		return 0
	if _chunk_has_trees.has(coord):
		return 0
	_chunk_has_trees[coord] = true
	var tree_requests: Array = data.get("tree_requests", [])
	if tree_requests.is_empty():
		return 0
	var parent_ref: WeakRef = weakref(parent)
	var generated_trees: Array[Dictionary] = []
	for req: Dictionary in tree_requests:
		var p_id: String = req["profile_id"]
		var pool_list: Array = _tree_archetype_pool.get(p_id, [])
		if pool_list.is_empty():
			continue
		var v_idx: int = int(abs(hash(Vector2i(int(req["pos"].x), int(req["pos"].z)))) % pool_list.size())
		var res: ProceduralTreeGenerator.TreeGenerationResult = pool_list[v_idx]
		generated_trees.append({
			"parent_ref": parent_ref,
			"req": req,
			"res": res
		})
	_tree_attach_queue.append_array(generated_trees)
	return tree_requests.size()


func _spawn_chunk_bushes(coord: Vector2i, parent: Node3D, data: Dictionary) -> int:
	if not enable_bushes:
		return 0
	if _chunk_has_bushes.has(coord):
		return 0
	_chunk_has_bushes[coord] = true
	var bush_requests: Array = data.get("bush_requests", [])
	if bush_requests.is_empty():
		return 0
	var parent_ref: WeakRef = weakref(parent)
	var bush_items: Array[Dictionary] = []
	for req: Dictionary in bush_requests:
		bush_items.append({
			"parent_ref": parent_ref,
			"req": req
		})
	_bush_attach_queue.append_array(bush_items)
	return bush_requests.size()


func _spawn_chunk_grass(coord: Vector2i, parent: Node3D, data: Dictionary) -> int:
	if not enable_grass or _chunk_has_grass.has(coord):
		return 0
	var grass_requests: Array = data.get("grass_requests", [])
	if grass_requests.is_empty():
		return 0
	_chunk_has_grass[coord] = true

	var mesh := _get_grass_mesh()
	if mesh == null:
		return 0

	var mm_inst := MultiMeshInstance3D.new()
	mm_inst.name = "ChunkGrass"
	mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mm_inst.material_override = PSXGrass.get_material()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = grass_requests.size()

	var parent_origin: Vector3 = parent.global_position
	for i in range(grass_requests.size()):
		var req: Dictionary = grass_requests[i]
		var local_pos: Vector3 = req["pos"] - parent_origin
		var basis := Basis()
		basis = basis.rotated(Vector3.UP, req["rot_y"])
		var tilt_x: float = float(req.get("tilt_x", 0.0))
		var tilt_z: float = float(req.get("tilt_z", 0.0))
		if absf(tilt_x) > 0.001:
			basis = basis.rotated(Vector3.RIGHT, tilt_x)
		if absf(tilt_z) > 0.001:
			basis = basis.rotated(Vector3.FORWARD, tilt_z)
		var s: float = float(req.get("scale", 1.0))
		basis = basis.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, local_pos))

	mm_inst.multimesh = mm
	parent.add_child(mm_inst)
	return grass_requests.size()


func _spawn_chunk_flowers(coord: Vector2i, parent: Node3D, data: Dictionary) -> int:
	if not enable_wildflowers or _chunk_has_flowers.has(coord):
		return 0
	var flower_requests: Array = data.get("flower_requests", [])
	if flower_requests.is_empty():
		return 0
	_chunk_has_flowers[coord] = true

	var by_type: Dictionary = {}
	for req in flower_requests:
		var f_type: String = req.get("type", "daisy")
		if not by_type.has(f_type):
			by_type[f_type] = []
		by_type[f_type].append(req)

	var parent_origin: Vector3 = parent.global_position
	var total_flowers := 0
	for f_type in by_type.keys():
		var reqs: Array = by_type[f_type]
		var mesh: Mesh = _get_flower_mesh(f_type)
		if mesh == null:
			continue

		var mm_inst := MultiMeshInstance3D.new()
		mm_inst.name = "ChunkFlowers_" + f_type
		mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mm_inst.material_override = _get_flower_material()

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = reqs.size()

		for i in range(reqs.size()):
			var req: Dictionary = reqs[i]
			var local_pos: Vector3 = req["pos"] - parent_origin
			var basis := Basis()
			basis = basis.rotated(Vector3.UP, req["rot_y"])
			var s: float = float(req.get("scale", 1.0))
			basis = basis.scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(basis, local_pos))

		mm_inst.multimesh = mm
		parent.add_child(mm_inst)
		total_flowers += reqs.size()

	return total_flowers


func _is_inside_city_zone(world_x: float, world_z: float) -> bool:
	if _city_inner_radius <= 0.0:
		return false
	var dx := world_x - _city_center.x
	var dz := world_z - _city_center.y
	return dx * dx + dz * dz <= _city_inner_radius * _city_inner_radius


func _get_terrain_surface(world_x: float, world_z: float, space_state: PhysicsDirectSpaceState3D) -> Dictionary:
	if _heightfield_mode or _generator == null:
		if space_state == null:
			return {}
		var from := Vector3(world_x, 200.0, world_z)
		var to := Vector3(world_x, -50.0, world_z)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return {}
		return {
			"position": result["position"],
			"normal": result["normal"]
		}
	
	# Muestreo matematico ultra-rapido directo desde Rust (0 ms, sin bloqueos de fisicas)
	var h: float = _generator.sample_height(_world_seed, world_x, world_z)
	var eps := 0.5
	var hl: float = _generator.sample_height(_world_seed, world_x - eps, world_z)
	var hr: float = _generator.sample_height(_world_seed, world_x + eps, world_z)
	var hd: float = _generator.sample_height(_world_seed, world_x, world_z - eps)
	var hu: float = _generator.sample_height(_world_seed, world_x, world_z + eps)
	var normal := Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()
	return {
		"position": Vector3(world_x, h, world_z),
		"normal": normal
	}


func _collect_tree_spawn_data(
	world_x: float,
	world_z: float,
	rng: RandomNumberGenerator,
	space_state: PhysicsDirectSpaceState3D
) -> Dictionary:
	var surface := _get_terrain_surface(world_x, world_z, space_state)
	if surface.is_empty():
		return {}

	var hit_position: Vector3 = surface["position"]
	var hit_normal: Vector3 = surface["normal"]

	if hit_position.y > VEGETATION_MAX_HEIGHT:
		return {}
	if hit_normal.dot(Vector3.UP) < VEGETATION_MIN_SLOPE_DOT:
		return {}

	var selected_profile_id := "classic_oak"
	if hit_position.y > 12.0:
		selected_profile_id = "pine_boreal" if rng.randf() < 0.85 else "dead_tree"
	else:
		var roll := rng.randf()
		if roll < 0.45:
			selected_profile_id = "classic_oak"
		elif roll < 0.75:
			selected_profile_id = "autumn_birch"
		elif roll < 0.90:
			selected_profile_id = "pine_boreal"
		else:
			selected_profile_id = "weeping_willow"

	# Variacion morfologica 3D organica:
	# Altura y copa independientes (rompe proporcion de molde)
	# X y Z uniformes para que el cilindro de colision en Jolt Physics sea perfecto
	var height_scale := rng.randf_range(0.82, 1.25)
	var canopy_spread := rng.randf_range(0.85, 1.20)
	var scale_vec := Vector3(canopy_spread, height_scale, canopy_spread)
	
	# 2. Inclinacion organica sutil del tronco (+-3 a 4.5 grados)
	var tilt_x := rng.randf_range(-0.065, 0.065)
	var tilt_z := rng.randf_range(-0.065, 0.065)

	return {
		"profile_id": selected_profile_id,
		"seed": rng.randi(),
		"pos": hit_position,
		"rot_y": rng.randf_range(0.0, TAU),
		"scale_3d": scale_vec,
		"tilt_x": tilt_x,
		"tilt_z": tilt_z
	}


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

	var surface := _get_terrain_surface(world_x, world_z, space_state)
	if surface.is_empty():
		return

	var hit_position: Vector3 = surface["position"]
	var hit_normal: Vector3 = surface["normal"]

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
		var material: StandardMaterial3D = _bush_materials_cache.get(index)
		if material == null:
			material = StandardMaterial3D.new()
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # consistente con look PSX
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR # por si las texturas de hojas usan alpha
			material.alpha_scissor_threshold = 0.5
			material.cull_mode = BaseMaterial3D.CULL_DISABLED # tarjetas de hojas visibles desde ambos lados
			_bush_materials_cache[index] = material
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
	if tree_instance.get_node_or_null("Collision") != null:
		return # Ya tiene colision activa
	
	var height := 6.0
	if "tree_height" in tree_instance and float(tree_instance.tree_height) > 0.1:
		height = maxf(float(tree_instance.tree_height) * TREE_COLLISION_HEIGHT_RATIO, 1.0)
	else:
		var world_aabb := _compute_world_aabb(tree_instance)
		if world_aabb.size.y <= 0.01:
			return
		var local_aabb: AABB = tree_instance.global_transform.affine_inverse() * world_aabb
		height = maxf(local_aabb.size.y * TREE_COLLISION_HEIGHT_RATIO, 0.5)

	var body := CHOPPABLE_TREE_SCRIPT.new() as StaticBody3D
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TREE_TRUNK_RADIUS
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(shape)
	tree_instance.add_child(body)


func _remove_tree_collision(tree_instance: Node3D) -> void:
	var col := tree_instance.get_node_or_null("Collision")
	if col != null:
		col.queue_free()


## Mantiene activas las colisiones fisicas de los arboles unicamente en los 9 chunks
## adyacentes al jugador (radio 3x3). Todos los arboles a mayor distancia son 100%
## visuales sin consumir recursos de fisica.
func _update_nearby_tree_collisions(center: Vector2i) -> void:
	if not enable_trees:
		return
	for coord: Vector2i in _loaded_chunks.keys():
		var chunk_node: Node3D = _loaded_chunks[coord] as Node3D
		if chunk_node == null or not is_instance_valid(chunk_node):
			continue
		var is_near: bool = abs(coord.x - center.x) <= 1 and abs(coord.y - center.y) <= 1
		for child in chunk_node.get_children():
			if child is ProceduralTree:
				if is_near:
					_add_tree_collision(child)
				else:
					_remove_tree_collision(child)


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
	_chunk_vegetation_data.erase(coord)
	_chunk_has_trees.erase(coord)
	_chunk_has_bushes.erase(coord)
	_chunk_has_grass.erase(coord)
	_chunk_has_flowers.erase(coord)
	_chunk_has_roses.erase(coord)
