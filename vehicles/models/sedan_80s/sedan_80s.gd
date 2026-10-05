class_name Sedan80s
extends BaseVehicleController

## Ensamblado Completo y Modular del Sedán 80s (Play Sector X)
## Integra el chasis unibody, suspensión de 4 ruedas, sockets y piezas funcionales.

const ModularEngineScript = preload("res://vehicles/parts/shared/modular_engine.gd")
const BatteryPartScript = preload("res://vehicles/parts/shared/battery_part.gd")
const RadiatorPartScript = preload("res://vehicles/parts/shared/radiator_part.gd")

@export var spawn_assembled: bool = true

var chassis_instance: MeshInstance3D = null


func _ready() -> void:
	car_model_name = "Sedán 80s Clásico"
	super._ready()

	_build_chassis_and_collision()
	_setup_vehicle_wheels()
	_setup_sockets()

	if spawn_assembled:
		_install_default_parts()


func _build_chassis_and_collision() -> void:
	# 1. Malla del Chasis Unibody (incluye el vano motor)
	var ch_mesh := CarMeshBuilder.create_chassis_mesh()
	chassis_instance = MeshInstance3D.new()
	chassis_instance.name = "ChassisMesh"
	chassis_instance.mesh = ch_mesh
	chassis_instance.material_override = SedanAtlasData.get_vehicle_material()
	add_child(chassis_instance)

	# 2. Colisión física principal del cuerpo
	var col_shape := CollisionShape3D.new()
	col_shape.name = "MainBodyCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(1.58, 0.42, 4.30)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, 0.54, -0.12)
	add_child(col_shape)

	# 3. Colisión de la cabina / techo
	var roof_shape := CollisionShape3D.new()
	roof_shape.name = "CabinCollision"
	var roof_box := BoxShape3D.new()
	roof_box.size = Vector3(1.34, 0.58, 1.84)
	roof_shape.shape = roof_box
	roof_shape.position = Vector3(0.0, 1.04, 0.10)
	add_child(roof_shape)


func _setup_vehicle_wheels() -> void:
	var track_half: float = CarMeshBuilder.HW_TRACK
	var z_front: float = CarMeshBuilder.Z_WHEEL_F
	var z_rear: float  = CarMeshBuilder.Z_WHEEL_R
	var wheel_y: float = CarMeshBuilder.Y_AXLE

	var wheel_configs := [
		{"slot": VehiclePartData.SlotType.WHEEL_FL, "name": "Wheel_FL", "pos": Vector3(-track_half, wheel_y, z_front), "steer": true, "front": true},
		{"slot": VehiclePartData.SlotType.WHEEL_FR, "name": "Wheel_FR", "pos": Vector3( track_half, wheel_y, z_front), "steer": true, "front": true},
		{"slot": VehiclePartData.SlotType.WHEEL_RL, "name": "Wheel_RL", "pos": Vector3(-track_half, wheel_y, z_rear), "steer": false, "front": false},
		{"slot": VehiclePartData.SlotType.WHEEL_RR, "name": "Wheel_RR", "pos": Vector3( track_half, wheel_y, z_rear), "steer": false, "front": false},
	]

	for cfg in wheel_configs:
		var vw := VehicleWheel3D.new()
		vw.name = cfg["name"]
		vw.position = cfg["pos"]
		vw.wheel_radius = SedanAtlasData.WHEEL_RADIUS
		vw.suspension_travel = 0.16
		vw.suspension_stiffness = 54.0
		vw.damping_compression = 3.5
		vw.damping_relaxation = 4.2
		vw.use_as_steering = cfg["steer"]
		vw.use_as_traction = cfg["front"] # Tracción delantera FWD
		vw.wheel_friction_slip = 2.4
		add_child(vw)
		register_physical_wheel(cfg["slot"], vw)



func _setup_sockets() -> void:
	# 1. Sockets de Ruedas (anclados en las ruedas físicas para suspensión y giro)
	for slot: VehiclePartData.SlotType in physical_wheels:
		var vw: VehicleWheel3D = physical_wheels[slot]
		var s := PartSocket.new()
		s.name = "Socket_" + vw.name
		s.socket_type = slot
		s.car_model_id = "sedan_80s"
		vw.add_child(s)
		register_socket(slot, s)

	# 2. Socket de Capó Practicable (en el Cowl)
	var s_hood := PartSocket.new()
	s_hood.name = "Socket_Hood"
	s_hood.socket_type = VehiclePartData.SlotType.HOOD
	s_hood.car_model_id = "sedan_80s"
	s_hood.position = Vector3(0.0, CarMeshBuilder.Y_HOOD_PIVOT, CarMeshBuilder.Z_HOOD_PIVOT)
	add_child(s_hood)
	register_socket(VehiclePartData.SlotType.HOOD, s_hood)

	# 3. Socket del Vano Motor (en el centro del vano motor)
	var s_eng := PartSocket.new()
	s_eng.name = "Socket_EngineBay"
	s_eng.socket_type = VehiclePartData.SlotType.ENGINE_BAY
	s_eng.car_model_id = "sedan_80s"
	s_eng.position = Vector3(0.0, 0.48, -1.67)
	add_child(s_eng)
	register_socket(VehiclePartData.SlotType.ENGINE_BAY, s_eng)


## Ensambla todas las piezas por defecto (auto listo de fábrica)
func _install_default_parts() -> void:
	# 1. Ruedas
	var wheel_slots: Array[VehiclePartData.SlotType] = [
		VehiclePartData.SlotType.WHEEL_FL,
		VehiclePartData.SlotType.WHEEL_FR,
		VehiclePartData.SlotType.WHEEL_RL,
		VehiclePartData.SlotType.WHEEL_RR
	]
	for slot: VehiclePartData.SlotType in wheel_slots:
		if sockets.has(slot) and sockets[slot] != null:
			var is_left := (slot == VehiclePartData.SlotType.WHEEL_FL or slot == VehiclePartData.SlotType.WHEEL_RL)
			var wp := WheelPart.new(is_left)
			sockets[slot].install(wp)

	# 2. Capó practicable con bisagra real al cowl
	if sockets.has(VehiclePartData.SlotType.HOOD) and sockets[VehiclePartData.SlotType.HOOD] != null:
		var hood := SedanHood.new()
		sockets[VehiclePartData.SlotType.HOOD].install(hood)
		hood.state_changed.connect(_update_engine_bay_visibility)

	# 4. Motor con sus subpiezas (Batería y Radiador)
	if sockets.has(VehiclePartData.SlotType.ENGINE_BAY) and sockets[VehiclePartData.SlotType.ENGINE_BAY] != null:
		var eng = ModularEngineScript.new()
		sockets[VehiclePartData.SlotType.ENGINE_BAY].install(eng)

		if eng.battery_socket != null:
			var bat = BatteryPartScript.new()
			eng.battery_socket.install(bat)

		if eng.radiator_socket != null:
			var rad = RadiatorPartScript.new()
			eng.radiator_socket.install(rad)

	_update_engine_bay_visibility()


## Actualiza la visibilidad de los componentes mecánicos internos según el estado del capó
func _update_engine_bay_visibility() -> void:
	var hood_socket: PartSocket = sockets.get(VehiclePartData.SlotType.HOOD, null)
	var hood: SedanHood = hood_socket.installed_part as SedanHood if hood_socket else null
	var eng := get_installed_engine()
	if eng != null:
		eng.visible = (hood != null and hood.is_open)
