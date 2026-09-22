extends Node3D
## Escena principal (Fase 2): terreno con streaming de chunks + jugador local
## + multijugador basico (host/join) + guardado simple de posicion/semilla.

const AUTOSAVE_INTERVAL := 60.0
const DEFAULT_WORLD_SEED := 1
const DEFAULT_SPAWN := Vector3(0.0, 50.0, 0.0)
const SPAWN_WAIT_HEIGHT := 500.0 # altura "de limbo" mientras se genera el chunk, fuera de cualquier terreno
const SPAWN_GROUND_MARGIN := 1.0 # separacion sobre el suelo detectado, para no quedar incrustado
const SPAWN_MAX_WAIT_FRAMES := 600 # ~10s a 60fps; limite de seguridad por si el chunk nunca carga
## Cuando hay una posicion guardada, el rayo que busca el "piso" arranca
## apenas esta cantidad de metros arriba de esa posicion (no desde
## SPAWN_WAIT_HEIGHT) - si arrancara desde el limbo, un jugador que se
## desconecto DENTRO de una casa terminaria detectando el TECHO de la casa
## como "suelo" (el primer impacto del rayo bajando desde muy arriba) y
## apareceria parado encima del techo en vez de adentro (bug reportado).
const SPAWN_GROUND_SEARCH_MARGIN := 2.0
const MAP_DOCUMENT_SCRIPT := preload("res://map_editor/map_document.gd")
const MAP_PLAYTEST_PATH := "user://map_editor_playtest.json"

@onready var chunk_manager: Node3D = $ChunkManager
@onready var dog_spawner: DogSpawner = $DogSpawner
@onready var city_spawner: CityWorldSpawner = $CityWorldSpawner
@onready var zombie_population_manager: Node3D = $ZombiePopulationManager
@onready var construction_manager: Node3D = $ConstructionManager

var _autosave_timer := 0.0
var _world_seed := DEFAULT_WORLD_SEED
var _playtest_document = null


func _ready() -> void:
	_playtest_document = _load_playtest_document()
	_world_seed = SaveManager.get_active_world_seed()
	chunk_manager.set_world_seed(_world_seed)
	if _playtest_document != null:
		chunk_manager.configure_playtest(_playtest_document.heights, _playtest_document.grid_size)
		construction_manager.call("configure_document", _playtest_document)
	zombie_population_manager.configure_world(_world_seed)
	NetworkManager.players_container = self
	NetworkManager.ensure_local_player()

	# Se coloca ANTES de resolver al jugador: registra la zona de aplanado
	# de terreno en ChunkManager antes de que se genere cualquier chunk (ver
	# CityWorldSpawner - mismo criterio que las aldeas de Minecraft, la
	# semilla decide un punto fijo del mundo).
	if _playtest_document == null:
		city_spawner.spawn(_world_seed)

	var player: Node3D = get_node_or_null("1")
	if player == null:
		push_warning("[world_test] No se pudo encontrar/crear el jugador local.")
		return

	chunk_manager.set_local_player(player)
	await _spawn_player_safely(player)
	dog_spawner.spawn_around(player.global_position.x, player.global_position.z)

	get_tree().root.close_requested.connect(func() -> void: _save_player_state(player))

	if "--capture-screenshot" in OS.get_cmdline_args():
		_schedule_screenshot_and_exit()


func _schedule_screenshot_and_exit() -> void:
	await get_tree().create_timer(4.5).timeout
	var vp := get_viewport()

	# Buscar un rosal generado en los chunks cercanos
	var found_rose: Node3D = null
	for coord in chunk_manager._loaded_chunks.keys():
		var chunk_node: Node3D = chunk_manager._loaded_chunks[coord]
		if chunk_node:
			for child in chunk_node.get_children():
				if child.name.begins_with("ChunkRose"):
					found_rose = child as Node3D
					break
		if found_rose != null:
			break

	if found_rose != null:
		print("[world_test] Enfocando rosal procedural en: ", found_rose.global_position)
		var cam := Camera3D.new()
		cam.current = true
		cam.fov = 55.0
		add_child(cam)
		var rpos := found_rose.global_position
		cam.global_position = rpos + Vector3(1.8, 1.0, 2.0)
		cam.look_at(rpos + Vector3(0.0, 0.45, 0.0), Vector3.UP)
		await get_tree().create_timer(0.6).timeout

	if vp:
		var img := vp.get_texture().get_image()
		var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/world_test_roses_and_grass.png"
		img.save_png(save_path)
		print("[world_test] Screenshot capturado exitosamente en: ", save_path)
	get_tree().quit(0)


func _load_playtest_document():
	if not FileAccess.file_exists(MAP_PLAYTEST_PATH):
		return null
	var document = MAP_DOCUMENT_SCRIPT.load_from_file(MAP_PLAYTEST_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAP_PLAYTEST_PATH))
	return document


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		var player: Node3D = get_node_or_null("1")
		if player:
			_save_player_state(player)
		zombie_population_manager.save_population()


## Spawn "estilo Minecraft": el jugador queda congelado e invisible en un
## punto muy alto (fuera de cualquier chunk) mientras el terreno de su
## columna se genera en el hilo de fondo. En cuanto ese chunk ya tiene
## colision real, se detecta el suelo con un raycast y recien ahi se lo
## coloca parado y se reactiva su fisica - asi nunca aparece cayendo al
## vacio ni incrustado bajo el mundo mientras todavia se esta generando.
func _spawn_player_safely(player: Node3D) -> void:
	var spawn_x := DEFAULT_SPAWN.x
	var spawn_z := DEFAULT_SPAWN.z
	var saved_y := DEFAULT_SPAWN.y
	var has_saved_position := false

	if _playtest_document != null:
		var map_size_x: float = float(_playtest_document.grid_size.x - 1) * float(_playtest_document.cell_size)
		var map_size_z: float = float(_playtest_document.grid_size.y - 1) * float(_playtest_document.cell_size)
		spawn_x = map_size_x * 0.5
		spawn_z = map_size_z * 0.5
	elif SaveManager.has_save():
		var data := SaveManager.load_game()
		if data.has("player_position"):
			var pos: Array = data["player_position"]
			if pos.size() == 3:
				spawn_x = pos[0]
				saved_y = pos[1]
				spawn_z = pos[2]
				has_saved_position = true
		if data.has("player_y_rotation"):
			player.rotation.y = data["player_y_rotation"]

	player.set_physics_process(false)
	player.visible = false
	player.global_position = Vector3(spawn_x, SPAWN_WAIT_HEIGHT, spawn_z)

	var spawn_chunk: Vector2i = chunk_manager.world_to_chunk_coord(Vector3(spawn_x, 0.0, spawn_z))
	var waited_frames := 0
	while not chunk_manager.is_chunk_loaded(spawn_chunk) and waited_frames < SPAWN_MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited_frames += 1

	# Un frame de fisica extra para que la colision recien creada ya este
	# activa en el espacio fisico antes de lanzar el raycast.
	await get_tree().physics_frame

	# Con guardado: buscar el suelo arrancando justo encima de la posicion
	# guardada (ver comentario de SPAWN_GROUND_SEARCH_MARGIN) - sin
	# guardado (spawn nuevo): arrancar desde el limbo de siempre, ya que no
	# hay ninguna posicion previa de la que partir.
	var ground_search_start := SPAWN_WAIT_HEIGHT
	if has_saved_position:
		ground_search_start = saved_y + SPAWN_GROUND_SEARCH_MARGIN
	player.global_position = Vector3(spawn_x, _find_safe_ground_y(spawn_x, spawn_z, ground_search_start), spawn_z)
	player.visible = true
	player.set_physics_process(true)


func _find_safe_ground_y(x: float, z: float, start_height: float) -> float:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, start_height, z), Vector3(x, -20.0, z)
	)
	var result := space_state.intersect_ray(query)
	if result.has("position"):
		return result["position"].y + SPAWN_GROUND_MARGIN

	push_warning("[world_test] No se detecto suelo en el punto de spawn - usando altura por defecto.")
	return DEFAULT_SPAWN.y


func _save_player_state(player: Node3D) -> void:
	SaveManager.save_game(_world_seed, player.global_position, player.rotation.y)
	zombie_population_manager.save_population()
