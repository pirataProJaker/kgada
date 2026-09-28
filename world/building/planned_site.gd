extends Node3D
class_name PlannedSite
## Representa un cimiento o trazado de obra en el terreno (p.ej. con un palo rascando la tierra,
## estacas con cuerda, o líneas de polvo de cal).
## Mantiene visible el trazado de la orilla en el mundo sin colocar el piso sólido,
## esperando a que el jugador aplique materiales (madera, piedra) para edificarlo.

const ConstructionVisualMarkerScript = preload("res://world/building/construction_visual_marker.gd")

var element_type: int = 0 # 0: Floor, 1: Wall, 2: Ceiling
var p0: Vector3
var p1: Vector3
var height: float = 2.5
var tool_info: Dictionary = {}
var marker_type: String = "dirt_scrape"
var discount_percent: float = 0.0

var marker: Node3D
var collision_body: StaticBody3D
var label: Label3D

func _ready() -> void:
	add_to_group("planned_sites")

func setup(p_elem_type: int, p_p0: Vector3, p_p1: Vector3, p_tool_info: Dictionary, p_height: float = 2.5) -> void:
	add_to_group("planned_sites")
	element_type = p_elem_type
	p0 = p_p0
	p1 = p_p1
	height = p_height
	tool_info = p_tool_info
	marker_type = tool_info.get("marker_type", "dirt_scrape")
	discount_percent = float(tool_info.get("discount_percent", 0.0))

	# 1. Crear marcador visual del trazado (orilla rascada en tierra, estacas o cal)
	marker = ConstructionVisualMarkerScript.new()
	add_child(marker)

	var pts: Array[Vector3] = []
	if element_type == 0 or element_type == 2:
		# Piso o Techo: Rectángulo perimetral cerrado (4 orillas rascadas)
		var min_x := minf(p0.x, p1.x)
		var max_x := maxf(p0.x, p1.x)
		var min_z := minf(p0.z, p1.z)
		var max_z := maxf(p0.z, p1.z)
		var y := p0.y

		var c0 := Vector3(min_x, y, min_z)
		var c1 := Vector3(max_x, y, min_z)
		var c2 := Vector3(max_x, y, max_z)
		var c3 := Vector3(min_x, y, max_z)
		pts = [c0, c1, c2, c3, c0]
	else:
		# Pared: Marco perimetral vertical en 3D ("debe verse con una linea toda su orilla y ya")
		var b0 := p0 + Vector3(0.0, 0.02, 0.0)
		var b1 := p1 + Vector3(0.0, 0.02, 0.0)
		var t1 := b1 + Vector3(0.0, height, 0.0)
		var t0 := b0 + Vector3(0.0, height, 0.0)
		pts = [b0, b1, t1, t0, b0]

	marker.setup(marker_type, pts)

	# 2. Colisión estática para detectar clics de interacción con materiales
	collision_body = StaticBody3D.new()
	collision_body.set_collision_layer_value(1, true)
	collision_body.set_meta("planned_site", self)

	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()

	if element_type == 0 or element_type == 2:
		var w := maxf(absf(p1.x - p0.x), 1.0)
		var d := maxf(absf(p1.z - p0.z), 1.0)
		box.size = Vector3(w, 0.20, d)
		col_shape.position = Vector3((p0.x + p1.x) * 0.5, p0.y + 0.10, (p0.z + p1.z) * 0.5)
	else:
		var dist := maxf(Vector2(p1.x - p0.x, p1.z - p0.z).length(), 1.0)
		box.size = Vector3(dist, height, 0.50)
		var angle_rad := atan2(p1.z - p0.z, p1.x - p0.x)
		col_shape.position = Vector3((p0.x + p1.x) * 0.5, p0.y + height * 0.5, (p0.z + p1.z) * 0.5)
		col_shape.rotation = Vector3(0, -angle_rad, 0)

	col_shape.shape = box
	collision_body.add_child(col_shape)
	add_child(collision_body)

	# 3. Etiqueta informativa 3D flotante
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 20
	label.outline_size = 6
	label.outline_modulate = Color(0.1, 0.1, 0.1, 0.95)
	label.modulate = Color(1.0, 0.92, 0.45)
	add_child(label)
	_update_label_text()

var openings: Array[Dictionary] = []
var next_opening_id: int = 1
var opening_visual_nodes: Array[Node3D] = []

## Comprueba si un vano propuesto se superpone con alguno ya existente en esta pared
func can_add_opening(t_min: float, t_max: float, y_bottom: float, y_top: float, exclude_id: int = -1) -> bool:
	for op in openings:
		if exclude_id != -1 and op.get("id", -1) == exclude_id:
			continue
		var op_t_min: float = op.get("t_min", 0.0)
		var op_t_max: float = op.get("t_max", 1.0)
		var op_y_bot: float = op.get("y_bottom", 0.0)
		var op_y_top: float = op.get("y_top", 2.1)

		var overlap_t := minf(t_max, op_t_max) - maxf(t_min, op_t_min)
		var overlap_y := minf(y_top, op_y_top) - maxf(y_bottom, op_y_bot)
		if overlap_t > 0.08 and overlap_y > 0.08:
			return false # Superposición real detectada
	return true

## Añade un vano de puerta anclado estrictamente al piso
func add_door_opening(t_center: float, door_w: float = 1.30, door_h: float = 2.1) -> Dictionary:
	var wall_len := (p1 - p0).length()
	var half_w := door_w * 0.5
	var t_min := clampf(t_center - half_w, 0.0, maxf(0.0, wall_len - door_w))
	var t_max := minf(t_min + door_w, wall_len)
	var eff_door_h := minf(door_h, height)

	if not can_add_opening(t_min, t_max, 0.0, eff_door_h):
		print("[PlannedSite] ❌ No se puede colocar puerta: se superpone con un vano existente.")
		return {}

	var op := {
		"id": next_opening_id,
		"type": 3, # Puerta
		"t_min": t_min,
		"t_max": t_max,
		"y_bottom": 0.0, # Anclado estrictamente al piso
		"y_top": eff_door_h,
		"width": t_max - t_min,
		"height": eff_door_h
	}
	next_opening_id += 1
	openings.append(op)
	_rebuild_openings_visuals()
	return op

## Añade un vano de ventana de tamaño flexible
func add_window_opening(t_start: float, t_end: float, y_start: float, y_end: float) -> Dictionary:
	var wall_len := (p1 - p0).length()
	var t_min := clampf(minf(t_start, t_end), 0.0, wall_len)
	var t_max := clampf(maxf(t_start, t_end), 0.0, wall_len)
	if (t_max - t_min) < 0.3:
		t_max = minf(t_min + 0.3, wall_len)
		t_min = maxf(0.0, t_max - 0.3)

	var y_min := clampf(minf(y_start, y_end), 0.05, height - 0.15)
	var y_max := clampf(maxf(y_start, y_end), y_min + 0.2, height)

	if not can_add_opening(t_min, t_max, y_min, y_max):
		print("[PlannedSite] ❌ No se puede colocar ventana: se superpone con un vano existente.")
		return {}

	var op := {
		"id": next_opening_id,
		"type": 4, # Ventana
		"t_min": t_min,
		"t_max": t_max,
		"y_bottom": y_min,
		"y_top": y_max,
		"width": t_max - t_min,
		"height": y_max - y_min
	}
	next_opening_id += 1
	openings.append(op)
	_rebuild_openings_visuals()
	return op

## Busca si una coordenada 3D cae dentro de algún vano de esta pared
func find_opening_at(world_pos: Vector3, filter_type: int = -1) -> Dictionary:
	var wall_dir := p1 - p0
	var wall_len := wall_dir.length()
	if wall_len < 0.001:
		return {}
	var u := wall_dir / wall_len
	var t := (world_pos - p0).dot(u)
	var y_rel := world_pos.y - p0.y

	for op in openings:
		if filter_type != -1 and op.get("type", -1) != filter_type:
			continue
		# Margen de 0.2m para facilitar selección/clic
		if t >= (op.get("t_min", 0.0) - 0.2) and t <= (op.get("t_max", 0.0) + 0.2):
			if y_rel >= (op.get("y_bottom", 0.0) - 0.2) and y_rel <= (op.get("y_top", 0.0) + 0.2):
				return op
	return {}

## Elimina un vano planificado por su ID
func remove_opening(op_id: int) -> bool:
	for i in range(openings.size()):
		if openings[i].get("id", -1) == op_id:
			openings.remove_at(i)
			_rebuild_openings_visuals()
			return true
	return false

## Reconstruye el marco de líneas perimetrales 3D de cada vano planificado
func _rebuild_openings_visuals() -> void:
	for node in opening_visual_nodes:
		if is_instance_valid(node):
			node.queue_free()
	opening_visual_nodes.clear()

	var wall_dir := p1 - p0
	var wall_len := wall_dir.length()
	if wall_len < 0.001:
		return
	var u := wall_dir / wall_len

	for op in openings:
		var t_min: float = op.get("t_min", 0.0)
		var t_max: float = op.get("t_max", 1.0)
		var y_min: float = op.get("y_bottom", 0.0)
		var y_max: float = op.get("y_top", 2.1)
		var op_type: int = op.get("type", 3)

		var c0 := p0 + u * t_min + Vector3(0.0, y_min + 0.02, 0.0)
		var c1 := p0 + u * t_max + Vector3(0.0, y_min + 0.02, 0.0)
		var c2 := p0 + u * t_max + Vector3(0.0, y_max, 0.0)
		var c3 := p0 + u * t_min + Vector3(0.0, y_max, 0.0)
		var loop: Array[Vector3] = [c0, c1, c2, c3, c0]

		var op_marker = ConstructionVisualMarkerScript.new()
		add_child(op_marker)
		opening_visual_nodes.append(op_marker)

		var m_type := "cal_line" if op_type == 4 else "stake_rope"
		op_marker.setup(m_type, loop)

		# Etiqueta informativa sobre el vano
		var op_lbl := Label3D.new()
		op_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		op_lbl.no_depth_test = true
		op_lbl.font_size = 15
		op_lbl.outline_size = 4
		op_lbl.outline_modulate = Color(0.1, 0.1, 0.1, 0.95)
		if op_type == 3:
			op_lbl.text = "🚪 Puerta (%.1fm)" % (t_max - t_min)
			op_lbl.modulate = Color(0.35, 1.0, 0.90)
		else:
			op_lbl.text = "🪟 Ventana (%.1fm × %.1fm)" % [t_max - t_min, y_max - y_min]
			op_lbl.modulate = Color(0.55, 0.88, 1.0)
		op_lbl.position = (c0 + c2) * 0.5
		add_child(op_lbl)
		opening_visual_nodes.append(op_lbl)

	_update_label_text()

func _update_label_text() -> void:
	if label == null:
		return
	var discount_str := " (Ahorro: %d%%)" % int(discount_percent * 100) if discount_percent > 0.0 else ""
	if element_type == 1:
		var len_wall := Vector2(p1.x - p0.x, p1.z - p0.z).length()
		var count_doors := 0
		var count_windows := 0
		for op in openings:
			if op.get("type", 0) == 3: count_doors += 1
			elif op.get("type", 0) == 4: count_windows += 1

		var details := ""
		if count_doors > 0 or count_windows > 0:
			var parts: Array[String] = []
			if count_doors > 0: parts.append("%d Puerta%s" % [count_doors, "s" if count_doors > 1 else ""])
			if count_windows > 0: parts.append("%d Ventana%s" % [count_windows, "s" if count_windows > 1 else ""])
			details = " [" + ", ".join(parts) + "]"

		label.text = "⛏️ Trazado de Pared: %.1fm largo × %.1fm alto%s%s\n[Clic con Madera o Piedra para construir]" % [len_wall, height, details, discount_str]
		label.position = Vector3((p0.x + p1.x) * 0.5, p0.y + height * 0.5 + 0.35, (p0.z + p1.z) * 0.5)
	else:
		var type_name := "Piso" if element_type == 0 else "Techo"
		var w_dim := absf(p1.x - p0.x)
		var d_dim := absf(p1.z - p0.z)
		label.text = "⛏️ Trazado de %s: %.1fm × %.1fm%s\n[Clic con Madera o Piedra para construir]" % [type_name, w_dim, d_dim, discount_str]
		label.position = Vector3((p0.x + p1.x) * 0.5, p0.y + 0.45, (p0.z + p1.z) * 0.5)

## Edifica la estructura con el material recibido (0: Wood, 1: Stone, etc.)
func build_with_material(mat_type: int, player_inventory: Inventory, engine: Node3D) -> bool:
	if engine == null:
		return false

	# Generar la estructura física permanente en ConstructionEngine (GPU Instanced)
	match element_type:
		0, 2:
			if engine.has_method("add_floor_span"):
				engine.call("add_floor_span", p0, p1, mat_type)
		1:
			if engine.has_method("add_wall_span_with_openings"):
				engine.call("add_wall_span_with_openings", p0, p1, height, mat_type, openings)
			elif engine.has_method("add_wall_span"):
				engine.call("add_wall_span", p0, p1, height, mat_type)

			# Instanciar la puerta de madera en cada vano de puerta planificado
			var door_scene = load("res://world/building/wooden_door.tscn")
			if door_scene:
				var wall_dir := (p1 - p0)
				var wall_len := Vector2(wall_dir.x, wall_dir.z).length()
				if wall_len > 0.001:
					var u_x := wall_dir.x / wall_len
					var u_z := wall_dir.z / wall_len
					var angle_rad := atan2(wall_dir.z, wall_dir.x)
					for op in openings:
						if op.get("type", 0) == 3: # Puerta
							var t_mid: float = (op.get("t_min", 0.0) + op.get("t_max", 1.3)) * 0.5
							var door_pos := Vector3(p0.x + u_x * t_mid, p0.y + op.get("y_bottom", 0.0), p0.z + u_z * t_mid)
							var door_inst: Node3D = door_scene.instantiate()
							door_inst.position = door_pos
							door_inst.rotation = Vector3(0, -angle_rad, 0)
							var parent_node: Node = engine.get_parent() if engine.get_parent() else engine
							parent_node.add_child(door_inst)

	# Consumir 1 unidad de material del inventario si existe
	if player_inventory:
		player_inventory.consume_selected(1)

	queue_free()
	return true

## Cancela el trazado y limpia la tierra
func cancel_site() -> void:
	queue_free()
