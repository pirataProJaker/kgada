class_name WheelPart
extends VehiclePart

## Rueda Modular (Llanta + Neumático 14") (Play Sector X)
## Compatible con cualquiera de las 4 posiciones del auto o como rueda de repuesto.

@export var is_left_side: bool = true


func _init(left_side: bool = true) -> void:
	is_left_side = left_side
	if data == null:
		data = VehiclePartData.new()
		data.part_id = "wheel_14_steelie"
		data.display_name = "Rueda 14\" con Tapacubos"
		data.slot_type = VehiclePartData.SlotType.WHEEL_FL
		data.compatible_models = ["universal"]
		data.mass_kg = 15.0
		data.wheel_radius = SedanAtlasData.WHEEL_RADIUS
		data.friction_slip = 1.05

	_build_wheel_mesh()


func _ready() -> void:
	super._ready()
	if mesh_instance == null:
		_build_wheel_mesh()


func _build_wheel_mesh() -> void:
	var m := CarMeshBuilder.get_wheel_mesh(is_left_side, true)
	set_mesh(m)
