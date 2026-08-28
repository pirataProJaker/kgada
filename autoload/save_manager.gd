extends Node
## Persistencia de mundos y del estado del jugador local.
##
## El formato actual permite varios mundos dentro del mismo archivo. Si
## existe el formato antiguo (un unico mundo plano), se migra automaticamente
## a un mundo llamado "Mundo principal" para no perder el progreso existente.

const SAVE_PATH := "user://savegame.json"
const DEFAULT_WORLD_SEED := 1
const DEFAULT_WORLD_NAME := "Mundo principal"

var _worlds: Array = []
var _active_world_id := ""
var _loaded := false


func get_worlds() -> Array:
	_ensure_loaded()
	var result: Array = []
	for world in _worlds:
		result.append(world.duplicate(true))
	return result


func get_active_world() -> Dictionary:
	_ensure_loaded()
	var index := _find_world_index(_active_world_id)
	if index < 0:
		return {}
	return _worlds[index].duplicate(true)


func get_active_world_seed() -> int:
	var world := get_active_world()
	if world.is_empty():
		return DEFAULT_WORLD_SEED
	return int(world.get("world_seed", DEFAULT_WORLD_SEED))


func create_world(world_name: String, world_seed: int) -> Dictionary:
	_ensure_loaded()

	var clean_name := world_name.strip_edges()
	if clean_name.is_empty():
		return {}

	var world := {
		"id": _next_world_id(),
		"name": clean_name,
		"world_seed": world_seed,
		"player_position": [0.0, 50.0, 0.0],
		"player_y_rotation": 0.0,
		"has_progress": false,
	}
	_worlds.append(world)
	_active_world_id = world["id"]
	_write_data()
	return world.duplicate(true)


func select_world(world_id: String) -> bool:
	_ensure_loaded()
	if _find_world_index(world_id) < 0:
		return false
	_active_world_id = world_id
	_write_data()
	return true


func save_game(world_seed: int, player_position: Vector3, player_y_rotation: float) -> void:
	_ensure_loaded()

	var index := _find_world_index(_active_world_id)
	if index < 0:
		var fallback := {
			"id": _next_world_id(),
			"name": DEFAULT_WORLD_NAME,
			"world_seed": world_seed,
			"player_position": [0.0, 50.0, 0.0],
			"player_y_rotation": 0.0,
			"has_progress": false,
		}
		_worlds.append(fallback)
		_active_world_id = fallback["id"]
		index = _worlds.size() - 1

	var world: Dictionary = _worlds[index]
	world["world_seed"] = world_seed
	world["player_position"] = [player_position.x, player_position.y, player_position.z]
	world["player_y_rotation"] = player_y_rotation
	world["has_progress"] = true
	_write_data()


func load_zombie_sector_snapshots(world_seed: int) -> Array:
	_ensure_loaded()
	var world := get_active_world()
	if world.is_empty() or int(world.get("world_seed", DEFAULT_WORLD_SEED)) != world_seed:
		return []
	var saved = world.get("zombie_sectors", [])
	if not saved is Array:
		return []
	return saved.duplicate(true)


func save_zombie_sector_snapshots(world_seed: int, snapshots: Array) -> void:
	_ensure_loaded()
	var index := _find_world_index(_active_world_id)
	if index < 0:
		var fallback := {
			"id": _next_world_id(),
			"name": DEFAULT_WORLD_NAME,
			"world_seed": world_seed,
			"player_position": [0.0, 50.0, 0.0],
			"player_y_rotation": 0.0,
			"has_progress": false,
		}
		_worlds.append(fallback)
		_active_world_id = fallback["id"]
		index = _worlds.size() - 1

	var clean_snapshots: Array = []
	for snapshot in snapshots:
		if snapshot is Dictionary:
			clean_snapshots.append(snapshot.duplicate(true))
	_worlds[index]["world_seed"] = world_seed
	_worlds[index]["zombie_sectors"] = clean_snapshots
	_write_data()


## Devuelve el mundo activo, o un diccionario vacio si nunca se ha creado.
func load_game() -> Dictionary:
	var world := get_active_world()
	if world.is_empty() or not bool(world.get("has_progress", false)):
		return {}
	return world


func has_save() -> bool:
	return not load_game().is_empty()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_worlds.clear()
	_active_world_id = ""

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return

	if parsed.has("worlds") and parsed["worlds"] is Array:
		for candidate in parsed["worlds"]:
			if candidate is Dictionary and candidate.has("id") and candidate.has("name"):
				_worlds.append(candidate.duplicate(true))
		_active_world_id = str(parsed.get("active_world_id", ""))
		if _find_world_index(_active_world_id) < 0 and not _worlds.is_empty():
			_active_world_id = str(_worlds[0].get("id", ""))
		return

	# Migracion del formato anterior: un unico diccionario en la raiz.
	var legacy_world := {
		"id": "world_1",
		"name": str(parsed.get("world_name", DEFAULT_WORLD_NAME)),
		"world_seed": int(parsed.get("world_seed", DEFAULT_WORLD_SEED)),
		"player_position": [0.0, 50.0, 0.0],
		"player_y_rotation": 0.0,
		"has_progress": false,
	}
	var legacy_position = parsed.get("player_position", [])
	if legacy_position is Array and legacy_position.size() == 3:
		legacy_world["player_position"] = legacy_position
		legacy_world["player_y_rotation"] = float(parsed.get("player_y_rotation", 0.0))
		legacy_world["has_progress"] = true
	_worlds.append(legacy_world)
	_active_world_id = legacy_world["id"]
	_write_data()


func _find_world_index(world_id: String) -> int:
	for index in _worlds.size():
		if str(_worlds[index].get("id", "")) == world_id:
			return index
	return -1


func _next_world_id() -> String:
	var number := 1
	while _find_world_index("world_%d" % number) >= 0:
		number += 1
	return "world_%d" % number


func _write_data() -> void:
	var data := {
		"version": 2,
		"active_world_id": _active_world_id,
		"worlds": _worlds,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[save_manager] No se pudo abrir el archivo de guardado para escribir.")
		return
	file.store_string(JSON.stringify(data))
	file.close()
