extends SceneTree

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	var node = showcase_scn.instantiate()
	node.is_capture_mode = true
	root.add_child(node)
	
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var res = engine.generate_house(10, 16, 0, 1009, false)
	var rooms = res.get("rooms", [])
	print("--- ROOM 7 PLAN ---")
	for r in rooms:
		if r.id == 7:
			print("Room 7 dict: ", r)
			var plan = HouseFurniturePlanner.plan_bedroom_furniture(res, r, 10.0, 16.0, 1009)
			for item in plan:
				print("  item: ", item.name, " pos=", item.position, " rot=", item.rotation_y)
		elif r.id == 1:
			print("Room 1 (Sala) dict: ", r)
			var plan = HouseFurniturePlanner.plan_living_room_furniture(res, r, 10.0, 16.0)
			for item in plan:
				print("  item: ", item.name, " pos=", item.position, " rot=", item.rotation_y)
	quit(0)
