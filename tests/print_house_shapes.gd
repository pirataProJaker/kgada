extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ProceduralHouseEngine no existe")
		quit(1)
		return

	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	for zone_idx in range(3):
		var zone_name = ["ColoniaVieja", "ColoniaNueva", "ZonaX"][zone_idx]
		var w = 18 if zone_idx == 2 else (10 if zone_idx == 0 else 7)
		var d = 20 if zone_idx == 2 else (16 if zone_idx == 0 else 15)
		print("\n================== %s (%dx%d) ==================" % [zone_name, w, d])
		for s in [1009, 2024, 777]:
			var res = engine.generate_house(w, d, zone_idx, s, false)
			var map_f1 = res.get("room_map_floor1", PackedByteArray())
			var map_f2 = res.get("room_map_floor2", PackedByteArray())
			var rooms = res.get("rooms", [])
			print("\n--- Semilla %d | Pisos: %s | Cuartos: %d ---" % [s, res.get("floors"), rooms.size()])
			print("PLANTA BAJA:")
			for z in range(d):
				var line = ""
				for x in range(w):
					var id = map_f1[z * w + x]
					line += str(id) if id > 0 else "."
				print(line)
			if int(res.get("floors", 1)) >= 2:
				print("PLANTA ALTA:")
				for z in range(d):
					var line = ""
					for x in range(w):
						var id = map_f2[z * w + x]
						line += str(id) if id > 0 else "."
					print(line)
	quit(0)
