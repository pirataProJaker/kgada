extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	# House 12: rect = Rect2(-17.0, 7.0, 10.0, 16.0), front_side = 0, default_zone = 0, seed = 4036 (index 12 % 15 = 12 -> 4444)
	# Wait, index 12 in corner seeds:
	# [1009, 2018, 3027, 4036, 5045, 6054, 7063, 8072, 9081, 1111, 2222, 3333, 4444, 5555, 6666]
	# index 12 is 4444!
	var w = 10
	var d = 16
	var res = engine.generate_house(w, d, 0, 4444, true)
	var rug_mesh = FurniturePropsBuilder.get_rug_braided_mesh()
	print("Rug mesh AABB: ", rug_mesh.get_aabb())
	for r in res.get("rooms", []):
		if r.name == "Recámara":
			print("Recámara id=%d (F%d) x=%d..%d z=%d..%d" % [r.id, r.floor, r.x_min, r.x_max, r.z_min, r.z_max])
			var plan = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), 4444)
			for it in plan:
				print("  -> %s pos=%s rot=%.2f" % [it.name, it.position, it.rotation_y])
	var f2 = res.get("room_map_floor2", PackedByteArray())
	print("Floor 2 map (w=%d, d=%d):" % [w, d])
	for z in range(d):
		var line = ""
		for x in range(w):
			line += "%2d " % f2[z * w + x]
		print("z=%2d: %s" % [z, line])
		
	for r in res.get("rooms", []):
		if r.floor == 2 and r.name == "Recámara":
			print("Recámara F2 id=%d: x=%d..%d, z=%d..%d" % [r.id, r.x_min, r.x_max, r.z_min, r.z_max])
			var plan = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), 3350)
			for it in plan:
				print("  -> %s pos=%s rot=%.2f" % [it.name, it.position, it.rotation_y])
				var gx = int(floor(it.position.x + float(w) * 0.5))
				var gz = int(floor(it.position.z + float(d) * 0.5))
				var val = f2[gz * w + gx] if (gx >= 0 and gx < w and gz >= 0 and gz < d) else -1
				print("     cell=(%d, %d) val=%d" % [gx, gz, val])
	quit(0)
