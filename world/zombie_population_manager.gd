extends Node3D
## Puente entre la poblacion agregada de Rust y los zombies CharacterBody3D.
## Solo los sectores cercanos se materializan; el resto permanece como datos.

const ZOMBIE_SCENE := preload("res://world/mobs/zombie.tscn")
const SECTOR_SIZE := 80.0
const DATA_RADIUS := 4
const ACTIVE_RADIUS := 1
const BASE_ZOMBIES_PER_SECTOR := 8
const EXTRA_ZOMBIES_PER_SECTOR := 8
const SPAWN_MARGIN := 8.0
const SPAWN_WAIT_HEIGHT := 500.0
const ACTIVE_ZOMBIE_BUDGET := 64
const NOISE_POLL_INTERVAL := 0.25
const ZOMBIE_HEARING_DISTANCE := 24.0
const SAVE_INTERVAL := 15.0
const NETWORK_SNAPSHOT_INTERVAL := 0.2

@export var chunk_manager_path: NodePath
@export var max_active_zombies := ACTIVE_ZOMBIE_BUDGET

var _population = null
var _chunk_manager: Node3D = null
var _world_seed := 1
var _configured := false
var _initialized_sectors: Dictionary = {}
var _desired_sectors: Dictionary = {}
var _active_records: Dictionary = {}
var _materialized_keys: Dictionary = {}
var _queued_keys: Dictionary = {}
var _spawn_queue: Array[Dictionary] = []
var _noise_poll_timer := 0.0
var _save_timer := 0.0
var _network_snapshot_timer := 0.0
var _network_proxies: Dictionary = {}
var _dead_network_events: Dictionary = {}


func _ready() -> void:
	_chunk_manager = get_node_or_null(chunk_manager_path)


func configure_world(world_seed: int) -> void:
	_despawn_all()
	_despawn_network_proxies()
	_dead_network_events.clear()
	_initialized_sectors.clear()
	_desired_sectors.clear()
	_spawn_queue.clear()
	_queued_keys.clear()
	_materialized_keys.clear()
	_world_seed = world_seed

	if _population == null:
		if not ClassDB.class_exists("ZombiePopulation"):
			push_warning("[zombie_population] ZombiePopulation no esta disponible.")
			return
		_population = ClassDB.instantiate("ZombiePopulation")
		add_child(_population)
	else:
		_population.call("clear")

	_population.call("configure", SECTOR_SIZE, _world_seed)
	_load_saved_population()
	_configured = true


func get_population() -> Node:
	return _population


func get_active_zombie_count() -> int:
	return _active_records.size()


func get_total_population() -> int:
	if _population == null:
		return 0
	return _population.call("get_total_population")


func save_population() -> void:
	if not _configured or _population == null or not has_node("/root/SaveManager"):
		return
	var snapshots: Array = []
	for sector_variant in _initialized_sectors.keys():
		var sector: Vector2i = sector_variant
		var snapshot: Dictionary = _population.call("get_sector_snapshot", sector.x, sector.y)
		var migration: Vector2 = snapshot.get("migration", Vector2.ZERO)
		var noise_position: Vector3 = snapshot.get("noise_position", Vector3.ZERO)
		snapshot["migration"] = [migration.x, migration.y]
		snapshot["noise_position"] = [noise_position.x, noise_position.y, noise_position.z]
		snapshots.append(snapshot)
	SaveManager.save_zombie_sector_snapshots(_world_seed, snapshots)


func report_noise(world_position: Vector3, strength: float, radius: float, duration: float) -> void:
	if not _configured or _population == null:
		return
	var center: Vector2i = _population.call("world_to_sector", world_position)
	var sector_radius := maxi(0, ceili(radius / SECTOR_SIZE))
	for dz in range(-sector_radius, sector_radius + 1):
		for dx in range(-sector_radius, sector_radius + 1):
			var sector := Vector2i(center.x + dx, center.y + dz)
			_ensure_sector(sector)
			_population.call("report_sector_noise", sector.x, sector.y, world_position, strength, duration)


func _process(delta: float) -> void:
	if not _configured:
		return
	if not _is_authoritative():
		return

	var players := _get_players()
	if players.is_empty():
		return

	_noise_poll_timer -= delta
	if _noise_poll_timer <= 0.0:
		_noise_poll_timer = NOISE_POLL_INTERVAL
		for player in players:
			if player.has_method("get_noise_strength"):
				var strength: float = player.get_noise_strength()
				if strength > 0.05:
					report_noise(player.global_position, strength, SECTOR_SIZE * 0.5, 1.0)
		_propagate_sector_noise()
	_population.call("advance", delta)
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		save_population()

	_desired_sectors = _calculate_desired_sectors(players)
	_initialize_data_sectors(players)
	_despawn_outside_desired_sectors()
	_prune_spawn_queue()
	_queue_spawn_entries()
	_materialize_next()

	_network_snapshot_timer -= delta
	for key in _dead_network_events.keys().duplicate():
		_dead_network_events[key]["remaining"] = float(_dead_network_events[key]["remaining"]) - delta
		if _dead_network_events[key]["remaining"] <= 0.0:
			_dead_network_events.erase(key)
	if multiplayer.has_multiplayer_peer() and _network_snapshot_timer <= 0.0:
		_network_snapshot_timer = NETWORK_SNAPSHOT_INTERVAL
		_send_network_snapshot()


func _is_authoritative() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _get_players() -> Array[Node3D]:
	var players: Array[Node3D] = []
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Node3D and is_instance_valid(candidate):
			players.append(candidate as Node3D)
	return players


func _calculate_desired_sectors(players: Array[Node3D]) -> Dictionary:
	var desired: Dictionary = {}
	for player in players:
		var center: Vector2i = _population.call("world_to_sector", player.global_position)
		for radius in range(ACTIVE_RADIUS + 1):
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if maxi(abs(dx), abs(dz)) != radius:
						continue
					desired[Vector2i(center.x + dx, center.y + dz)] = true
	return desired


func _initialize_data_sectors(players: Array[Node3D]) -> void:
	for player in players:
		var center: Vector2i = _population.call("world_to_sector", player.global_position)
		for dz in range(-DATA_RADIUS, DATA_RADIUS + 1):
			for dx in range(-DATA_RADIUS, DATA_RADIUS + 1):
				_ensure_sector(Vector2i(center.x + dx, center.y + dz))


func _ensure_sector(sector: Vector2i) -> void:
	if _initialized_sectors.has(sector):
		return
	_initialized_sectors[sector] = true

	var seed: int = _population.call("get_sector_seed", sector.x, sector.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count := BASE_ZOMBIES_PER_SECTOR + rng.randi_range(0, EXTRA_ZOMBIES_PER_SECTOR)
	_population.call("set_sector_population", sector.x, sector.y, count)


func _despawn_outside_desired_sectors() -> void:
	for instance_id in _active_records.keys().duplicate():
		var record: Dictionary = _active_records[instance_id]
		var sector: Vector2i = record["sector"]
		if _desired_sectors.has(sector):
			continue

		var zombie: Node3D = record["zombie"]
		var body := zombie as CharacterBody3D
		if body != null:
			_population.call("set_sector_aggregate_state", sector.x, sector.y, 2, Vector2(body.velocity.x, body.velocity.z))
		if is_instance_valid(zombie):
			zombie.set_physics_process(false)
			zombie.queue_free()
		_active_records.erase(instance_id)
		_materialized_keys.erase(record["key"])


func _prune_spawn_queue() -> void:
	var retained: Array[Dictionary] = []
	for entry in _spawn_queue:
		var sector: Vector2i = entry["sector"]
		if _desired_sectors.has(sector):
			retained.append(entry)
		else:
			_queued_keys.erase(entry["key"])
	_spawn_queue = retained


func _queue_spawn_entries() -> void:
	var pending_count := _active_records.size() + _spawn_queue.size()
	if pending_count >= max_active_zombies:
		return

	for sector_variant in _desired_sectors.keys():
		var sector: Vector2i = sector_variant
		var count: int = _population.call("get_sector_population", sector.x, sector.y)
		for index in range(count):
			if pending_count >= max_active_zombies:
				return
			var key := _materialization_key(sector, index)
			if _materialized_keys.has(key) or _queued_keys.has(key):
				continue
			_queued_keys[key] = true
			_spawn_queue.append({
				"key": key,
				"sector": sector,
				"index": index,
			})
			pending_count += 1


func _materialize_next() -> void:
	if _spawn_queue.is_empty() or _active_records.size() >= max_active_zombies:
		return

	var entry: Dictionary = _spawn_queue[0]
	var sector: Vector2i = entry["sector"]
	if not _desired_sectors.has(sector):
		_spawn_queue.pop_front()
		_queued_keys.erase(entry["key"])
		return

	var position := _position_for_entry(sector, entry["index"])
	if _chunk_manager != null and _chunk_manager.has_method("is_chunk_loaded"):
		var chunk: Vector2i = _chunk_manager.call("world_to_chunk_coord", position)
		if not _chunk_manager.call("is_chunk_loaded", chunk):
			return

	_spawn_queue.pop_front()
	_queued_keys.erase(entry["key"])
	var ground_y: Variant = _find_ground_y(position.x, position.z)
	if ground_y == null:
		return

	var zombie: Node3D = ZOMBIE_SCENE.instantiate()
	zombie.name = "Zombie_%s" % entry["key"]
	add_child(zombie)
	zombie.global_position = Vector3(position.x, ground_y as float, position.z)
	if zombie.has_method("initialize_from_population"):
		var seed: int = _population.call("get_sector_seed", sector.x, sector.y)
		zombie.call("initialize_from_population", seed ^ int(entry["index"]))
	if zombie.has_signal("died"):
		zombie.died.connect(_on_zombie_died.bind(sector, entry["key"]))

	var instance_id := zombie.get_instance_id()
	_active_records[instance_id] = {
		"zombie": zombie,
		"sector": sector,
		"key": entry["key"],
	}
	_materialized_keys[entry["key"]] = true


func _find_ground_y(x: float, z: float) -> Variant:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, SPAWN_WAIT_HEIGHT, z), Vector3(x, -20.0, z)
	)
	var result := space_state.intersect_ray(query)
	if result.has("position"):
		return result["position"].y + 0.1
	return null


func _position_for_entry(sector: Vector2i, index: int) -> Vector3:
	var seed: int = _population.call("get_sector_seed", sector.x, sector.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ (index * 1_103_515_245)
	return Vector3(
		sector.x * SECTOR_SIZE + rng.randf_range(SPAWN_MARGIN, SECTOR_SIZE - SPAWN_MARGIN),
		0.0,
		sector.y * SECTOR_SIZE + rng.randf_range(SPAWN_MARGIN, SECTOR_SIZE - SPAWN_MARGIN)
	)


func _materialization_key(sector: Vector2i, index: int) -> String:
	return "%d:%d:%d" % [sector.x, sector.y, index]


func _propagate_sector_noise() -> void:
	for record_variant in _active_records.values():
		var record: Dictionary = record_variant
		var zombie: Node3D = record["zombie"]
		if not is_instance_valid(zombie) or not zombie.has_method("hear_noise"):
			continue
		var sector: Vector2i = record["sector"]
		var snapshot: Dictionary = _population.call("get_sector_snapshot", sector.x, sector.y)
		var strength := float(snapshot.get("noise_strength", 0.0))
		if strength <= 0.05:
			continue
		var noise_position: Vector3 = snapshot.get("noise_position", Vector3.ZERO)
		var horizontal_distance := Vector2(
			zombie.global_position.x - noise_position.x,
			zombie.global_position.z - noise_position.z
		).length()
		if horizontal_distance <= ZOMBIE_HEARING_DISTANCE:
			zombie.call("hear_noise", noise_position, strength)


func _load_saved_population() -> void:
	if not has_node("/root/SaveManager"):
		return
	var snapshots: Array = SaveManager.load_zombie_sector_snapshots(_world_seed)
	for snapshot in snapshots:
		if not snapshot is Dictionary:
			continue
		var sector := Vector2i(int(snapshot.get("sector_x", 0)), int(snapshot.get("sector_z", 0)))
		_initialized_sectors[sector] = true
		_population.call("set_sector_population", sector.x, sector.y, int(snapshot.get("count", 0)))
		_population.call(
			"set_sector_aggregate_state",
			sector.x,
			sector.y,
			int(snapshot.get("state", 0)),
			_vector2_from_array(snapshot.get("migration", []))
		)
		var noise_position := _vector3_from_array(snapshot.get("noise_position", []))
		var noise_strength := float(snapshot.get("noise_strength", 0.0))
		var noise_remaining := float(snapshot.get("noise_remaining", 0.0))
		if noise_strength > 0.0 and noise_remaining > 0.0:
			_population.call("report_sector_noise", sector.x, sector.y, noise_position, noise_strength, noise_remaining)


func _vector2_from_array(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _vector3_from_array(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _on_zombie_died(zombie: Node3D, sector: Vector2i, key: String) -> void:
	var instance_id := zombie.get_instance_id()
	if not _active_records.has(instance_id):
		return
	_active_records.erase(instance_id)
	_materialized_keys.erase(key)
	_population.call("remove_sector_population", sector.x, sector.y, 1)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and zombie.has_method("get_network_state"):
		var death_snapshot: Dictionary = zombie.get_network_state()
		death_snapshot["key"] = key
		death_snapshot["dead"] = true
		_dead_network_events[key] = {"snapshot": death_snapshot, "remaining": 0.5}
	zombie.queue_free()


func _send_network_snapshot() -> void:
	if not multiplayer.is_server():
		return
	for peer_id in multiplayer.get_peers():
		var player: Node3D = get_parent().get_node_or_null(str(peer_id))
		var snapshots := _build_network_snapshot(player)
		_receive_network_snapshot.rpc_id(peer_id, snapshots)


func _build_network_snapshot(player: Node3D) -> Array:
	var snapshots: Array = []
	for record_variant in _active_records.values():
		var record: Dictionary = record_variant
		var zombie: Node3D = record["zombie"]
		if not is_instance_valid(zombie) or not zombie.has_method("get_network_state"):
			continue
		var snapshot: Dictionary = zombie.get_network_state()
		if player != null and snapshot.get("position", Vector3.ZERO).distance_to(player.global_position) > SECTOR_SIZE * (ACTIVE_RADIUS + 1):
			continue
		snapshot["key"] = record["key"]
		snapshots.append(snapshot)
	for event_variant in _dead_network_events.values():
		var event_snapshot: Dictionary = event_variant["snapshot"]
		if player == null or event_snapshot.get("position", Vector3.ZERO).distance_to(player.global_position) <= SECTOR_SIZE * (ACTIVE_RADIUS + 1):
			snapshots.append(event_snapshot)
	return snapshots


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_network_snapshot(snapshots: Array) -> void:
	if _is_authoritative():
		return
	var received: Dictionary = {}
	for snapshot in snapshots:
		if not snapshot is Dictionary or not snapshot.has("key"):
			continue
		var key := str(snapshot["key"])
		received[key] = true
		var zombie: Node3D = _network_proxies.get(key)
		if not is_instance_valid(zombie):
			zombie = ZOMBIE_SCENE.instantiate()
			add_child(zombie)
			zombie.set_network_proxy(true)
			_network_proxies[key] = zombie
		zombie.apply_network_state(
			_snapshot_vector3(snapshot.get("position", Vector3.ZERO)),
			float(snapshot.get("rotation_y", 0.0)),
			str(snapshot.get("animation", "idle")),
			bool(snapshot.get("dead", false))
		)

	for key in _network_proxies.keys().duplicate():
		if received.has(key):
			continue
		var stale: Node3D = _network_proxies[key]
		if is_instance_valid(stale):
			stale.queue_free()
		_network_proxies.erase(key)


func _snapshot_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _despawn_network_proxies() -> void:
	for zombie_variant in _network_proxies.values():
		var zombie: Node3D = zombie_variant
		if is_instance_valid(zombie):
			zombie.queue_free()
	_network_proxies.clear()


func _despawn_all() -> void:
	for record_variant in _active_records.values():
		var record: Dictionary = record_variant
		var zombie: Node3D = record["zombie"]
		if is_instance_valid(zombie):
			zombie.queue_free()
	_active_records.clear()