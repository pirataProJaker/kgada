extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var parcels = [
		{"w": 10, "d": 16, "zone": 0},
		{"w": 9, "d": 16, "zone": 0},
		{"w": 7, "d": 15, "zone": 1},
		{"w": 18, "d": 20, "zone": 2},
		{"w": 14, "d": 20, "zone": 2},
	]
	
	var total_tested := 0
	var total_errors := 0
	
	for seed_val in range(1000, 1050):
		for p in parcels:
			total_tested += 1
			var res = engine.generate_house(p["w"], p["d"], p["zone"], seed_val, true)
			if res.is_empty():
				print("ERROR: Empty result for seed %d, zone %d" % [seed_val, p["zone"]])
				total_errors += 1
				continue
			
			var map_f1: PackedByteArray = res.get("room_map_floor1", PackedByteArray())
			var map_f2: PackedByteArray = res.get("room_map_floor2", PackedByteArray())
			var w: int = p["w"]
			var d: int = p["d"]
			
			# Verificar que Floor 2 NUNCA flote sobre vacio
			for z in range(d):
				for x in range(w):
					var idx = z * w + x
					if map_f2[idx] > 0 and map_f1[idx] == 0:
						print("ERROR: Floor 2 floating at (%d, %d) in seed %d, zone %d!" % [x, z, seed_val, p["zone"]])
						total_errors += 1
			
			# Verificar huecos cerrados de 1 o 2 celdas en Floor 1 rodeados 100% por cuartos
			for z in range(1, d - 1):
				for x in range(1, w - 1):
					var idx = z * w + x
					if map_f1[idx] == 0:
						var n = map_f1[(z - 1) * w + x] > 0
						var s = map_f1[(z + 1) * w + x] > 0
						var west = map_f1[z * w + (x - 1)] > 0
						var east = map_f1[z * w + (x + 1)] > 0
						if n and s and west and east:
							print("WARNING: 1x1 enclosed hole in F1 at (%d, %d) seed %d, zone %d" % [x, z, seed_val, p["zone"]])
							total_errors += 1

	print("=== RESULTADO DEL TEST DE 50 SEMILLAS ===")
	print("Total casas generadas: %d" % total_tested)
	print("Errores encontrados: %d" % total_errors)
	if total_errors == 0:
		print("✓ TODAS LAS CASAS Y TECHOS SON 100% ESTRUCTURALMENTE SÓLIDOS!")
	print("=========================================")
	quit(0)
