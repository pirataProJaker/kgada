extends CharacterBody3D
## Controlador de personaje minimo (Fase 1) para probar movimiento/camara con
## el estilo PSX y validar el InputManager (autoload) con gameplay real.
##
## Soporta multijugador basico: solo el peer dueño de este personaje
## (is_multiplayer_authority) procesa input/camara/fisica localmente; en los
## demas peers, este nodo solo recibe su posicion por RPC periodico (sin
## interpolar todavia - es "basico" a proposito, no probado con 2 instancias
## reales corriendo a la vez).

const MOVE_SPEED := 4.5
const GRAVITY := 18.0
const JUMP_VELOCITY := 7.0
const LOOK_PITCH_LIMIT := 1.4 # radianes, ~80 grados
const FALL_RECOVERY_Y := 3.0 # el terreno natural nunca baja hasta aqui
const SYNC_HZ := 15.0 # veces por segundo que se manda la posicion por red
const STEP_HEIGHT := 0.45 # desnivel maximo que el jugador puede subir suavemente
const STEP_DOWN_DISTANCE := 0.65 # margen para encontrar el piso despues de subir
const NOISE_DECAY_PER_SECOND := 1.8

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var stats: PlayerStats = $PlayerStats

var _spawn_position: Vector3
var _was_jump_key_pressed := false
var _sync_accumulator := 0.0
var _noise_strength := 0.0


func _ready() -> void:
	_spawn_position = global_position
	camera.current = is_multiplayer_authority()
	add_to_group("players")

	if not is_multiplayer_authority():
		return

	add_to_group("local_player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	InputManager.look_input.connect(_apply_look)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	var mouse_delta := InputManager.get_mouse_look_delta(event)
	if mouse_delta != Vector2.ZERO:
		_apply_look(mouse_delta)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	stats.tick(delta)

	var move_input := InputManager.get_movement_vector()
	_noise_strength = move_toward(_noise_strength, 0.0, NOISE_DECAY_PER_SECOND * delta)
	if move_input.length_squared() > 0.01:
		_noise_strength = maxf(_noise_strength, 0.55)

	var move_dir := Vector3.ZERO
	if move_input.length() > 0.0:
		move_dir = (transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()

	velocity.x = move_dir.x * MOVE_SPEED
	velocity.z = move_dir.z * MOVE_SPEED

	# Deteccion manual de flanco ("just pressed") para Space, ya que no esta
	# mapeado a una accion en el Input Map.
	var jump_key_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	var jump_just_pressed := jump_key_pressed and not _was_jump_key_pressed
	_was_jump_key_pressed = jump_key_pressed

	var was_on_floor := is_on_floor()
	if was_on_floor:
		velocity.y = 0.0
		if jump_just_pressed:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta

	# Mientras esta parado en el piso y no esta saltando/cayendo, se intenta
	# el "step-up" ANTES de mover (no reaccionando despues de que
	# move_and_slide ya resolvio el choque deslizando) - asi funciona sin
	# importar el angulo de acercamiento o si el objeto esta en una esquina.
	var desired_horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if not _can_enter_position(global_position + desired_horizontal_motion):
		velocity.x = 0.0
		velocity.z = 0.0
		desired_horizontal_motion = Vector3.ZERO
	if was_on_floor and velocity.y <= 0.0 and desired_horizontal_motion.length_squared() > 0.000001:
		_step_and_move(desired_horizontal_motion)
	else:
		move_and_slide()

	if global_position.y < FALL_RECOVERY_Y:
		_recover_from_fall()

	if multiplayer.has_multiplayer_peer():
		_sync_accumulator += delta
		if _sync_accumulator >= 1.0 / SYNC_HZ:
			_sync_accumulator = 0.0
			_sync_transform.rpc(global_position, rotation.y, head.rotation.x)


func emit_noise(strength: float) -> void:
	if is_multiplayer_authority():
		_noise_strength = maxf(_noise_strength, clampf(strength, 0.0, 1.0))


func get_noise_strength() -> float:
	return _noise_strength


func _can_enter_position(target_position: Vector3) -> bool:
	var chunk_manager := get_parent().get_node_or_null("ChunkManager") if get_parent() else null
	if chunk_manager == null or not chunk_manager.has_method("is_position_ready"):
		return true
	return chunk_manager.is_position_ready(target_position)


func _recover_from_fall() -> void:
	var current_position := global_position
	var chunk_manager := get_parent().get_node_or_null("ChunkManager") if get_parent() else null
	if chunk_manager != null and chunk_manager.has_method("sample_terrain_height"):
		var ground_y: float = chunk_manager.sample_terrain_height(current_position.x, current_position.z)
		current_position.y = ground_y + 1.0
		global_position = current_position
		velocity = Vector3.ZERO
		return
	_respawn()


## Reaparece en la posicion XZ original, pero recalculando la altura del
## suelo con ChunkManager.sample_terrain_height() (calculo analitico de
## ruido, no depende de que el chunk este cargado) en vez de reusar la
## vieja posicion Y guardada al inicio. Si se reusara esa Y directo, y el
## chunk original ya se descargo (jugador se alejo mucho antes de caer),
## reaparecia cayendo en el vacio hasta el piso de seguridad y quedaba
## atrapado bajo el terreno una vez que ese chunk se regeneraba encima
## suyo - este era el bug reportado de "morir y aparecer bajo el mapa".
func _respawn() -> void:
	var safe_position := _spawn_position
	var chunk_manager := get_parent().get_node_or_null("ChunkManager") if get_parent() else null
	if chunk_manager != null and chunk_manager.has_method("sample_terrain_height"):
		var ground_y: float = chunk_manager.sample_terrain_height(_spawn_position.x, _spawn_position.z)
		safe_position = Vector3(_spawn_position.x, ground_y + 1.0, _spawn_position.z)
	global_position = safe_position
	velocity = Vector3.ZERO


## Mata al jugador local usando exactamente el mismo respawn seguro que se
## usa cuando cae fuera del mapa. El chat llama a este metodo para /kill;
## no mueve ni afecta a jugadores remotos.
func kill() -> void:
	if not is_multiplayer_authority():
		return
	_respawn()


## Intenta subir automaticamente desniveles bajos (bordillos, objetos
## chicos) probando el movimiento ANTES de aplicarlo, no reaccionando
## despues de que move_and_slide ya lo resolvio deslizando - eso fallaba en
## angulos de acercamiento distintos a "de frente" o cerca de esquinas,
## porque el "resto" del movimiento quedaba mal calculado. Con test_move:
## 1) si el camino normal (altura actual) esta libre, es el caso comun,
## se hace move_and_slide de siempre (barato). 2) si esta bloqueado pero
## subiendo STEP_HEIGHT el mismo camino queda libre, se sube fisicamente
## (subir, avanzar, bajar a pisar la superficie real). 3) si sigue
## bloqueado incluso elevado (pared/objeto alto), se cae de vuelta a
## move_and_slide - se comporta como pared, igual que antes.
func _step_and_move(desired_horizontal_motion: Vector3) -> void:
	var ground_transform := global_transform
	if not test_move(ground_transform, desired_horizontal_motion):
		move_and_slide()
		return

	if test_move(ground_transform, Vector3.UP * STEP_HEIGHT):
		move_and_slide() # hay techo/algo encima - no se puede subir, es pared normal
		return

	var raised_transform := ground_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(raised_transform, desired_horizontal_motion):
		move_and_slide() # el obstaculo es demasiado alto/ancho - pared normal
		return

	global_transform = raised_transform.translated(desired_horizontal_motion)
	var landing_collision := move_and_collide(Vector3.DOWN * (STEP_HEIGHT + STEP_DOWN_DISTANCE))
	if landing_collision == null or landing_collision.get_normal().dot(Vector3.UP) < 0.5:
		global_transform = ground_transform
		move_and_slide()
		return

	velocity.y = 0.0


func _apply_look(delta: Vector2) -> void:
	rotate_y(-delta.x)
	head.rotate_x(-delta.y)
	head.rotation.x = clamp(head.rotation.x, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_transform(pos: Vector3, y_rotation: float, head_x_rotation: float) -> void:
	global_position = pos
	rotation.y = y_rotation
	head.rotation.x = head_x_rotation
