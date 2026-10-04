extends SceneTree

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	var node = showcase_scn.instantiate()
	node.is_capture_mode = true
	root.add_child(node)
	
	var p_cfg = node._parcels_config[9]
	var rect: Rect2 = p_cfg["rect"]
	var front_side: int = p_cfg["front_side"]
	var h_seed: int = node._corner_seeds[9 % node._corner_seeds.size()]
	var z_mode = p_cfg["default_zone"]
	var w = int(rect.size.x) if (front_side == 0 or front_side == 2) else int(rect.size.y)
	var d = int(rect.size.y) if (front_side == 0 or front_side == 2) else int(rect.size.x)
	
	var res = node._engine.generate_house(w, d, z_mode, h_seed, true)
	var rooms = res.get("rooms", [])
	for r in rooms:
		if r.name == "Baño":
			print("Baño room: ", r)
			var items = HouseFurniturePlanner.plan_bathroom_furniture(res, r, float(w), float(d), h_seed)
			for item in items:
				print("  item: ", item)
	quit(0)
