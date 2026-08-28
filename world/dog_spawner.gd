extends Node3D
class_name DogSpawner
## Spawner de prueba: coloca varios perros alrededor del punto de spawn del
## jugador para validar que el modelo importado (assets/dog) se ve e integra
## bien en el juego, y que la IA de vagabundeo (Rust, DogAi) corre en varias
## instancias a la vez. La IA/movimiento de cada perro vive en Rust; este
## script solo decide DONDE aparecen.

const DOG_SCENE := preload("res://world/mobs/dog.tscn")
const DOG_COUNT := 15
const SPAWN_RADIUS_MIN := 8.0
const SPAWN_RADIUS_MAX := 35.0
const SPAWN_WAIT_HEIGHT := 500.0
const SPAWN_MAX_WAIT_FRAMES := 600

@export var chunk_manager_path: NodePath


func spawn_around(center_x: float, center_z: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var chunk_manager: Node3D = get_node_or_null(chunk_manager_path)

	for i in DOG_COUNT:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
		var x := center_x + cos(angle) * radius
		var z := center_z + sin(angle) * radius
		_spawn_one(x, z, chunk_manager)


func _spawn_one(x: float, z: float, chunk_manager: Node3D) -> void:
	if chunk_manager != null:
		var chunk_coord: Vector2i = chunk_manager.world_to_chunk_coord(Vector3(x, 0.0, z))
		var waited_frames := 0
		while not chunk_manager.is_chunk_loaded(chunk_coord) and waited_frames < SPAWN_MAX_WAIT_FRAMES:
			await get_tree().process_frame
			waited_frames += 1
		await get_tree().physics_frame

	var ground_y: Variant = _find_ground_y(x, z)
	if ground_y == null:
		return # sin suelo detectado (fuera del terreno cargado) - no aparece

	var dog: Node3D = DOG_SCENE.instantiate()
	get_tree().current_scene.add_child(dog)
	dog.global_position = Vector3(x, ground_y as float, z)


func _find_ground_y(x: float, z: float) -> Variant:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, SPAWN_WAIT_HEIGHT, z), Vector3(x, -20.0, z)
	)
	var result := space_state.intersect_ray(query)
	if result.has("position"):
		return result["position"].y + 0.1
	return null
