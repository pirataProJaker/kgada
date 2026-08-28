extends CharacterBody3D
class_name Zombie
signal died(zombie: Zombie)
## Mob zombie (assets/zombie 1/). El movimiento lo decide ZombieAi (Rust,
## rust_core/src/mob_ai.rs) - mismo patron que Dog/Cat, pero solo con 3
## estados de locomocion (idle/walk/run - un zombie no se sienta ni se
## acuesta). El modelo visual (con las 5 animaciones fusionadas: walk, run,
## idle, die, attack) lo carga ZombieModelUtils.build_model().
##
## La percepcion y las decisiones viven en ZombieAi (Rust); este script hace
## los raycasts, mueve el CharacterBody3D, reproduce animaciones y aplica el
## dano validado al objetivo.

const GRAVITY := 20.0
const PLAYER_MOVE_SPEED := 4.5
const ZOMBIE_SPEED_RATIO := 0.95
const WANDER_SPEED := PLAYER_MOVE_SPEED * ZOMBIE_SPEED_RATIO
const TURN_SPEED := 3.0 # gira mas lento que un animal (mas torpe)
const MAX_HEALTH := 60.0
const PERCEPTION_INTERVAL := 0.15
const SEPARATION_INTERVAL := 0.1
const VISION_DISTANCE := 18.0
const HEARING_DISTANCE := 24.0
const VISION_HALF_ANGLE_DEG := 70.0
const ATTACK_RANGE := 1.55
const ATTACK_DAMAGE := 8.0
const NETWORK_INTERPOLATION_SPEED := 12.0
const STEP_HEIGHT := 0.45
const STEP_DOWN_DISTANCE := 0.65

const LOOPING_ANIMS := ["walk", "run", "idle"]

var _ai = null
var _anim_player: AnimationPlayer = null
var _current_anim := ""
var _dead := false
var _health := MAX_HEALTH
var _perception_timer := 0.0
var _separation_timer := 0.0
var _separation_velocity := Vector3.ZERO
var _perceived_target: Node3D = null
var _network_proxy := false
var _network_target_position := Vector3.ZERO
var _network_target_rotation := 0.0
var _network_animation := "idle"
# Velocidad "natural" (m/s) de cada animacion de locomocion, leida de la
# metadata que deja ZombieModelUtils - ver _sync_anim_speed.
var _natural_speeds := {}


func _ready() -> void:
	floor_max_angle = deg_to_rad(40.0) # no debe poder subir pendientes muy pronunciadas
	add_to_group("active_zombies")

	if ClassDB.class_exists("ZombieAi"):
		_ai = ClassDB.instantiate("ZombieAi")
		_ai.call("set_speed", WANDER_SPEED)
		_ai.call("set_seed", int(get_instance_id() % 2147483647))
		add_child(_ai)
	else:
		push_warning("[zombie] ZombieAi no esta disponible - compila rust_core (cargo build) y reabre el proyecto.")

	ZombieModelUtils.build_model(self)
	_find_anim_player()
	var update_phase := float(get_instance_id() % 1000) / 1000.0
	_perception_timer = update_phase * PERCEPTION_INTERVAL
	_separation_timer = update_phase * SEPARATION_INTERVAL


func _find_anim_player() -> void:
	var model := get_node_or_null("Model")
	if model == null:
		return
	_anim_player = _find_anim_player_recursive(model)
	if _anim_player != null and _anim_player.has_meta("mob_natural_speeds"):
		_natural_speeds = _anim_player.get_meta("mob_natural_speeds")


func _find_anim_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player_recursive(child)
		if found != null:
			return found
	return null


func initialize_from_population(seed: int) -> void:
	if _ai != null:
		_ai.call("set_seed", seed)


func hear_noise(position: Vector3, strength: float) -> void:
	if _ai != null and not _network_proxy:
		_ai.call("hear_noise", position, strength)


func set_network_proxy(enabled: bool) -> void:
	_network_proxy = enabled
	if enabled and _ai != null:
		_ai.process_mode = Node.PROCESS_MODE_DISABLED


func apply_network_state(position: Vector3, rotation_y: float, animation: String, dead: bool) -> void:
	_network_target_position = position
	_network_target_rotation = rotation_y
	_network_animation = animation
	if dead:
		_dead = true
		_update_animation("die")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _network_proxy:
		global_position = global_position.lerp(_network_target_position, minf(1.0, NETWORK_INTERPOLATION_SPEED * delta))
		rotation.y = lerp_angle(rotation.y, _network_target_rotation, minf(1.0, NETWORK_INTERPOLATION_SPEED * delta))
		_update_animation(_network_animation)
		return

	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = PERCEPTION_INTERVAL
		_update_perception()

	var was_on_floor := is_on_floor()
	if was_on_floor:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	var anim := "idle"
	var actual_speed := 0.0
	var result: Dictionary = {}
	if _ai != null:
		result = _ai.call("tick", delta)
		var wander: Vector3 = result.get("velocity", Vector3.ZERO)
		_separation_timer -= delta
		if _separation_timer <= 0.0:
			_separation_timer = SEPARATION_INTERVAL
			_separation_velocity = _get_separation_velocity()
		wander += _separation_velocity
		anim = result.get("anim", "idle")
		velocity.x = wander.x
		velocity.z = wander.z
		actual_speed = Vector2(wander.x, wander.z).length()
		if actual_speed > 0.01:
			# Ver comentario identico en dog.gd/cat.gd: el modelo mira hacia
			# -Z, asi que theta = atan2(-dx, -dz).
			var target_angle := atan2(-wander.x, -wander.z)
			rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

	var desired_horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if was_on_floor and velocity.y <= 0.0 and desired_horizontal_motion.length_squared() > 0.000001:
		_step_and_move(desired_horizontal_motion)
	else:
		move_and_slide()

	if bool(result.get("attack", false)) and _perceived_target != null:
		play_attack()
		_apply_attack_damage(_perceived_target)

	# Si se topo con una pared o una pendiente demasiado pronunciada, se le
	# pide a la IA que elija una nueva direccion de inmediato.
	if is_on_wall() and _ai != null:
		_ai.call("force_redirect")

	_update_animation(anim)
	_sync_anim_speed(anim, actual_speed, delta)


## Reproduce "attack" una sola vez (sin loop) cuando Rust emite el evento de
## ataque; tambien queda publica para otros sistemas de combate.
func play_attack() -> void:
	_update_animation("attack")


func _update_perception() -> void:
	if _ai == null:
		return

	var nearest_target: Node3D = null
	var nearest_distance := INF
	var nearest_visible := false
	var nearest_noise_strength := 0.0

	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node3D:
			continue
		var player: Node3D = candidate as Node3D
		if player == self or not is_instance_valid(player):
			continue

		var offset := player.global_position - global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance > HEARING_DISTANCE:
			continue

		var noise_strength := 0.0
		if player.has_method("get_noise_strength"):
			noise_strength = player.get_noise_strength()
		var audible := noise_strength > 0.05 and distance <= HEARING_DISTANCE
		var visible := distance <= VISION_DISTANCE and _is_in_vision(player) and _has_line_of_sight(player)
		if not visible and not audible:
			continue
		if visible and (not nearest_visible or distance < nearest_distance):
			nearest_target = player
			nearest_distance = distance
			nearest_visible = true
		elif not nearest_visible and distance < nearest_distance:
			nearest_target = player
			nearest_distance = distance
			nearest_noise_strength = noise_strength

	_perceived_target = nearest_target
	if nearest_target == null:
		_ai.call("set_perception", global_position, Vector3.ZERO, false, false, Vector3.ZERO)
		return

	var target_position := nearest_target.global_position
	var heard_noise := not nearest_visible and nearest_noise_strength > 0.05
	_ai.call("set_perception", global_position, target_position, nearest_visible, heard_noise, target_position)


func _is_in_vision(target: Node3D) -> bool:
	var offset := target.global_position - global_position
	var direction := Vector3(offset.x, 0.0, offset.z)
	if direction.length_squared() <= 0.0001:
		return true
	return (-global_transform.basis.z).normalized().dot(direction.normalized()) >= cos(deg_to_rad(VISION_HALF_ANGLE_DEG))


func _has_line_of_sight(target: Node3D) -> bool:
	var from := global_position + Vector3.UP * 1.0
	var to := target.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var collider: Object = result.get("collider")
	if collider == target:
		return true
	if collider is Node:
		var collider_node: Node = collider as Node
		return target.is_ancestor_of(collider_node)
	return false


func _get_separation_velocity() -> Vector3:
	var separation := Vector3.ZERO
	for other_candidate in get_tree().get_nodes_in_group("active_zombies"):
		if other_candidate == self or not other_candidate is Node3D:
			continue
		var other_zombie: Node3D = other_candidate as Node3D
		var offset := global_position - other_zombie.global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance <= 0.001 or distance >= 1.2:
			continue
		separation += Vector3(offset.x, 0.0, offset.z).normalized() * (1.2 - distance) / 1.2
	if separation.length_squared() <= 0.0001:
		return Vector3.ZERO
	return separation.normalized() * 0.35


func _step_and_move(desired_horizontal_motion: Vector3) -> void:
	var ground_transform := global_transform
	if not test_move(ground_transform, desired_horizontal_motion):
		move_and_slide()
		return

	if test_move(ground_transform, Vector3.UP * STEP_HEIGHT):
		move_and_slide()
		return

	var raised_transform := ground_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(raised_transform, desired_horizontal_motion):
		move_and_slide()
		return

	global_transform = raised_transform.translated(desired_horizontal_motion)
	var landing_collision := move_and_collide(Vector3.DOWN * (STEP_HEIGHT + STEP_DOWN_DISTANCE))
	if landing_collision == null or landing_collision.get_normal().dot(Vector3.UP) < 0.5:
		global_transform = ground_transform
		move_and_slide()
		return

	velocity.y = 0.0


func _apply_attack_damage(target: Node3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > ATTACK_RANGE + 0.25:
		return
	if not _has_line_of_sight(target):
		return
	var stats := target.get_node_or_null("PlayerStats")
	if stats != null and stats.has_method("take_damage"):
		stats.take_damage(ATTACK_DAMAGE)


## Le quita `amount` de vida (llamado por MeleeController al conectar un
## golpe). Al llegar a 0, muere. Metodo con este nombre exacto ("take_damage")
## a proposito: cualquier atacante (MeleeController, futuras armas, etc.)
## puede llamarlo por duck-typing sin necesitar saber que es un Zombie.
func take_damage(amount: float) -> void:
	if _dead:
		return
	_health = maxf(_health - amount, 0.0)
	if _health <= 0.0:
		die()


## Reproduce "die" una sola vez y detiene la IA/fisica del zombie. Uso
## futuro: cuando exista un sistema de vida/dano para mobs.
func die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	_update_animation("die")
	died.emit(self)


func _update_animation(anim: String) -> void:
	if _anim_player == null:
		return
	if anim == _current_anim:
		return
	_current_anim = anim
	if _anim_player.has_animation(anim):
		var anim_res: Animation = _anim_player.get_animation(anim)
		if anim_res != null:
			anim_res.loop_mode = Animation.LOOP_LINEAR if anim in LOOPING_ANIMS else Animation.LOOP_NONE
		_anim_player.play(anim)
	else:
		push_warning("[zombie] No existe la animacion '%s'." % anim)


func get_network_state() -> Dictionary:
	return {
		"position": global_position,
		"rotation_y": rotation.y,
		"animation": _current_anim,
		"dead": _dead,
	}


## El paso "natural" horneado en cada animacion (ver ZombieModelUtils.
## _strip_root_motion) casi nunca coincide con la velocidad real a la que
## se mueve el CharacterBody3D (fija por WANDER_SPEED/ZombieAi) - sin esto,
## se ve como si el zombie arrastrara los pies (el cuerpo avanza mas o
## menos de lo que la animacion "cree" que esta caminando). Esta funcion
## ajusta `speed_scale` del AnimationPlayer para que el ciclo de pasos de
## la animacion en reproduccion se acerque a la velocidad real de
## movimiento.
##
## Dos ajustes para que no se vea "erratico": 1) el rango de correccion se
## deja BASTANTE mas angosto (0.7-1.4 en vez del ratio exacto, que en
## "walk" llegaba a ser 3.3x mas rapido - demasiado, se veia frenetico) -
## se prioriza que la animacion se siga viendo natural sobre una
## sincronizacion perfecta de pies. 2) el cambio se suaviza con un lerp por
## segundo en vez de aplicarse de golpe, porque AnimationPlayer.speed_scale
## es GLOBAL: si se cambia de golpe justo al llamar play(), durante el
## cross-fade (blend_time, ver _merge_animations) la animacion SALIENTE
## (ej. "idle") tambien queda afectada por el nuevo speed_scale un
## instante, lo cual se veia como un salto brusco/erratico en la
## transicion.
const ANIM_SPEED_MIN := 0.7
const ANIM_SPEED_MAX := 1.4
const ANIM_SPEED_SMOOTH := 3.0 # que tan rapido se acerca speed_scale al objetivo (por segundo)

func _sync_anim_speed(anim: String, actual_speed: float, delta: float) -> void:
	if _anim_player == null:
		return
	var natural_speed: float = _natural_speeds.get(anim, 0.0)
	var target_scale := 1.0
	if natural_speed > 0.01 and actual_speed > 0.01:
		target_scale = clamp(actual_speed / natural_speed, ANIM_SPEED_MIN, ANIM_SPEED_MAX)
	_anim_player.speed_scale = move_toward(_anim_player.speed_scale, target_scale, ANIM_SPEED_SMOOTH * delta)
