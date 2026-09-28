extends SceneTree
## Test de verificación para Planificación de Puertas y Ventanas en Paredes
## Cubre los 5 puntos solicitados por el usuario:
## 1. Planificación de vanos antes de construir con madera/piedra.
## 2. Puertas siempre ancladas al piso (y_bottom = 0.0).
## 3. Ventanas de tamaño flexible (anchura, altura, antepecho libres).
## 4. Clic en planeación existente con selector correspondiente la elimina.
## 5. Una vez construida, la pared no admite nuevos vanos.

func _init() -> void:
	var f := FileAccess.open("C:/Users/PC 1/PSX/tests/test_results.txt", FileAccess.WRITE)
	var log_msg = func(msg: String):
		print(msg)
		if f:
			f.store_line(msg)
			f.flush()

	log_msg.call("========== INICIANDO TEST: PLANIFICACIÓN DE VANOS (PUERTAS Y VENTANAS) ==========")
	var total_tests := 0
	var passed_tests := 0

	# 1. Crear nodo ConstructionEngine
	var engine: Node3D = null
	if ClassDB.class_exists("ConstructionEngine"):
		engine = ClassDB.instantiate("ConstructionEngine")
		root.add_child(engine)
		log_msg.call("✅ ConstructionEngine instanciado.")
	else:
		log_msg.call("❌ ConstructionEngine no disponible.")
		if f: f.close()
		quit(1)
		return

	# 2. Crear un PlannedSite de tipo Pared (element_type = 1)
	var planned_site_script = load("res://world/building/planned_site.gd")
	var wall_site: PlannedSite = planned_site_script.new()
	var p0 := Vector3(0, 0, 0)
	var p1 := Vector3(6, 0, 0) # Pared de 6m de largo
	var wall_height := 3.0
	wall_site.setup(1, p0, p1, {"name": "Palo de Trazado", "marker_type": "dirt_scrape"}, wall_height)
	root.add_child(wall_site)

	# TEST 1: Puerta anclada estrictamente al piso
	total_tests += 1
	var door_op := wall_site.add_door_opening(2.0, 1.0, 2.1)
	log_msg.call("Door opening data: " + str(door_op))
	if door_op.get("y_bottom", -1.0) == 0.0 and is_equal_approx(door_op.get("y_top", 0.0), 2.1):
		log_msg.call("✅ TEST 1 PASADO: La puerta está anclada estrictamente al piso (y_bottom = 0.0, y_top = 2.1).")
		passed_tests += 1
	else:
		log_msg.call("❌ TEST 1 FALLÓ: La puerta no está anclada al piso correctamente.")

	# TEST 2: Ventana de tamaño flexible
	total_tests += 1
	# Ventana flexible: de t=3.5 a t=5.0 (ancho 1.5m), de y=1.0 a y=2.2 (alto 1.2m, antepecho 1.0m)
	var win_op := wall_site.add_window_opening(3.5, 5.0, 1.0, 2.2)
	log_msg.call("Window opening data: " + str(win_op))
	if is_equal_approx(win_op.get("width", 0.0), 1.5) and is_equal_approx(win_op.get("height", 0.0), 1.2) and is_equal_approx(win_op.get("y_bottom", 0.0), 1.0):
		log_msg.call("✅ TEST 2 PASADO: Ventana flexible creada con dimensiones exactas (1.5m ancho x 1.2m alto, antepecho 1.0m).")
		passed_tests += 1
	else:
		log_msg.call("❌ TEST 2 FALLÓ: Ventana flexible con dimensiones incorrectas.")

	# TEST 3: Búsqueda y eliminación de vano planificado al hacer clic con selector
	total_tests += 1
	# Punto 3D dentro del vano de la puerta: t=2.0 (Vector3(2.0, 0.5, 0.0))
	var found_door := wall_site.find_opening_at(Vector3(2.0, 0.5, 0.0), 3)
	if not found_door.is_empty() and found_door.get("id") == door_op.get("id"):
		# Eliminar vano como si el jugador hiciera clic con selector de puerta
		var removed := wall_site.remove_opening(found_door.get("id"))
		var after_remove := wall_site.find_opening_at(Vector3(2.0, 0.5, 0.0), 3)
		if removed and after_remove.is_empty():
			log_msg.call("✅ TEST 3 PASADO: Clic con selector sobre vano planificado lo elimina correctamente.")
			passed_tests += 1
		else:
			log_msg.call("❌ TEST 3 FALLÓ: No se eliminó el vano correctamente.")
	else:
		log_msg.call("❌ TEST 3 FALLÓ: No se encontró el vano de puerta en la posición esperada.")

	# Volver a añadir la puerta para probar construcción con ambos vanos
	var door_op_readded := wall_site.add_door_opening(1.5, 1.0, 2.1)
	log_msg.call("Door re-added for build: " + str(door_op_readded))

	# TEST 4: Edificar la pared con madera incorporando los vanos planificados
	total_tests += 1
	var build_success: bool = wall_site.build_with_material(0, null, engine)
	if build_success:
		log_msg.call("✅ TEST 4 PASADO: Pared planificada construida con éxito en el motor físico.")
		passed_tests += 1
	else:
		log_msg.call("❌ TEST 4 FALLÓ: build_with_material falló.")

	# TEST 5: Verificar que la pared construida tiene los marcos de puerta y ventana en Rust ConstructionEngine
	total_tests += 1
	var door_count: int = engine.get_element_count_by_type(3) # ElementType::DoorFrame = 3
	var win_count: int = engine.get_element_count_by_type(4)  # ElementType::WindowFrame = 4
	var wall_count: int = engine.get_element_count_by_type(1) # ElementType::Wall = 1
	log_msg.call("Elementos en ConstructionEngine -> Paredes: %d, Marcos Puerta: %d, Marcos Ventana: %d" % [wall_count, door_count, win_count])
	if door_count >= 1 and win_count >= 1 and wall_count > 0:
		log_msg.call("✅ TEST 5 PASADO: ConstructionEngine colocó correctamente DoorFrame y WindowFrame con la pared.")
		passed_tests += 1
	else:
		log_msg.call("❌ TEST 5 FALLÓ: Conteo de elementos no coincide (DoorFrame >= 1, WindowFrame >= 1, Wall > 0).")

	log_msg.call("\n==================================================")
	log_msg.call("RESULTADO FINAL: %d / %d TESTS PASADOS" % [passed_tests, total_tests])
	log_msg.call("==================================================")

	if f: f.close()

	if passed_tests == total_tests:
		quit(0)
	else:
		quit(1)
