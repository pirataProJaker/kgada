extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ERROR: ProceduralHouseEngine no existe.")
		quit(1)
		return

	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var w := 10
	var d := 16
	var zone := 0 # Colonia Vieja
	var seed_val := 1009
	var res: Dictionary = engine.generate_house(w, d, zone, seed_val, false)

	var house_pos := Vector3(-12.0, 0.16, -15.0)
	var rot_y := PI
	var house_basis := Basis(Vector3.UP, rot_y)
	var house_xform := Transform3D(house_basis, house_pos)

	print("=== HABITACIONES (Local & World) ===")
	for r in res.get("rooms", []):
		var rx0: float = float(r.x_min) - w * 0.5
		var rx1: float = float(r.x_max) - w * 0.5
		var rz0: float = float(r.z_min) - d * 0.5
		var rz1: float = float(r.z_max) - d * 0.5
		var w_min = house_xform * Vector3(rx0, 0, rz0)
		var w_max = house_xform * Vector3(rx1, 0, rz1)
		print("  %s (piso %d): local X[%.1f..%.1f] Z[%.1f..%.1f] -> world X[%.1f..%.1f] Z[%.1f..%.1f]" % [
			r.name, r.floor, rx0, rx1, rz0, rz1,
			minf(w_min.x, w_max.x), maxf(w_min.x, w_max.x),
			minf(w_min.z, w_max.z), maxf(w_min.z, w_max.z)
		])

	print("\n=== VENTANAS EN PLANTA BAJA (Piso 1) ===")
	for win in res.get("windows", []):
		if win.floor == 1:
			var loc_pos: Vector3 = win.position
			var world_pos = house_xform * loc_pos
			var world_norm = house_basis * win.normal
			print("  Ventana local: pos=%s sz=%s norm=%s -> world: pos=(%.2f, %.2f, %.2f) norm=(%.1f, %.1f, %.1f)" % [
				loc_pos, win.size, win.normal,
				world_pos.x, world_pos.y, world_pos.z,
				world_norm.x, world_norm.y, world_norm.z
			])

	print("\n=== PUERTAS EN PLANTA BAJA ===")
	for dr in res.get("doors", []):
		var loc_pos: Vector3 = dr.position
		var world_pos = house_xform * loc_pos
		print("  Puerta local: pos=%s sz=%s is_main=%s -> world pos=(%.2f, %.2f, %.2f)" % [
			loc_pos, dr.size, dr.is_main,
			world_pos.x, world_pos.y, world_pos.z
		])

	print("\n=== VERIFICACION DE POSICION VIEJA DEL MEDIDOR: Vector3(-13.8, 1.55, -7.06) ===")
	for win in res.get("windows", []):
		if win.floor == 1:
			var wp = house_xform * win.position
			var sz: Vector3 = win.size
			var x_min = wp.x - sz.x * 0.5
			var x_max = wp.x + sz.x * 0.5
			if -13.8 >= x_min and -13.8 <= x_max and absf(wp.z - (-7.06)) < 0.3:
				print("  -> ¡COLISIÓN CONFIRMADA! El medidor (-13.8) está adentro de la ventana en X[%.2f..%.2f]!" % [x_min, x_max])

	quit(0)
