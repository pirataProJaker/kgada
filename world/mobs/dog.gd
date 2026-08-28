extends CharacterBody3D
class_name Dog
## Mob animal simple. El movimiento en si (que direccion tomar y
## cuando cambiarla) lo decide DogAi, escrito en Rust (rust_core/src/mob_ai.rs)
## - este script solo aplica gravedad y llama a esa IA cada frame de fisica.
## El modelo visual es el gato real (assets/cat/cat.fbx), cargado y
## normalizado por DogModelUtils.build_model() (el perro original -
## assets/dog/- no importa en Godot, valid=false confirmado para fbx y glb).

const GRAVITY := 20.0
const WANDER_SPEED := 1.8
const TURN_SPEED := 5.0 # que tan rapido gira para mirar hacia donde camina
const FALL_SAFETY_Y := -3.0 # por debajo de esto no hay terreno valido (min natural ~6-8) - probablemente cayo por un chunk descargado

var _ai = null
var _chunk_manager: Node = null


func _ready() -> void:
	if ClassDB.class_exists("DogAi"):
		_ai = ClassDB.instantiate("DogAi")
		_ai.call("set_speed", WANDER_SPEED)
		add_child(_ai)
	else:
		push_warning("[dog] DogAi no esta disponible - compila rust_core (cargo build) y reabre el proyecto.")

	DogModelUtils.build_model(self)
	_chunk_manager = get_tree().current_scene.get_node_or_null("ChunkManager")


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if _ai != null:
		var wander: Vector3 = _ai.call("tick", delta)
		velocity.x = wander.x
		velocity.z = wander.z
		if Vector2(wander.x, wander.z).length() > 0.01:
			var target_angle := atan2(wander.x, wander.z)
			rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

	move_and_slide()

	# Si su chunk se descargo mientras el jugador estaba lejos, cae sin fondo
	# hasta el piso de seguridad (ChunkManager._create_safety_floor, Y=-5) y
	# queda atrapado bajo el mundo cuando ese chunk se regenera encima -
	# mismo bug que se arreglo en player.gd, pero aca no habia ningun
	# mecanismo de recuperacion todavia.
	if global_position.y < FALL_SAFETY_Y:
		_recover_from_fall()


func _recover_from_fall() -> void:
	if _chunk_manager == null or not _chunk_manager.has_method("sample_terrain_height"):
		return
	var ground_y: float = _chunk_manager.sample_terrain_height(global_position.x, global_position.z)
	global_position.y = ground_y + 0.3
	velocity = Vector3.ZERO
