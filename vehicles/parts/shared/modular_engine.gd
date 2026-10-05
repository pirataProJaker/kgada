class_name ModularEngine
extends VehiclePart

## Motor Modular de Combustión Interna (Play Sector X)
## Puede montarse en el vano motor del vehículo o extraerse completo.
## Contiene sus propios sockets para Batería, Radiador y Varilla de Aceite.

signal oil_checked(level: float, quality: float)

@export var engine_model_name: String = "Inline 4 1.6L"

var battery_socket: PartSocket = null
var radiator_socket: PartSocket = null

# Estado dinámico del motor
var is_running: bool = false
var current_rpm: float = 0.0
var target_rpm: float = 850.0 # Ralentí


func _init() -> void:
	_setup_internal_sockets()
	_build_visuals()


func _ready() -> void:
	super._ready()


func _setup_internal_sockets() -> void:
	# Socket de Batería (en la bandeja derecha del vano motor)
	battery_socket = PartSocket.new()
	battery_socket.name = "SocketBattery"
	battery_socket.socket_type = VehiclePartData.SlotType.BATTERY
	battery_socket.position = Vector3(0.44, 0.08, -0.12)
	add_child(battery_socket)

	# Socket de Radiador (en el soporte frontal del vano motor)
	radiator_socket = PartSocket.new()
	radiator_socket.name = "SocketRadiator"
	radiator_socket.socket_type = VehiclePartData.SlotType.RADIATOR
	radiator_socket.position = Vector3(0.0, 0.02, -0.46)
	add_child(radiator_socket)


@export_enum("Inline-4 1.6L (DOHC 16V)", "Inline-6 2.5L (DOHC 24V)") var engine_type: int = 0


func _build_visuals() -> void:
	if data == null:
		data = VehiclePartData.new()
		if engine_type == 1:
			data.part_id = "engine_i6_25l"
			data.display_name = "Motor 2.5L 6 Cilindros (DOHC 24V)"
			data.horse_power = 165.0
			data.max_rpm = 6800.0
			data.mass_kg = 165.0
		else:
			data.part_id = "engine_i4_16l"
			data.display_name = "Motor 1.6L 4 Cilindros (DOHC 16V)"
			data.horse_power = 92.0
			data.max_rpm = 6200.0
			data.mass_kg = 115.0

		data.slot_type = VehiclePartData.SlotType.ENGINE_BAY
		data.compatible_models = ["universal", "sedan_80s"]
		data.oil_level = 0.85
		data.oil_quality = 0.90

	var m: ArrayMesh
	if engine_type == 1:
		m = MechanicalPartsAtlasData.create_engine_i6_mesh()
	else:
		m = MechanicalPartsAtlasData.create_engine_i4_mesh()
	set_mesh(m)



## Simula la extracción de la varilla de aceite para inspección
func check_oil() -> Dictionary:
	var lvl := data.oil_level if data else 0.0
	var qual := data.oil_quality if data else 0.0
	oil_checked.emit(lvl, qual)
	return {
		"level": lvl,
		"quality": qual,
		"status_text": "Aceite Óptimo" if qual > 0.6 else "Aceite Quemado / Requiere Cambio"
	}


## Verifica si el motor está listo para arrancar (batería, aceite, etc.)
func can_start() -> bool:
	if data == null:
		return false
	if data.oil_level < 0.10:
		return false # Sin aceite no arranca o se traba
	if battery_socket and battery_socket.installed_part == null:
		return false # Sin batería no hay chispa
	return true
