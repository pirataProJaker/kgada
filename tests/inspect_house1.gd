extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	# House 1: rect = Rect2(-26.0, -23.0, 9.0, 16.0), front_side = 2, default_zone = 0, seed = 2018
	var w = 9
	var d = 16
	var res = engine.generate_house(w, d, 0, 2018, true)
	print("=== HOUSE 1 (seed=2018, w=9, d=16) ===")
	print("Rooms:")
	for r in res.get("rooms", []):
		print("  Room %d: %s floor=%d x=%d..%d z=%d..%d" % [r.id, r.name, r.floor, r.x_min, r.x_max, r.z_min, r.z_max])
		if r.name == "Recámara":
			var plan = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), 2018)
			for item in plan:
				print("    -> %s: pos=%s rot=%.2f" % [item.name, item.position, item.rotation_y])
		elif r.name == "Sala":
			var plan = HouseFurniturePlanner.plan_living_room_furniture(res, r, float(w), float(d))
			for item in plan:
				print("    -> %s: pos=%s rot=%.2f" % [item.name, item.position, item.rotation_y])
	
	print("\nDoors:")
	for dr in res.get("doors", []):
		print("  Door: pos=%s sz=%s" % [dr.position, dr.size])
		
	print("\nWindows:")
	for wn in res.get("windows", []):
		print("  Window: pos=%s sz=%s floor=%s" % [wn.position, wn.size, wn.get("floor", 1)])
	quit(0)
