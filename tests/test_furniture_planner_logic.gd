extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ERROR: ProceduralHouseEngine no existe.")
		quit(1)
		return

	var engine = ClassDB.instantiate("ProceduralHouseEngine")

	# Probar con dos casas:
	# Casa 1: NW Colonia Vieja (10x16m, seed 1009)
	# Casa 2: NE Infonavit (7x15m, seed 1009)
	for test_case in [
		{"name": "NW Colonia Vieja", "w": 10, "d": 16, "zone": 0, "seed": 1009, "pos": Vector3(-12.0, 0.16, -15.0), "rot_y": PI},
		{"name": "NE Infonavit Lote 1", "w": 7, "d": 15, "zone": 1, "seed": 1009, "pos": Vector3(10.5, 0.16, -14.5), "rot_y": 0.0}
	]:
		print("\n========================================================")
		print("PROBANDO PLANIFICADOR EN: ", test_case.name)
		print("========================================================")
		var w: int = test_case.w
		var d: int = test_case.d
		var zone: int = test_case.zone
		var s: int = test_case.seed
		var house_pos: Vector3 = test_case.pos
		var rot_y: float = test_case.rot_y
		var house_xform := Transform3D(Basis(Vector3.UP, rot_y), house_pos)

		var res: Dictionary = engine.generate_house(w, d, zone, s, false)

		# 1. Analizar Fachada Frontal para Medidor CFE
		print("\n--- 1. BÚSQUEDA DE TRAMO SÓLIDO PARA MEDIDOR CFE EN FACHADA ---")
		var facade_z_local := -float(d) * 0.5
		var facade_openings: Array[Dictionary] = []

		for win in res.get("windows", []):
			if win.floor == 1 and absf(win.position.z - facade_z_local) < 0.3:
				var sz: Vector2 = win.size
				facade_openings.append({
					"type": "window",
					"x_min": win.position.x - sz.x * 0.5 - 0.40, # buffer 40cm
					"x_max": win.position.x + sz.x * 0.5 + 0.40,
					"center": win.position.x
				})
				print("  Ventana en fachada local X=%.2f, rango excluido: [%.2f..%.2f]" % [win.position.x, win.position.x - sz.x * 0.5 - 0.40, win.position.x + sz.x * 0.5 + 0.40])

		for dr in res.get("doors", []):
			if absf(dr.position.z - facade_z_local) < 0.3:
				var sz: Vector3 = dr.size
				facade_openings.append({
					"type": "door",
					"x_min": dr.position.x - sz.x * 0.5 - 0.45, # buffer 45cm
					"x_max": dr.position.x + sz.x * 0.5 + 0.45,
					"center": dr.position.x
				})
				print("  Puerta en fachada local X=%.2f, rango excluido: [%.2f..%.2f]" % [dr.position.x, dr.position.x - sz.x * 0.5 - 0.45, dr.position.x + sz.x * 0.5 + 0.45])

		# Encontrar tramos libres en [-w/2 + 0.25 .. w/2 - 0.25]
		var wall_x0 := -float(w) * 0.5 + 0.25
		var wall_x1 := float(w) * 0.5 - 0.25
		facade_openings.sort_custom(func(a, b): return a.x_min < b.x_min)

		var cur_x := wall_x0
		var solid_piers: Array[Dictionary] = []
		for op in facade_openings:
			if op.x_min > cur_x + 0.50: # Al menos 50cm de muro sólido continuo
				solid_piers.append({"x_min": cur_x, "x_max": op.x_min, "width": op.x_min - cur_x})
			cur_x = maxf(cur_x, op.x_max)
		if wall_x1 > cur_x + 0.50:
			solid_piers.append({"x_min": cur_x, "x_max": wall_x1, "width": wall_x1 - cur_x})

		for pier in solid_piers:
			var pier_center: float = (pier.x_min + pier.x_max) * 0.5
			var world_meter_pos = house_xform * Vector3(pier_center, 1.55, facade_z_local - 0.06)
			print("  -> TRAMO SÓLIDO VÁLIDO: Local X[%.2f..%.2f] (Ancho: %.2fm) -> Medidor World: (%.2f, %.2f, %.2f)" % [
				pier.x_min, pier.x_max, pier.width,
				world_meter_pos.x, world_meter_pos.y, world_meter_pos.z
			])

		# 2. Analizar Cocina y ubicación de Estufa / Gabinetes / Refri
		print("\n--- 2. ANÁLISIS DE COCINA ---")
		for r in res.get("rooms", []):
			if r.name == "Cocina" and r.floor == 1:
				var rx0: float = float(r.x_min) - w * 0.5
				var rx1: float = float(r.x_max) - w * 0.5
				var rz0: float = float(r.z_min) - d * 0.5
				var rz1: float = float(r.z_max) - d * 0.5
				print("  Cocina Local: X[%.2f..%.2f] Z[%.2f..%.2f] (Ancho: %.2fm, Fondo: %.2fm)" % [rx0, rx1, rz0, rz1, rx1 - rx0, rz1 - rz0])

				# 4 paredes candidatas
				var candidate_walls: Array[Dictionary] = [
					{"side": "East",  "is_x_wall": true,  "coord": rx1, "normal": Vector3(-1, 0, 0), "span_start": rz0, "span_end": rz1, "is_exterior": is_equal_approx(float(r.x_max), float(w))},
					{"side": "South", "is_x_wall": false, "coord": rz1, "normal": Vector3(0, 0, -1), "span_start": rx0, "span_end": rx1, "is_exterior": is_equal_approx(float(r.z_max), float(d))},
					{"side": "West",  "is_x_wall": true,  "coord": rx0, "normal": Vector3(1, 0, 0),  "span_start": rz0, "span_end": rz1, "is_exterior": is_equal_approx(float(r.x_min), 0.0)},
					{"side": "North", "is_x_wall": false, "coord": rz0, "normal": Vector3(0, 0, 1),  "span_start": rx0, "span_end": rx1, "is_exterior": is_equal_approx(float(r.z_min), 0.0)},
				]

				# Detectar qué pared colinda con el Comedor (vano social abierto)
				for other_r in res.get("rooms", []):
					if other_r.name == "Comedor" and other_r.floor == 1:
						var ox0: float = float(other_r.x_min) - w * 0.5
						var ox1: float = float(other_r.x_max) - w * 0.5
						var oz0: float = float(other_r.z_min) - d * 0.5
						var oz1: float = float(other_r.z_max) - d * 0.5

						for wall in candidate_walls:
							if wall.side == "North" and is_equal_approx(rz0, oz1) and ox1 > rx0 and ox0 < rx1:
								wall["is_open_social_pass"] = true
								print("  -> Pared NORTE colinda con Comedor: ¡VANO SOCIAL ABIERTO!")
							elif wall.side == "South" and is_equal_approx(rz1, oz0) and ox1 > rx0 and ox0 < rx1:
								wall["is_open_social_pass"] = true
								print("  -> Pared SUR colinda con Comedor: ¡VANO SOCIAL ABIERTO!")
							elif wall.side == "West" and is_equal_approx(rx0, ox1) and oz1 > rz0 and oz0 < rz1:
								wall["is_open_social_pass"] = true
								print("  -> Pared OESTE colinda con Comedor: ¡VANO SOCIAL ABIERTO!")
							elif wall.side == "East" and is_equal_approx(rx1, ox0) and oz1 > rz0 and oz0 < rz1:
								wall["is_open_social_pass"] = true
								print("  -> Pared ESTE colinda con Comedor: ¡VANO SOCIAL ABIERTO!")

				# Evaluar paredes válidas
				for wall in candidate_walls:
					if wall.get("is_open_social_pass", false):
						continue
					print("  Pared Candidata: %s (Coord: %.2f, Exterior: %s, Largo: %.2fm)" % [
						wall.side, wall.coord, wall.is_exterior, wall.span_end - wall.span_start
					])

	quit(0)
