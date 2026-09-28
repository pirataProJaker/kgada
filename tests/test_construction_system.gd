extends SceneTree

const ConstructionVisualMarker = preload("res://world/building/construction_visual_marker.gd")
const BuildingManagerScript = preload("res://autoload/building_manager.gd")

func _init() -> void:
	print("=================================================================")
	print("🧪 INICIANDO TEST DEL SISTEMA DE CONSTRUCCIÓN VECTORIAL MODULAR")
	print("=================================================================")

	var passed := 0
	var total := 0

	# 1. Test Data-Driven Tools & Recipes
	total += 1
	var bm = BuildingManagerScript.new()
	bm._ready()
	if bm and not bm.tools_data.is_empty() and not bm.recipes_data.is_empty():
		print("✅ [1/7] Configuración Data-Driven cargada exitosamente: %d herramientas, %d recetas." % [bm.tools_data.size(), bm.recipes_data.size()])
		passed += 1
	else:
		push_error("❌ [1/7] Fallo al cargar configuración en BuildingManager.")

	# 2. Test Material Savings
	total += 1
	var stick_cost = bm.calculate_discounted_cost({"wood": 20}, 0.0)
	var book_cost = bm.calculate_discounted_cost({"wood": 20}, 0.08)
	var blueprint_cost = bm.calculate_discounted_cost({"wood": 20}, 0.15)

	if stick_cost["wood"] == 20 and book_cost["wood"] == 19 and blueprint_cost["wood"] == 17:
		print("✅ [2/7] Ahorro de materiales correcto: Palo: %d, Cuaderno (8%%): %d, Cal (15%%): %d." % [stick_cost["wood"], book_cost["wood"], blueprint_cost["wood"]])
		passed += 1
	else:
		push_error("❌ [2/7] Cálculo de ahorro de materiales incorrecto: " + str([stick_cost, book_cost, blueprint_cost]))

	# 3. Test Book Unlock System
	total += 1
	var brick_recipe = {}
	for r in bm.recipes_data:
		if r["id"] == "wall_brick":
			brick_recipe = r
			break

	var initially_locked = not bm.is_recipe_unlocked(brick_recipe)
	bm.unlock_book("book_architecture_brickwork")
	var unlocked_after_reading = bm.is_recipe_unlocked(brick_recipe)

	if initially_locked and unlocked_after_reading:
		print("✅ [3/7] Sistema de desbloqueo de recetas por libros funcionando al 100%.")
		passed += 1
	else:
		push_error("❌ [3/7] Falló el desbloqueo por libro de recetas.")

	# 4. Test ConstructionEngine (Rust GDExtension) Instance
	total += 1
	if not ClassDB.class_exists("ConstructionEngine"):
		push_error("❌ [4/7] Clase 'ConstructionEngine' no encontrada en GDExtension.")
	else:
		var engine = ClassDB.instantiate("ConstructionEngine")
		if engine:
			print("✅ [4/7] ConstructionEngine (Rust) instanciado con éxito.")
			passed += 1

			# 5. Test Snapping Vectorial (P0 libre, mínimo 1 metro por lado y seguimiento continuo sin saltos)
			total += 1
			# Origen libre arbitrario (12.35, 5.0, 45.67) y cursor muy cercano (< 1m)
			var free_origin := Vector3(12.35, 5.0, 45.67)
			var near_ray := Vector3(12.40, 5.2, 45.70)
			var snap_min_floor: Vector3 = engine.calc_snap_point(free_origin, near_ray, 0)

			# Debe garantizar mínimo 1.0m en X y 1.0m en Z respecto al origen libre
			var min_dx: float = absf(snap_min_floor.x - free_origin.x)
			var min_dz: float = absf(snap_min_floor.z - free_origin.z)
			var floor_min_ok = is_equal_approx(min_dx, 1.0) and is_equal_approx(min_dz, 1.0) and is_equal_approx(snap_min_floor.y, 5.0)

			# Cursor a distancia continua arbitraria (p.ej. dx = 3.40m, dz = 2.15m) -> NO debe redondear ni saltar a enteros
			var free_ray := Vector3(12.35 + 3.40, 5.0, 45.67 + 2.15)
			var snap_free_floor: Vector3 = engine.calc_snap_point(free_origin, free_ray, 0)
			var free_dx: float = absf(snap_free_floor.x - free_origin.x)
			var free_dz: float = absf(snap_free_floor.z - free_origin.z)
			var floor_free_ok = is_equal_approx(free_dx, 3.40) and is_equal_approx(free_dz, 2.15)

			# Pared: mínimo 1.0m si se apunta bajo, continuo si se apunta a 2.7m
			var snap_wall_min: Vector3 = engine.calc_snap_point(Vector3(0, 0, 0), Vector3(0, 0.4, 0), 1)
			var snap_wall_free: Vector3 = engine.calc_snap_point(Vector3(0, 0, 0), Vector3(0, 2.7, 0), 1)
			var wall_ok = is_equal_approx(snap_wall_min.y, 1.0) and is_equal_approx(snap_wall_free.y, 2.7)

			# Test Anclaje Magnético a Orillas de Piso (Wall Edge Snapping)
			engine.register_floor_span(Vector3(0, 0, 0), Vector3(4, 0, 3))
			var edge_snap: Dictionary = engine.snap_point_to_floor(Vector3(0.15, 0, 1.5), 0.40)
			var edge_ok: bool = edge_snap.get("valid", false) and edge_snap.get("is_on_edge", false) and is_equal_approx(edge_snap["position"].x, 0.0) and is_equal_approx(edge_snap["position"].z, 1.5)

			var corner_snap: Dictionary = engine.snap_point_to_floor(Vector3(0.12, 0, 0.10), 0.40)
			var corner_ok: bool = corner_snap.get("valid", false) and corner_snap.get("is_corner", false) and is_equal_approx(corner_snap["position"].x, 0.0) and is_equal_approx(corner_snap["position"].z, 0.0)

			var interior_snap: Dictionary = engine.snap_point_to_floor(Vector3(2.0, 0, 1.5), 0.40)
			var interior_ok: bool = interior_snap.get("valid", false) and not interior_snap.get("is_on_edge", false) and is_equal_approx(interior_snap["position"].x, 2.0)

			var outside_snap: Dictionary = engine.snap_point_to_floor(Vector3(25.0, 0, 25.0), 0.40)
			var outside_ok: bool = not outside_snap.get("valid", false)

			if floor_min_ok and floor_free_ok and wall_ok and edge_ok and corner_ok and interior_ok and outside_ok:
				print("✅ [5/7] Snapping Vectorial y Anclaje Magnético a Orillas de Piso: Validado al 100% (Orilla=OK, Esquina=OK, Interior=OK, Fuera=Rechazado).")
				passed += 1
			else:
				push_error("❌ [5/7] Falló el snapping vectorial o anclaje a orilla: edge=%s, corner=%s, interior=%s, outside=%s" % [edge_ok, corner_ok, interior_ok, outside_ok])

			# 6. Test Spans, Bloqueo de Materiales y Demolición
			total += 1
			# Piso 3x3 = 9 losas (span de 3m x 3m desde 0 hasta 3) colocadas como Armazón (5: Frame)
			var floor_pts: PackedVector3Array = engine.add_floor_span(Vector3(0, 0, 0), Vector3(3, 0, 3), 5)
			# Pared 3x2 = 6 bloques
			var wall_pts: PackedVector3Array = engine.add_wall_span(Vector3(0, 0, 0), Vector3(3, 0, 0), 2.0, 5)
			var count_after_span: int = engine.get_element_count()

			# Asignar Madera a una pared en (0.5, 0.0, 0.0)
			var mat_wood_ok: int = engine.apply_material_at(Vector3(0.5, 0.0, 0.0), 0) # 0: Wood
			# Intentar meter Piedra (1: Stone) a la misma pared ya bloqueada en Madera
			var mat_stone_reject: int = engine.apply_material_at(Vector3(0.5, 0.0, 0.0), 1) # 1: Stone -> Debe retornar -1!

			# Reemplazar por vano de puerta
			var door_ok: bool = engine.add_opening(Vector3(1, 0, 0), 3)

			# Demoler un bloque
			var demo_ok: bool = engine.remove_element_at(Vector3(0, 0, 0))
			var final_count: int = engine.get_element_count()

			if floor_pts.size() == 9 and wall_pts.size() == 6 and mat_wood_ok == 1 and mat_stone_reject == -1 and door_ok and demo_ok and final_count == (count_after_span - 1):
				print("✅ [6/7] GPU MultiMesh y Bloqueo de Materiales: Asignar madera=OK, Rechazar piedra en madera=-1, Puerta=OK, Demolición=OK.")
				passed += 1
			else:
				push_error("❌ [6/7] Error en tramos o bloqueo de materiales: mat_wood=%d, mat_stone_reject=%d, counts=[floor:%d, wall:%d, total:%d]" % [mat_wood_ok, mat_stone_reject, floor_pts.size(), wall_pts.size(), final_count])

			engine.free()

	# 7. Test Visual Markers
	total += 1
	var marker := ConstructionVisualMarker.new()
	var test_pts: Array[Vector3] = [Vector3(0, 0, 0), Vector3(3, 0, 0)]
	marker.setup("dirt_scrape", test_pts)
	var dirt_nodes = marker.marker_nodes.size()

	marker.setup("stake_rope", test_pts)
	var stake_nodes = marker.marker_nodes.size()

	marker.setup("cal_line", test_pts)
	var cal_nodes = marker.marker_nodes.size()

	marker.free()

	if dirt_nodes > 0 and stake_nodes > 0 and cal_nodes > 0:
		print("✅ [7/7] Marcadores visuales (Tierra raspada: %d, Estacas/Cuerda: %d, Línea Cal: %d) verificados." % [dirt_nodes, stake_nodes, cal_nodes])
		passed += 1
	else:
		push_error("❌ [7/7] Falló la creación de marcadores visuales.")

	print("=================================================================")
	print("📊 RESULTADO FINAL: %d / %d TESTS COMPLETADOS EXITOSAMENTE." % [passed, total])
	print("=================================================================")

	quit(0 if passed == total else 1)
