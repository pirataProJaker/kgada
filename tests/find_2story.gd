extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var sc = load("res://scenes/cross_street_houses_showcase.tscn").instantiate()
	sc._init_parcel_definitions()

	for i in range(sc._parcels_config.size()):
		var p = sc._parcels_config[i]
		var rect = p["rect"]
		var w = int(rect.size.x)
		var d = int(rect.size.y)
		if p["front_side"] == 1 or p["front_side"] == 3:
			w = int(rect.size.y)
			d = int(rect.size.x)
		var s = sc._corner_seeds[i % sc._corner_seeds.size()]
		var res = engine.generate_house(w, d, p["default_zone"], s, true)
		var map_f2: PackedByteArray = res.get("room_map_floor2", PackedByteArray())
		var has_f2 = false
		for b in map_f2:
			if b > 0:
				has_f2 = true
				break
		if has_f2:
			print("Parcel #%d (%s, w=%d, d=%d, zone=%d, seed=%d) HAS 2 FLOORS!" % [i, p["corner_name"], w, d, p["default_zone"], s])

	quit(0)
