@tool
extends SceneTree

func _initialize() -> void:
	var out_file := FileAccess.open("res://scratch/test_rules_output.txt", FileAccess.WRITE)
	var log_msg := func(msg: String) -> void:
		print(msg)
		if out_file:
			out_file.store_line(msg)
			out_file.flush()

	log_msg.call("==================================================")
	log_msg.call("🧪 INICIANDO TEST DE REGLAS DE CONSTRUCCIÓN")
	log_msg.call("==================================================")

	var root_node := Node3D.new()
	root.add_child(root_node)

	var planned_site_script = preload("res://world/building/planned_site.gd")
	var controller_script = preload("res://player/vectorial_construction_controller.gd")

	var controller = controller_script.new()
	root_node.add_child(controller)

	# -----------------------------------------------------------------
	# TEST 1: REGLA DE NO SUPERPOSICIÓN DE PISOS
	# -----------------------------------------------------------------
	log_msg.call("\n--- TEST 1: No poner suelo donde ya hay suelo ---")
	var floor1 = planned_site_script.new()
	floor1.setup(0, Vector3(0, 0, 0), Vector3(4, 0, 4), {"name": "Palo"})
	root_node.add_child(floor1)

	# Probar superposición parcial ([2, 6] x [2, 6])
	var overlaps_partial: bool = controller._check_floor_rect_overlap(Vector3(2, 0, 2), Vector3(6, 0, 6))
	assert(overlaps_partial == true, "FALLO: Debería detectar superposición parcial de piso")
	log_msg.call("✅ Detecta superposición parcial correctamente: %s" % overlaps_partial)

	# Probar superposición total ([1, 3] x [1, 3] dentro de [0, 4] x [0, 4])
	var overlaps_total: bool = controller._check_floor_rect_overlap(Vector3(1, 0, 1), Vector3(3, 0, 3))
	assert(overlaps_total == true, "FALLO: Debería detectar superposición total de piso")
	log_msg.call("✅ Detecta superposición total correctamente: %s" % overlaps_total)

	# Probar piso adyacente contiguo ([4, 8] x [0, 4]) que comparte borde
	var overlaps_adjacent: bool = controller._check_floor_rect_overlap(Vector3(4, 0, 0), Vector3(8, 0, 4))
	assert(overlaps_adjacent == false, "FALLO: El piso adyacente que comparte arista no debería solaparse")
	log_msg.call("✅ Permite piso adyacente contiguo sin solapamiento: overlaps=%s" % overlaps_adjacent)

	# -----------------------------------------------------------------
	# TEST 2: EL FANTASMA NUNCA PENETRA AL INTERIOR Y RODEA EL PISO
	# -----------------------------------------------------------------
	log_msg.call("\n--- TEST 2: Fantasma no penetra y rodea construcciones de piso ---")
	var inside_point := Vector3(2.0, 0.0, 2.0)
	assert(controller._is_point_inside_any_floor(inside_point) == true, "FALLO: (2, 2) debe estar dentro de [0, 4] x [0, 4]")

	var proj_info: Dictionary = controller._project_point_outside_floors(inside_point, 0.40)
	var projected_pos: Vector3 = proj_info.get("position", inside_point)
	var was_inside: bool = proj_info.get("was_inside", false)
	var is_on_edge: bool = proj_info.get("is_on_edge", false)

	log_msg.call("Punto original dentro: %s -> Proyectado fuera: %s" % [inside_point, projected_pos])
	assert(was_inside == true, "FALLO: was_inside debe ser true")
	assert(is_on_edge == true, "FALLO: is_on_edge debe ser true")
	assert(controller._is_point_inside_any_floor(projected_pos) == false, "FALLO: El punto proyectado NUNCA debe estar dentro del piso")
	log_msg.call("✅ Fantasma proyectado al perímetro exterior sin penetrar: %s" % projected_pos)

	# Test de magnetismo al contorno desde afuera
	var near_point := Vector3(2.0, 0.0, 4.25) # 0.25m al sur del borde Z=4
	var snap_info: Dictionary = controller._project_point_outside_floors(near_point, 0.40)
	var snapped_pos: Vector3 = snap_info.get("position", near_point)
	assert(snapped_pos.z == 4.0, "FALLO: El punto cercano debe anclarse a la orilla Z=4")
	log_msg.call("✅ Fantasma rodea/se ancla magnéticamente al contorno exterior: %s" % snapped_pos)

	# -----------------------------------------------------------------
	# TEST 3: REGLA DE NO SUPERPOSICIÓN DE PAREDES
	# -----------------------------------------------------------------
	log_msg.call("\n--- TEST 3: No poner pared donde ya hay pared ---")
	var wall1 = planned_site_script.new()
	wall1.setup(1, Vector3(0, 0, 0), Vector3(4, 0, 0), {"name": "Palo"}, 2.5)
	root_node.add_child(wall1)

	# Pared colineal idéntica ([0, 0] a [4, 0])
	var wall_dup: bool = controller._check_wall_overlap(Vector3(0, 0, 0), Vector3(4, 0, 0))
	assert(wall_dup == true, "FALLO: Debería detectar pared duplicada idéntica")
	log_msg.call("✅ Bloquea pared idéntica superpuesta: %s" % wall_dup)

	# Subtramo de pared colineal ([1, 0] a [3, 0])
	var wall_sub: bool = controller._check_wall_overlap(Vector3(1, 0, 0), Vector3(3, 0, 0))
	assert(wall_sub == true, "FALLO: Debería detectar subtramo de pared colineal")
	log_msg.call("✅ Bloquea subtramo de pared colineal: %s" % wall_sub)

	# Pared perpendicular en esquina ([0, 0] a [0, 0, 4])
	var wall_corner: bool = controller._check_wall_overlap(Vector3(0, 0, 0), Vector3(0, 0, 4))
	assert(wall_corner == false, "FALLO: Esquina perpendicular debe ser permitida")
	log_msg.call("✅ Permite esquina perpendicular: overlap=%s" % wall_corner)

	# Unión en T ([2, 0] a [2, 0, 4])
	var wall_t: bool = controller._check_wall_overlap(Vector3(2, 0, 0), Vector3(2, 0, 4))
	assert(wall_t == false, "FALLO: Cruce en T debe ser permitido")
	log_msg.call("✅ Permite cruce en T: overlap=%s" % wall_t)

	# Continuación de pared colineal ([4, 0] a [8, 0])
	var wall_cont: bool = controller._check_wall_overlap(Vector3(4, 0, 0), Vector3(8, 0, 0))
	assert(wall_cont == false, "FALLO: Continuación de pared debe ser permitida")
	log_msg.call("✅ Permite continuación de pared contigua: overlap=%s" % wall_cont)

	# -----------------------------------------------------------------
	# TEST 4: REGLA DE NO SUPERPOSICIÓN DE VANOS (Puertas y Ventanas)
	# -----------------------------------------------------------------
	log_msg.call("\n--- TEST 4: No poner vanos superpuestos en pared ---")
	# Añadir puerta de 1.30m centrada en t=1.5 (t de 0.85 a 2.15)
	var op_door = wall1.add_door_opening(1.5, 1.30, 2.1)
	assert(not op_door.is_empty(), "FALLO: La primera puerta debe poder colocarse")
	log_msg.call("✅ Puerta 1 colocada exitosamente.")

	# Intentar colocar otra puerta que se solapa (t_center = 1.8)
	var op_overlap_door = wall1.add_door_opening(1.8, 1.30, 2.1)
	assert(op_overlap_door.is_empty(), "FALLO: Puerta superpuesta debe ser rechazada")
	log_msg.call("✅ Puerta superpuesta rechazada correctamente.")

	# Intentar colocar ventana que se solapa (t de 1.0 a 2.0)
	var op_overlap_win = wall1.add_window_opening(1.0, 2.0, 0.5, 1.5)
	assert(op_overlap_win.is_empty(), "FALLO: Ventana superpuesta con puerta debe ser rechazada")
	log_msg.call("✅ Ventana superpuesta con puerta rechazada correctamente.")

	# Colocar ventana en espacio libre (t de 2.5 a 3.8)
	var op_valid_win = wall1.add_window_opening(2.5, 3.8, 0.8, 1.8)
	assert(not op_valid_win.is_empty(), "FALLO: Ventana en espacio libre debe poder colocarse")
	log_msg.call("✅ Ventana en espacio libre colocada exitosamente.")

	# -----------------------------------------------------------------
	# TEST 5: EL PUNTO DE CONSTRUCCIÓN NUNCA ESCALA SOBRE LA ALTURA DE LOSA DEL PISO (SALVO QUE SEA PARED)
	# -----------------------------------------------------------------
	log_msg.call("\n--- TEST 5: El punto de construcción de piso nunca escala sobre la losa ---")
	# Simular raycast que golpea la losa de piso elevada (y = 0.20m)
	var elevated_hit := Vector3(2.0, 0.20, 2.0)
	var floor_proj := controller._project_point_outside_floors(elevated_hit, 0.40)
	var floor_pos: Vector3 = floor_proj.get("position", elevated_hit)
	assert(floor_pos.y == 0.0, "FALLO: El punto de piso NUNCA debe escalar en Y sobre la losa, debe quedar a y=0.0")
	log_msg.call("✅ En modo piso, el punto permanece rígidamente en la base y=0.0 sin escalar sobre la losa (0.20m): %s" % floor_pos)

	# Simular punto exterior con altura de losa
	var elevated_near := Vector3(2.0, 0.20, 4.25)
	var near_proj := controller._project_point_outside_floors(elevated_near, 0.40)
	var near_pos: Vector3 = near_proj.get("position", elevated_near)
	assert(near_pos.y == 0.0, "FALLO: El punto perimetral de piso debe mantener y=0.0")
	log_msg.call("✅ En contorno perimetral exterior, mantiene y=0.0: %s" % near_pos)

	# Verificar que en MODO PARED sí se eleva a la superficie superior del piso (y + 0.20m)
	var wall_snap := controller._snap_point_to_floors(Vector3(2.0, 0.0, 2.0))
	log_msg.call("wall_snap obtenido: %s" % wall_snap)
	var wall_pos: Vector3 = wall_snap.get("position", Vector3.ZERO)
	assert(is_equal_approx(wall_pos.y, 0.20), "FALLO: Las paredes SÍ deben descansar sobre la superficie superior del piso a y=0.20m")
	log_msg.call("✅ En modo pared, SÍ descansa sobre la losa a y=0.20m ('al menos que sea una pared'): %s" % wall_pos)

	# -----------------------------------------------------------------
	# TEST 6: VENTANA SOBRE MARCO DE PUERTA (FLEXIBILIDAD TOTAL SIN TAPAR LA PUERTA)
	# -----------------------------------------------------------------
	log_msg.call("\n--- TEST 6: Ventana sobre marco de puerta y flexibilidad total ---")
	var wall2 = PlannedSite.new()
	wall2.setup(1, Vector3(0, 0, 0), Vector3(6, 0, 0), {"marker_type": "cal_line"}, 3.2)
	root.add_child(wall2)

	# 1. Colocar puerta de 1.30m anclada al piso (y de 0.0 a 2.10) centrada en t=3.0
	var door_op = wall2.add_door_opening(3.0, 1.30, 2.10)
	assert(not door_op.is_empty(), "FALLO: Debe poder colocarse la puerta")
	log_msg.call("✅ Puerta colocada en t=[%.2f, %.2f], y=[0.0, 2.10]" % [door_op["t_min"], door_op["t_max"]])

	# 2. Colocar ventana directamente encima del marco de la puerta (t de 2.35 a 3.65, y de 2.20 a 3.00)
	var win_above = wall2.add_window_opening(door_op["t_min"], door_op["t_max"], 2.20, 3.00)
	assert(not win_above.is_empty(), "FALLO: Debe permitir colocar una ventana sobre el marco de la puerta")
	log_msg.call("✅ Ventana colocada exitosamente sobre la puerta: t=[%.2f, %.2f], y=[2.20, 3.00]" % [win_above["t_min"], win_above["t_max"]])

	# 3. Construir en ConstructionEngine (Rust) con add_wall_span_with_openings
	var engine = controller.construction_engine
	if engine == null:
		engine = ClassDB.instantiate("ConstructionEngine")
		root_node.add_child(engine)

	var placed_elements: PackedVector3Array = engine.call("add_wall_span_with_openings", wall2.p0, wall2.p1, wall2.height, 0, wall2.openings)
	var door_count: int = engine.call("get_element_count_by_type", 3)
	var win_count: int = engine.call("get_element_count_by_type", 4)
	var wall_count: int = engine.call("get_element_count_by_type", 1)
	log_msg.call("Elementos construidos en Rust: Puertas=%d, Ventanas=%d, BloquesMuro=%d" % [door_count, win_count, wall_count])
	assert(door_count >= 1, "FALLO: El marco de la puerta debe existir en el motor (NO debe descartarse)")
	assert(win_count >= 1, "FALLO: El marco de la ventana debe existir en el motor (NO debe descartarse)")
	assert(wall_count >= 2, "FALLO: Los bloques de muro deben bordear los vanos sin tapar la puerta ni la ventana")
	log_msg.call("✅ TEST 6 PASADO: La ventana se colocó sobre el marco de puerta y la puerta NO se tapó!")

	log_msg.call("\n==================================================")
	log_msg.call("🎉 ¡TODOS LOS TESTS DE REGLAS PASARON EXITOSAMENTE (100%)!")
	log_msg.call("==================================================")
	if out_file:
		out_file.close()

	for i in range(2):
		await process_frame
	quit()
