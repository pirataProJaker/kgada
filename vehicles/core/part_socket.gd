class_name PartSocket
extends Marker3D

## Punto de anclaje (Socket) para piezas modulares en el vehículo (Play Sector X)

signal part_installed(part: VehiclePart)
signal part_uninstalled(part: VehiclePart)

@export var socket_type: VehiclePartData.SlotType = VehiclePartData.SlotType.NONE
@export var car_model_id: String = "sedan_80s"
@export var is_optional: bool = false

var installed_part: VehiclePart = null


## Valida si una pieza dada puede ser montada en este socket
func can_accept(part: VehiclePart) -> bool:
	if installed_part != null or part == null or part.data == null:
		return false

	# Validación de tipo de slot:
	var req := socket_type
	var given := part.data.slot_type

	var is_wheel_req := (req == VehiclePartData.SlotType.WHEEL_FL or req == VehiclePartData.SlotType.WHEEL_FR or req == VehiclePartData.SlotType.WHEEL_RL or req == VehiclePartData.SlotType.WHEEL_RR)
	var is_wheel_given := (given == VehiclePartData.SlotType.WHEEL_FL or given == VehiclePartData.SlotType.WHEEL_FR or given == VehiclePartData.SlotType.WHEEL_RL or given == VehiclePartData.SlotType.WHEEL_RR)

	if is_wheel_req and is_wheel_given:
		pass # Las 4 ruedas son completamente intercambiables
	elif req != given:
		return false

	return part.data.is_compatible_with(car_model_id)


## Monta la pieza en este socket
func install(part: VehiclePart) -> bool:
	if not can_accept(part):
		return false

	installed_part = part
	part.current_socket = self

	# Reparentar al socket manteniendo posición y rotación locales a cero
	if part.get_parent() != self:
		if part.get_parent() != null:
			part.get_parent().remove_child(part)
		add_child(part)

	part.transform = Transform3D.IDENTITY
	part_installed.emit(part)
	return true


## Desmonta la pieza actual de este socket
func uninstall() -> VehiclePart:
	if installed_part == null:
		return null

	var part := installed_part
	installed_part = null
	part.current_socket = null
	part_uninstalled.emit(part)
	return part
