class_name RadiatorPart
extends VehiclePart

## Radiador de Enfriamiento Automotriz (Play Sector X)

@export var coolant_level: float = 1.0


func _init() -> void:
	if data == null:
		data = VehiclePartData.new()
		data.part_id = "radiator_standard"
		data.display_name = "Radiador de Aluminio"
		data.slot_type = VehiclePartData.SlotType.RADIATOR
		data.compatible_models = ["universal"]
		data.mass_kg = 8.0

	_build_radiator_mesh()


func _ready() -> void:
	super._ready()
	if mesh_instance == null:
		_build_radiator_mesh()


func _build_radiator_mesh() -> void:
	var m := MechanicalPartsAtlasData.create_radiator_mesh(0.70, 0.36, 0.08)
	set_mesh(m)

