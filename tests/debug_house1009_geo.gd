extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var res = engine.generate_house(10, 16, 0, 1009, true)
	var rooms = res.get("rooms", [])
	print("Rooms in house 1009:")
	for r in rooms:
		print("Room %d: %s floor=%d x=%d..%d z=%d..%d" % [r.id, r.name, r.floor, r.x_min, r.x_max, r.z_min, r.z_max])
	
	# Check where doors are on floor 2
	print("\nDoors in house 1009:")
	for d in res.get("doors", []):
		print("Door: pos=%s sz=%s is_main=%s" % [d.position, d.size, d.get("is_main", false)])
		
	# Check where windows are
	print("\nWindows in house 1009:")
	for w in res.get("windows", []):
		print("Window: pos=%s sz=%s floor=%s" % [w.position, w.size, w.get("floor", 1)])
	quit(0)
