extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ERROR: ProceduralHouseEngine no existe en ClassDB")
		quit(1)
		return

	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	print("✓ ProceduralHouseEngine instanciado con éxito.")

	var seeds_to_test: Array[int] = [1009, 2018, 3027, 4036, 5045, 6054, 7063, 8072, 9081, 1111, 2222, 3333, 4444, 5555, 6666]
	for s in range(50):
		if not seeds_to_test.has(s):
			seeds_to_test.append(s)

	var total_rooms_tested := 0
	var rooms_without_doors := 0
	var inaccessible_rooms: Array[Dictionary] = []

	for zone in [0, 1, 2]:
		var zone_name := "Colonia Vieja" if zone == 0 else ("Colonia Nueva" if zone == 1 else "Zona X (Mansiones)")
		print("\n=======================================================")
		print("Probando Zona %d: %s" % [zone, zone_name])
		print("=======================================================")

		for seed_val in seeds_to_test:
			var w := 14 if zone == 2 else (10 if zone == 1 else 9)
			var d := 14 if zone == 2 else (12 if zone == 1 else 10)
			var res: Dictionary = engine.generate_house(w, d, zone, seed_val, false)
			if res.is_empty():
				continue

			var rooms: Array = res.get("rooms", [])
			var doors: Array = res.get("doors", [])

			# Verificar puertas para cada habitación
			for r in rooms:
				var r_dict: Dictionary = r
				var r_id: int = int(r_dict.get("id", 0))
				var r_name: String = str(r_dict.get("name", ""))
				var r_fl: int = int(r_dict.get("floor", 1))
				var x_min: float = float(r_dict.get("x_min", 0))
				var x_max: float = float(r_dict.get("x_max", 0))
				var z_min: float = float(r_dict.get("z_min", 0))
				var z_max: float = float(r_dict.get("z_max", 0))

				# Convertir coordenadas locales a mundo (centrado en 0,0)
				# Según to_world_x: x_world = x_grid - w/2
				var rx0_world := x_min - float(w) * 0.5
				var rx1_world := x_max - float(w) * 0.5
				var rz0_world := z_min - float(d) * 0.5
				var rz1_world := z_max - float(d) * 0.5

				# Buscar puertas en el perímetro o dentro de la habitación
				var door_count := 0
				for dr in doors:
					var dr_pos: Vector3 = dr.get("position", Vector3.ZERO)
					# Verificar si la puerta está en el perímetro de este cuarto (con tolerancia de 0.25m)
					var on_x_boundary := (absf(dr_pos.x - rx0_world) < 0.25 or absf(dr_pos.x - rx1_world) < 0.25) and (dr_pos.z >= rz0_world - 0.25 and dr_pos.z <= rz1_world + 0.25)
					var on_z_boundary := (absf(dr_pos.z - rz0_world) < 0.25 or absf(dr_pos.z - rz1_world) < 0.25) and (dr_pos.x >= rx0_world - 0.25 and dr_pos.x <= rx1_world + 0.25)

					# Verificar piso (Y)
					var fl_y := 0.0 if r_fl == 1 else 2.80
					var on_floor := absf(dr_pos.y - fl_y) < 1.0

					if on_floor and (on_x_boundary or on_z_boundary):
						door_count += 1

				total_rooms_tested += 1
				if door_count == 0:
					rooms_without_doors += 1
					inaccessible_rooms.append({
						"zone": zone,
						"seed": seed_val,
						"room_id": r_id,
						"name": r_name,
						"floor": r_fl,
						"bounds": "[%d..%d, %d..%d]" % [int(x_min), int(x_max), int(z_min), int(z_max)]
					})

	print("\n=======================================================")
	print("RESULTADO DE ACCESIBILIDAD DE HABITACIONES:")
	print("Total de cuartos analizados: %d" % total_rooms_tested)
	print("Cuartos sin puertas detectados: %d" % rooms_without_doors)
	if rooms_without_doors > 0:
		print("DETALLES DE CUARTOS SIN PUERTAS:")
		for item in inaccessible_rooms:
			print(" - Zona %d, Seed %d, Cuarto %d (%s) Piso %d Bounds: %s" % [item["zone"], item["seed"], item["room_id"], item["name"], item["floor"], item["bounds"]])
	else:
		print("✓ ¡TODOS LOS CUARTOS TIENEN AL MENOS UNA PUERTA DE ACCESO VÁLIDA!")
	print("=======================================================\n")

	quit(0 if rooms_without_doors == 0 else 1)
