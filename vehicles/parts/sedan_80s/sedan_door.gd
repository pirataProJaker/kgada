class_name SedanDoor
extends VehiclePart

## Puerta Específica para Sedán 80s con Bisagra Real (Play Sector X)

enum DoorPosition {
	FRONT_LEFT,
	FRONT_RIGHT,
	REAR_LEFT,
	REAR_RIGHT
}

@export var door_position: DoorPosition = DoorPosition.FRONT_LEFT


func _init(pos: DoorPosition = DoorPosition.FRONT_LEFT) -> void:
	door_position = pos
	is_hinged = true
	open_angle_deg = 65.0
	setup_door()


func setup_door() -> void:
	var is_left := (door_position == DoorPosition.FRONT_LEFT or door_position == DoorPosition.REAR_LEFT)
	var is_front := (door_position == DoorPosition.FRONT_LEFT or door_position == DoorPosition.FRONT_RIGHT)

	open_axis = Vector3.UP if is_left else -Vector3.UP

	if data == null:
		data = VehiclePartData.new()
		data.compatible_models = ["sedan_80s"]
		data.mass_kg = 18.0

		match door_position:
			DoorPosition.FRONT_LEFT:
				data.part_id = "sedan80_door_fl"
				data.display_name = "Puerta Delantera Izq"
				data.slot_type = VehiclePartData.SlotType.DOOR_FL
			DoorPosition.FRONT_RIGHT:
				data.part_id = "sedan80_door_fr"
				data.display_name = "Puerta Delantera Der"
				data.slot_type = VehiclePartData.SlotType.DOOR_FR
			DoorPosition.REAR_LEFT:
				data.part_id = "sedan80_door_rl"
				data.display_name = "Puerta Trasera Izq"
				data.slot_type = VehiclePartData.SlotType.DOOR_RL
			DoorPosition.REAR_RIGHT:
				data.part_id = "sedan80_door_rr"
				data.display_name = "Puerta Trasera Der"
				data.slot_type = VehiclePartData.SlotType.DOOR_RR

	var m: Mesh
	if is_front:
		m = CarMeshBuilder.create_front_door_mesh(is_left)
	else:
		m = CarMeshBuilder.create_rear_door_mesh(is_left)

	set_mesh(m)


func _ready() -> void:
	super._ready()
	if mesh_instance == null:
		setup_door()
