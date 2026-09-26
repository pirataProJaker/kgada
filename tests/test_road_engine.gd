extends SceneTree

func _init() -> void:
	print("=======================================================")
	print("--- TEST DEL MOTOR PROCEDURAL DE CARRETERAS (RUST) ---")
	print("=======================================================")

	if not ClassDB.class_exists("RoadEngine"):
		printerr("ERROR: RoadEngine no esta disponible en ClassDB. Verifica la compilacion de rust_core.")
		quit(1)
		return

	print("✓ RoadEngine detectado en ClassDB correctamente.")

	var engine = ClassDB.instantiate("RoadEngine")
	if not engine:
		printerr("ERROR: No se pudo instanciar RoadEngine.")
		quit(1)
		return

	print("✓ Instancia de RoadEngine creada.")

	# 1. Creamos un cruce entre un Bulevar Dividido (Norte-Sur) y una Calle Residencial (Este-Oeste)
	# Nodo Central (Intersección): (0, 0, 0)
	var n_center: int = engine.add_node(Vector3(0, 0, 0))
	var n_north: int = engine.add_node(Vector3(0, 0, -60))
	var n_south: int = engine.add_node(Vector3(0, 0, 60))
	var n_west: int = engine.add_node(Vector3(-50, 0, 0))
	var n_east: int = engine.add_node(Vector3(50, 0, 0))

	print("✓ 5 Nodos añadidos. Centro ID: %d" % n_center)

	# 2. Tramo Bulevar Dividido Norte-Sur (2 tramos conectados a la interseccion)
	# Bulevar: 3 carriles por direccion, camellon de 8m con arboles, banquetas de 3m
	var blvd_params = {
		"lanes": 2,
		"median_width": 6.0,
		"median_style": "trees",
		"tree_spacing": 12.0,
		"sidewalk_width": 2.5
	}
	var r_north: int = engine.add_road(n_north, n_center, "divided_boulevard", blvd_params)
	var r_south: int = engine.add_road(n_center, n_south, "divided_boulevard", blvd_params)
	print("✓ Bulevar Norte-Sur añadido. Edge IDs: %d, %d" % [r_north, r_south])

	# 3. Tramo Calle Residencial Este-Oeste cruzando perpendicular
	# Residencial 2 carriles estandar
	var res_params = {
		"sidewalk_width": 2.0
	}
	var r_west: int = engine.add_road(n_west, n_center, "residential_2lane", res_params)
	var r_east: int = engine.add_road(n_center, n_east, "residential_2lane", res_params)
	print("✓ Calle Residencial Este-Oeste añadida. Edge IDs: %d, %d" % [r_west, r_east])

	# 4. Resolver red vial y medir tiempo
	var t0 := Time.get_ticks_usec()
	engine.solve()
	var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("✓ Red vial resuelta en %.3f ms" % elapsed_ms)

	# 5. Obtener los MultiMeshes GPU y estadísticas
	var mm_asphalt: MultiMesh = engine.get_asphalt_multimesh()
	var mm_sidewalk: MultiMesh = engine.get_sidewalk_multimesh()
	var mm_curb: MultiMesh = engine.get_curb_multimesh()
	var mm_median: MultiMesh = engine.get_median_multimesh()
	var mm_junction: MultiMesh = engine.get_junction_multimesh()
	var mm_paint: MultiMesh = engine.get_paint_multimesh()
	var tree_sockets: Array = engine.get_tree_socket_transforms()
	var total_boxes: int = engine.get_total_box_count()

	var asphalt_count := mm_asphalt.instance_count if mm_asphalt else 0
	var sidewalk_count := mm_sidewalk.instance_count if mm_sidewalk else 0
	var curb_count := mm_curb.instance_count if mm_curb else 0
	var median_count := mm_median.instance_count if mm_median else 0
	var junction_count := mm_junction.instance_count if mm_junction else 0
	var paint_count := mm_paint.instance_count if mm_paint else 0
	var tree_count := tree_sockets.size()

	print("\n--- RESULTADOS DE INSTANCING GPU (CUBOS) ---")
	print("  Asfalto vehicular:     %d cajas (Draw Calls: 1)" % asphalt_count)
	print("  Banquetas peatonales:  %d cajas (Draw Calls: 1)" % sidewalk_count)
	print("  Bordillos / Guarnicion:%d cajas (Draw Calls: 1)" % curb_count)
	print("  Camellon central:      %d cajas (Draw Calls: 1)" % median_count)
	print("  Cruces / Interseccion: %d cajas (Draw Calls: 1)" % junction_count)
	print("  Pintura vial (rayas):  %d cajas (Draw Calls: 1)" % paint_count)
	print("  TOTAL CUBOS GPU:       %d cajas" % total_boxes)
	print("  SOCKETS DE ÁRBOLES:    %d posiciones calculadas" % tree_count)

	if tree_count > 0:
		print("\n  Ejemplo de socket de arbol 0: ", tree_sockets[0].origin)

	# Verificaciones de sanidad
	assert(asphalt_count > 0, "Debe haber instancias de asfalto")
	assert(sidewalk_count > 0, "Debe haber banquetas")
	assert(curb_count > 0, "Debe haber bordillos de proteccion")
	assert(junction_count >= 1, "Debe haber al menos 1 caja de interseccion")
	assert(median_count >= 2, "Debe haber camellones para los 2 tramos de bulevar")
	assert(paint_count > 0, "Debe haber rayas de pintura vial instanciadas")
	assert(tree_count >= 4, "Debe haber sockets para plantar arboles")

	print("\n✓ ¡TODAS LAS ASERCIONES DEL MOTOR PASARON CON ÉXITO!")
	engine.free()
	quit(0)
