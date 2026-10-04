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
		var map_f1 = res.get("room_map_floor1", PackedByteArray())
		for z in range(1, d - 1):
			for x in range(1, w - 1):
				if map_f1[z * w + x] == 0:
					var n = map_f1[(z-1)*w + x] > 0
					var s_cell = map_f1[(z+1)*w + x] > 0
					var w_cell = map_f1[z*w + (x-1)] > 0
					var e = map_f1[z*w + (x+1)] > 0
					if n and s_cell and w_cell and e:
						print("FOUND ENCLOSED HOLE in parcel %d (%s) seed %d at (%d, %d)" % [i, p["corner_name"], s, x, z])

	quit(0)
