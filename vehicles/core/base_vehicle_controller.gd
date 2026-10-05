class_name BaseVehicleController
extends VehicleBody3D

## Controlador Base de Vehículos Modulares (Play Sector X)
## Gestiona la integración entre piezas modulares, motor, ruedas y conducción en 1ra persona.

signal driver_entered(player)
signal driver_exited(player)
signal part_detached(socket, part)

@export var car_model_name: String = "Sedán 80s"
@export var paint_color: Color = Color(0.18, 0.32, 0.62, 1.0) # Azul PSX por defecto

# Control de conducción
@export var max_steering_angle: float = 0.55 # Radianes (~31 grados)
@export var brake_strength: float = 85.0

var current_driver = null
var is_engine_started: bool = false

# Referencias a sockets principales
var sockets: Dictionary = {} # slot_type -> PartSocket

# Nodos de ruedas físicas de Godot
var physical_wheels: Dictionary = {} # slot_type -> VehicleWheel3D


func _ready() -> void:
	# Ajuste de masa realista (~1.4 toneladas) y centro de gravedad sobre el tren motriz
	mass = 1420.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.32, -0.15)
	linear_damp = 0.20
	angular_damp = 4.0


func _physics_process(delta: float) -> void:
	if current_driver != null:
		_process_driving_inputs(delta)
	else:
		engine_force = 0.0
		brake = 150.0 # Freno de mano firme al estar estacionado (no se mueve ni resbala si el jugador salta encima)


func _process_driving_inputs(delta: float) -> void:
	# 1. Lectura directa y robusta de teclado (WASD / Flechas) y Gamepad
	var forward_pressed := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var reverse_pressed := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var left_pressed := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right_pressed := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var handbrake_pressed := Input.is_physical_key_pressed(KEY_SPACE)

	var accel_input := (1.0 if forward_pressed else 0.0) - (1.0 if reverse_pressed else 0.0)
	var steer_input := (1.0 if left_pressed else 0.0) - (1.0 if right_pressed else 0.0)

	# Gamepad si se usa
	var joy_fwd := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	var joy_rev := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if joy_fwd > 0.1 or joy_rev > 0.1:
		accel_input = joy_fwd - joy_rev
	var joy_steer := -Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if abs(joy_steer) > 0.15:
		steer_input = joy_steer

	# 2. Verificación de motor instalado y encendido
	var engine_part := get_installed_engine()
	if engine_part == null or not is_engine_started:
		engine_force = 0.0
		brake = 10.0
	else:
		var hp: float = engine_part.data.horse_power if (engine_part.data and engine_part.data.horse_power > 10.0) else 90.0
		# Potencia ágil y viva para sedán ochentero (~4700N para 90HP)
		var max_force: float = hp * 52.0

		# Velocidad longitudinal relativa (-Z es hacia adelante en el vehículo)
		var forward_speed: float = -transform.basis.z.dot(linear_velocity)

		if handbrake_pressed:
			engine_force = 0.0
			brake = brake_strength * 2.5
		elif accel_input > 0.05:
			# Quiere avanzar hacia adelante (W)
			if forward_speed < -0.8:
				# Si iba marcha atrás, frenar con fuerza antes de avanzar
				engine_force = 0.0
				brake = brake_strength * 2.0
			else:
				# Acelerar hacia adelante: en Godot -Z es hacia adelante (fuerza negativa)
				engine_force = -accel_input * max_force
				brake = 0.0
		elif accel_input < -0.05:
			# Quiere ir marcha atrás (S)
			if forward_speed > 0.8:
				# Si iba hacia adelante a velocidad, ¡frenar en seco instantáneamente!
				engine_force = 0.0
				brake = brake_strength * 2.2
			else:
				# Marcha atrás (+Z es hacia atrás en Godot, fuerza positiva)
				engine_force = abs(accel_input) * (max_force * 0.72)
				brake = 0.0
		else:
			# Sin acelerador: freno de motor suave
			engine_force = 0.0
			brake = 4.0

	# 3. Dirección reactiva con atenuación a alta velocidad
	var speed_factor := clampf(1.0 - (linear_velocity.length() / 40.0) * 0.30, 0.65, 1.0)
	var target_steering := clampf(steer_input, -1.0, 1.0) * max_steering_angle * speed_factor
	steering = move_toward(steering, target_steering, delta * 5.0)




## Registra un socket en el diccionario del vehículo
func register_socket(slot_type: VehiclePartData.SlotType, socket: PartSocket) -> void:
	sockets[slot_type] = socket
	socket.part_installed.connect(_on_part_installed.bind(slot_type))
	socket.part_uninstalled.connect(_on_part_uninstalled.bind(slot_type))


## Registra una rueda física para sincronizar tracción
func register_physical_wheel(slot_type: VehiclePartData.SlotType, wheel: VehicleWheel3D) -> void:
	physical_wheels[slot_type] = wheel


func _on_part_installed(part: VehiclePart, slot_type: VehiclePartData.SlotType) -> void:
	# Si se instaló una rueda, activamos tracción y visibilidad
	if physical_wheels.has(slot_type):
		var w: VehicleWheel3D = physical_wheels[slot_type]
		w.use_as_traction = (slot_type == VehiclePartData.SlotType.WHEEL_FL or slot_type == VehiclePartData.SlotType.WHEEL_FR) # Tracción delantera FWD
		w.use_as_steering = (slot_type == VehiclePartData.SlotType.WHEEL_FL or slot_type == VehiclePartData.SlotType.WHEEL_FR)
		w.wheel_radius = part.data.wheel_radius if part.data else 0.29
		w.wheel_friction_slip = part.data.friction_slip if part.data else 1.05


func _on_part_uninstalled(part: VehiclePart, slot_type: VehiclePartData.SlotType) -> void:
	# Si se quitó una rueda, pierde tracción y agarre en esa esquina
	if physical_wheels.has(slot_type):
		var w: VehicleWheel3D = physical_wheels[slot_type]
		w.use_as_traction = false
		w.wheel_friction_slip = 0.05 # Desliza sobre el disco/buje
	part_detached.emit(sockets[slot_type], part)


## Retorna el motor instalado actualmente (si existe)
func get_installed_engine() -> VehiclePart:
	if sockets.has(VehiclePartData.SlotType.ENGINE_BAY):
		var s: PartSocket = sockets[VehiclePartData.SlotType.ENGINE_BAY]
		if s.installed_part != null:
			return s.installed_part
	return null


## Intenta arrancar el motor
func try_start_engine() -> bool:
	var eng := get_installed_engine()
	if eng != null and eng.can_start():
		is_engine_started = true
		return true
	is_engine_started = false
	return false


## Entrada del jugador al asiento del conductor
func enter_driver_seat(player) -> void:
	current_driver = player
	try_start_engine()
	driver_entered.emit(player)


## Salida del jugador del vehículo
func exit_driver_seat() -> void:
	var prev_driver = current_driver
	current_driver = null
	is_engine_started = false
	driver_exited.emit(prev_driver)
