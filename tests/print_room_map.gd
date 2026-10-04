extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var res = engine.generate_house(9, 16, 0, 2018, true)
	
	# Blueprint room map
	var f1: PackedByteArray = res.get("room_map_floor1", PackedByteArray())
	var f2: PackedByteArray = res.get("room_map_floor2", PackedByteArray())
	
	print("Floor 1 room map (9x16):")
	for z in range(16):
		var line = ""
		for x in range(9):
			line += "%d " % f1[z * 9 + x]
		print("  z=%2d: %s" % [z, line])
		
	print("\nFloor 2 room map (9x16):")
	for z in range(16):
		var line = ""
		for x in range(9):
			line += "%d " % f2[z * 9 + x]
		print("  z=%2d: %s" % [z, line])
		
	quit(0)
