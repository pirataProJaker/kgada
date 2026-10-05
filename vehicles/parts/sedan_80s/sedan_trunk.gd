class_name SedanTrunk
extends VehiclePart

## Tapa de Baúl / Maletero para Sedán 80s (Play Sector X)

func _init() -> void:
	is_hinged = true
	open_angle_deg = 52.0
	open_axis = Vector3.RIGHT # Rota hacia arriba sobre el eje X transversal

	if data == null:
		data = VehiclePartData.new()
		data.part_id = "sedan80_trunk"
		data.display_name = "Tapa de Maletero"
		data.slot_type = VehiclePartData.SlotType.TRUNK
		data.compatible_models = ["sedan_80s"]
		data.mass_kg = 12.0

	var m := CarMeshBuilder.create_trunk_mesh()
	set_mesh(m)


func _ready() -> void:
	super._ready()
	if mesh_instance == null:
		var m := CarMeshBuilder.create_trunk_mesh()
		set_mesh(m)
