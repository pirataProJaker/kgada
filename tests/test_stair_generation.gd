extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ERROR: ProceduralHouseEngine not in ClassDB")
		quit(1)
		return

	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	print("ProceduralHouseEngine instantiated successfully.")

	var test_configs = [
		{"name": "ColoniaVieja 10x16 s=1009", "w": 10, "d": 16, "zone": 0, "seed": 1009},
		{"name": "ColoniaNueva 7x15 s=1009", "w": 7, "d": 15, "zone": 1, "seed": 1009},
		{"name": "ColoniaNueva 7x15 s=2018", "w": 7, "d": 15, "zone": 1, "seed": 2018},
		{"name": "ColoniaNueva 7x15 s=8072", "w": 7, "d": 15, "zone": 1, "seed": 8072},
		{"name": "ZonaX 18x20 s=2018", "w": 18, "d": 20, "zone": 2, "seed": 2018},
		{"name": "ZonaX 18x20 s=9999", "w": 18, "d": 20, "zone": 2, "seed": 9999},
	]

	for cfg in test_configs:
		print("\n==========================================")
		print("Testing %s" % cfg["name"])
		var res: Dictionary = engine.generate_house(cfg["w"], cfg["d"], cfg["zone"], cfg["seed"], true)

		var map_f2: PackedByteArray = res.get("room_map_floor2", PackedByteArray())
		var f2_count := 0
		for b in map_f2:
			if b > 0:
				f2_count += 1
		print("Floor 2 active cells: %d" % f2_count)

		if res.has("stair"):
			var st: Dictionary = res["stair"]
			print(">>> STAIR GENERATED:")
			print("    Type: %s (0=Straight, 1=UShape)" % str(st.get("type")))
			print("    Pos: (x=%s, z=%s)" % [str(st.get("x")), str(st.get("z"))])
			print("    Size: (w=%s, l=%s)" % [str(st.get("width")), str(st.get("length"))])
			print("    Orientation: %s" % str(st.get("orientation")))
		else:
			print(">>> NO STAIR (Single story or no valid placement)")

		var rooms: Array = res.get("rooms", [])
		print("Rooms (%d total):" % rooms.size())
		for r in rooms:
			print("  - F%d: %s (id=%d) [%d..%d, %d..%d]" % [
				r.get("floor", 1),
				r.get("name", "Unknown"),
				r.get("id", -1),
				r.get("x_min", 0), r.get("x_max", 0),
				r.get("z_min", 0), r.get("z_max", 0)
			])

	quit(0)
