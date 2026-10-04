extends SceneTree

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	var scn = showcase_scn.instantiate()
	scn._init_parcel_definitions()
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	
	for i in range(scn._parcels_config.size()):
		var p_cfg: Dictionary = scn._parcels_config[i]
		var rect: Rect2 = p_cfg["rect"]
		var front_side: int = p_cfg["front_side"]
		var house_seed: int = scn._corner_seeds[i % scn._corner_seeds.size()]
		var zone_type: int = p_cfg["default_zone"]
		
		var w: int = int(rect.size.x)
		var d: int = int(rect.size.y)
		if front_side == 1 or front_side == 3:
			w = int(rect.size.y)
			d = int(rect.size.x)
			
		var res: Dictionary = engine.generate_house(w, d, zone_type, house_seed, false)
		var rooms: Array = res.get("rooms", [])
		var has_bath := false
		var has_bed := false
		for r in rooms:
			if r.get("name") == "Baño": has_bath = true
			if r.get("name") == "Recámara": has_bed = true
		
		print("Parcel %d (%s) | Zone: %d | Seed: %d | Size: %dx%d | Rooms: %d | Doors: %d" % [
			i, p_cfg["corner_name"], zone_type, house_seed, w, d, rooms.size(), res.get("doors", []).size()
		])
		for r in rooms:
			print("   - %s (%s) Floor %d: [%.0f..%.0f, %.0f..%.0f]" % [
				r.get("name"), r.get("id"), r.get("floor", 1),
				r.get("x_min", 0), r.get("x_max", 0), r.get("z_min", 0), r.get("z_max", 0)
			])
		for dr in res.get("doors", []):
			print("   * Door: pos=%s style=%d is_main=%s" % [dr.get("position"), dr.get("style"), dr.get("is_main")])
	
	quit(0)
