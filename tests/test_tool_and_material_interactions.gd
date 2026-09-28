extends SceneTree

const STICK_RES = preload("res://content/building/stick_tool.tres")
const WOOD_RES = preload("res://content/building/wood_material.tres")

func _init() -> void:
	print("\n========== INICIANDO TEST: VERIFICACIÓN DE MANOS, PALO Y MADERA ==========")
	var total_tests := 0
	var passed_tests := 0

	# 1. Instanciar escena de prueba con Player y ConstructionEngine
	var scene = preload("res://tests/test_construction_chunk.tscn").instantiate()
	root.add_child(scene)

	for i in range(3):
		await process_frame

	var player: CharacterBody3D = scene.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var controller: VectorialConstructionController = player.get_node("VectorialConstructionController")
	var engine = scene.get_node("ConstructionEngine")

	# Asegurar slots
	inv.set_slot(0, STICK_RES, 1)
	inv.set_slot(3, WOOD_RES, 64)
	inv.clear_slot(7) # Manos vacías

	# Crear un PlannedSite de pared con una ventana
	var planned_site_script = preload("res://world/building/planned_site.gd")
	var wall_site: PlannedSite = planned_site_script.new()
	var p0 := Vector3(0, 0, 0)
	var p1 := Vector3(6, 0, 0)
	wall_site.setup(1, p0, p1, {"name": "Palo de Trazado", "marker_type": "dirt_scrape"}, 3.0)
	scene.add_child(wall_site)

	# Añadir ventana de t=2.0 a 3.5, y=1.0 a 2.0
	var win := wall_site.add_window_opening(2.0, 3.5, 1.0, 2.0)
	print("Ventana añadida al trazado: ", win)

	# =========================================================================
	# TEST 1: SIN EL PALO EN LA MANO (Manos vacías)
	# Clic en la ventana NO DEBE BORRARLA.
	# =========================================================================
	total_tests += 1
	inv.select_hotbar_slot(7)
	controller._process(0.016)

	# El controlador antes borraba la ventana porque active_element_type era 4
	controller.active_element_type = 4 # Modo ventana residual

	var win_center := Vector3(2.75, 1.5, 0.0)
	var fake_collider = wall_site.collision_body

	# Intentar clic sin herramienta en la mano
	controller._handle_opening_click(win_center, fake_collider)

	# Verificar que la ventana SIGUE EXISTIENDO
	var check_win = wall_site.find_opening_at(win_center, 4)
	if not check_win.is_empty() and wall_site.openings.size() == 1:
		print("✅ TEST 1 PASADO: Sin el palo en la mano, NO se borra la ventana (protegido contra clics accidentales).")
		passed_tests += 1
	else:
		printerr("❌ TEST 1 FALLÓ: La ventana fue borrada sin tener el palo en la mano!")

	# =========================================================================
	# TEST 2: CON MADERA EN LA MANO
	# Clic en el trazado planificado DEBE EDIFICAR LA PARED
	# =========================================================================
	total_tests += 1
	inv.select_hotbar_slot(3) # WOOD_RES
	controller._process(0.016)

	var detected_mat := controller._detect_held_material_type()
	print("Material detectado en mano: %d (0 = Madera)" % detected_mat)

	if detected_mat == 0:
		var initial_wood: int = inv.get_slot(3).count
		var site = controller._get_planned_site_from_collider(fake_collider)
		if site == null:
			site = controller._find_planned_site_near(Vector3(3, 1, 0), 1.2)

		if site != null:
			site.build_with_material(detected_mat, inv, engine)
			var after_wood: int = inv.get_slot(3).count
			var wall_count: int = engine.get_element_count_by_type(1)
			var win_count: int = engine.get_element_count_by_type(4)
			print("Paredes construidas: %d, Ventanas construidas: %d, Madera restante: %d" % [wall_count, win_count, after_wood])
			if wall_count > 0 and win_count >= 1 and after_wood == (initial_wood - 1):
				print("✅ TEST 2 PASADO: Con Madera en la mano, el trazado se edifica correctamente con su ventana integrada y consume material.")
				passed_tests += 1
			else:
				printerr("❌ TEST 2 FALLÓ: No se construyó la pared o no se consumió madera.")
		else:
			printerr("❌ TEST 2 FALLÓ: No se detectó el PlannedSite.")
	else:
		printerr("❌ TEST 2 FALLÓ: No se detectó madera en la mano.")

	# =========================================================================
	# TEST 3: CON EL PALO EN LA MANO Y MODO VENTANA
	# Clic en una ventana planificada SÍ DEBE BORRARLA
	# =========================================================================
	total_tests += 1
	var wall_site2: PlannedSite = planned_site_script.new()
	wall_site2.setup(1, Vector3(10, 0, 0), Vector3(16, 0, 0), {"name": "Palo de Trazado", "marker_type": "dirt_scrape"}, 3.0)
	scene.add_child(wall_site2)
	wall_site2.add_window_opening(2.0, 3.5, 1.0, 2.0)

	# Equipar el palo (slot 0)
	inv.select_hotbar_slot(0)
	controller._process(0.016)
	controller.active_element_type = 4 # Modo ventana

	# Clic con el palo sobre la ventana
	var win2_pos := Vector3(12.75, 1.5, 0.0)
	var fake_collider2 = wall_site2.collision_body
	controller._handle_opening_click(win2_pos, fake_collider2)

	var check_win2 = wall_site2.find_opening_at(win2_pos, 4)
	if check_win2.is_empty() and wall_site2.openings.is_empty():
		print("✅ TEST 3 PASADO: Con el palo en la mano y selector de ventana, la ventana sí se borra correctamente al hacer clic.")
		passed_tests += 1
	else:
		printerr("❌ TEST 3 FALLÓ: No se borró la ventana teniendo el palo equipado.")

	print("\n==================================================")
	print("RESULTADO FINAL: %d / %d TESTS PASADOS" % [passed_tests, total_tests])
	print("==================================================")

	quit(0 if passed_tests == total_tests else 1)
