class_name SedanHood
extends VehiclePart

## Capó Abatible para Sedán 80s (Play Sector X)
## Al abrirse descubre el vano motor en 3D para inspeccionar y realizar swaps.

func _init() -> void:
	is_hinged = true
	open_angle_deg = 48.0
	open_axis = Vector3.RIGHT # Rota hacia arriba sobre el eje X transversal (+X x -Z = +Y)

	if data == null:
		data = VehiclePartData.new()
		data.part_id = "sedan80_hood"
		data.display_name = "Capó Frontal"
		data.slot_type = VehiclePartData.SlotType.HOOD
		data.compatible_models = ["sedan_80s"]
		data.mass_kg = 15.0

	var m := CarMeshBuilder.create_hood_mesh()
	set_mesh(m)


func _ready() -> void:
	super._ready()
	if mesh_instance == null:
		var m := CarMeshBuilder.create_hood_mesh()
		set_mesh(m)
