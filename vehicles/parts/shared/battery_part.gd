class_name BatteryPart
extends VehiclePart

## Batería Automotriz 12V Estándar (Play Sector X)

@export var charge_pct: float = 1.0


func _init() -> void:
	if data == null:
		data = VehiclePartData.new()
		data.part_id = "battery_12v_standard"
		data.display_name = "Batería 12V 60Ah"
		data.slot_type = VehiclePartData.SlotType.BATTERY
		data.compatible_models = ["universal"]
		data.mass_kg = 14.0

	_build_battery_mesh()


func _ready() -> void:
	super._ready()
	if mesh_instance == null:
		_build_battery_mesh()


func _build_battery_mesh() -> void:
	var m := MechanicalPartsAtlasData.create_battery_mesh(0.24, 0.18, 0.16)
	set_mesh(m)

