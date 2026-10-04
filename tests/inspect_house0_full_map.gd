extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var w := 10
	var d := 16
	var h_seed := 1009
	var res = engine.generate_house(w, d, 0, h_seed, false)
	var map = res.get("room_map_floor1", PackedByteArray())
	print("--- MAP FLOOR 1 (W=%d, D=%d) ---" % [w, d])
	for z in range(d):
		var s := "Z=%2d: " % z
		for x in range(w):
			s += "%2d " % map[z * w + x]
		print(s)
	quit(0)
