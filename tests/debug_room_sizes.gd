extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ProceduralHouseEngine no existe")
		quit(1)
		return

	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	var sc = showcase_scn.instantiate()
	sc._init_parcel_definitions()

	print("--- AUDITORIA DE DIMENSIONES DE CUARTOS EN LAS 15 CASAS ---")
	for i in range(sc._parcels_config.size()):
		var p = sc._parcels_config[i]
		var rect = p["rect"]
		var w = int(rect.size.x)
		var d = int(rect.size.y)
		if p["front_side"] == 1 or p["front_side"] == 3:
			w = int(rect.size.y)
			d = int(rect.size.x)
		var s = sc._corner_seeds[i % sc._corner_seeds.size()]
		var res = engine.generate_house(w, d, p["default_zone"], s, false)
		var map_f1 = res.get("room_map_floor1", PackedByteArray())
		var map_f2 = res.get("room_map_floor2", PackedByteArray())
		for r in res.get("rooms", []):
			var map = map_f1 if r.floor == 1 else map_f2
			var count = 0
			var min_rx = w
			var max_rx = -1
			var min_rz = d
			var max_rz = -1
			for z in range(r.z_min, r.z_max):
				for x in range(r.x_min, r.x_max):
					if z * w + x < map.size() and map[z * w + x] == r.id:
						count += 1
						min_rx = min(min_rx, x)
						max_rx = max(max_rx, x)
						min_rz = min(min_rz, z)
						max_rz = max(max_rz, z)
			var actual_w = (max_rx - min_rx + 1) if count > 0 else 0
			var actual_d = (max_rz - min_rz + 1) if count > 0 else 0
			if actual_w <= 1 or actual_d <= 1 or count < 4:
				print("Casa %d Semilla %d Piso %d: ALERTA CUARTO PLANO O TRUNCADO: [%s] Celdas=%d, Real: %dx%d (declarado: %dx%d)" % [
					i, s, r.floor, r.name, count, actual_w, actual_d, r.x_max - r.x_min, r.z_max - r.z_min
				])

	print("\n--- TEST CON 300 SEMILLAS ALEATORIAS (100 POR CADA ZONA) ---")
	var total_rooms_checked = 0
	var flat_rooms_found = 0
	for zone_idx in range(3):
		var zone_name = ["ColoniaVieja", "ColoniaNueva", "ZonaX"][zone_idx]
		for test_seed in range(100):
			var res = engine.generate_house(10, 16, zone_idx, test_seed, false)
			var map_f1 = res.get("room_map_floor1", PackedByteArray())
			var map_f2 = res.get("room_map_floor2", PackedByteArray())
			for r in res.get("rooms", []):
				total_rooms_checked += 1
				var map = map_f1 if r.floor == 1 else map_f2
				var count = 0
				var min_rx = 10
				var max_rx = -1
				var min_rz = 16
				var max_rz = -1
				for z in range(r.z_min, r.z_max):
					for x in range(r.x_min, r.x_max):
						if z * 10 + x < map.size() and map[z * 10 + x] == r.id:
							count += 1
							min_rx = min(min_rx, x)
							max_rx = max(max_rx, x)
							min_rz = min(min_rz, z)
							max_rz = max(max_rz, z)
				var actual_w = (max_rx - min_rx + 1) if count > 0 else 0
				var actual_d = (max_rz - min_rz + 1) if count > 0 else 0
				if actual_w <= 1 or actual_d <= 1 or count < 4:
					flat_rooms_found += 1
					print("  Zona %s Semilla %d Piso %d: ⚠️ CUARTO PLANO: [%s] Celdas=%d, Real: %dx%d (declarado: %dx%d)" % [
						zone_name, test_seed, r.floor, r.name, count, actual_w, actual_d, r.x_max - r.x_min, r.z_max - r.z_min
					])

	print("Auditoría completada: %d cuartos verificados. Cuartos planos encontrados: %d" % [total_rooms_checked, flat_rooms_found])
	quit(0 if flat_rooms_found == 0 else 1)
