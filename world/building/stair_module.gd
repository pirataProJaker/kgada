@tool
extends Node3D
class_name StairModule

## Módulo de Escalera Normalizada para Play Sector X.
## Diseñada para encajar en la cuadrícula de 1m x 1m y conectar pisos (2.80m / 3.40m).
## Incorpora peldaños estilizados PSX, descansos ergonómicos y rampa de colisión inclinada continua
## para garantizar subida y bajada perfectamente suave con CharacterBody3D.
## Soporta Escaleras Rectas, en "U" y en "L" (ideal para esquinas y cero bloqueos de pared).

enum StairType {
	STRAIGHT = 0,   ## Tramo recto adosado a muro (1m ancho x 3m o 4m largo)
	U_SHAPE = 1,    ## Doble tramo en "U" con descanso a media altura (huella de 2m x 2m o 2x3m)
	L_SHAPE = 2     ## Escalera en "L" en esquina de 2 muros (huella de 2m x 2m)
}

enum MaterialStyle {
	WOOD = 0,       ## Madera entarimada de piso
	CONCRETE = 1,   ## Concreto gris pulido
	DARK_OAK = 2    ## Roble oscuro colonial
}

@export var stair_type: StairType = StairType.STRAIGHT:
	set(val):
		stair_type = val
		_rebuild()

@export var orientation: int = 0:
	set(val):
		orientation = val
		_rebuild()

@export var stair_width: float = 0.90:
	set(val):
		stair_width = maxf(0.75, val)
		_rebuild()

@export var target_height: float = 2.80:
	set(val):
		target_height = maxf(1.5, val)
		_rebuild()

@export var straight_length: float = 3.0:
	set(val):
		straight_length = maxf(2.0, val)
		_rebuild()

@export var material_style: MaterialStyle = MaterialStyle.WOOD:
	set(val):
		material_style = val
		_rebuild()

@export var railing_left: bool = false:
	set(val):
		railing_left = val
		_rebuild()

@export var railing_right: bool = true:
	set(val):
		railing_right = val
		_rebuild()

@export var add_upper_guardrails: bool = true:
	set(val):
		add_upper_guardrails = val
		_rebuild()

var _steps_node: Node3D
var _static_body: StaticBody3D
var _railings_node: Node3D


func _ready() -> void:
	_rebuild()


## Reconstruye toda la geometría visual y física de la escalera
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	_steps_node = Node3D.new()
	_steps_node.name = "StepsVisual"
	add_child(_steps_node)

	_static_body = StaticBody3D.new()
	_static_body.name = "StairCollider"
	add_child(_static_body)

	_railings_node = Node3D.new()
	_railings_node.name = "Railings"
	add_child(_railings_node)

	match stair_type:
		StairType.STRAIGHT:
			_build_straight_stair()
		StairType.U_SHAPE:
			_build_u_shape_stair()
		StairType.L_SHAPE:
			_build_l_shape_stair()


# =============================================================================
# --- 1. ESCALERA RECTA (1 TRAMO) ---------------------------------------------
# =============================================================================

func _build_straight_stair() -> void:
	var total_h := target_height
	var total_l := straight_length
	var w := stair_width

	var num_steps := maxi(6, int(round(total_h / 0.175)))
	var riser_h := total_h / float(num_steps)
	var tread_d := total_l / float(num_steps)
	var mat := _get_tread_material()
	var stringer_mat := _get_railing_material()

	var plank_thickness := 0.045
	var nosing := 0.025

	for i in range(num_steps):
		var step_top_y := float(i + 1) * riser_h
		var z_start := float(i) * tread_d
		var z_center := z_start + tread_d * 0.5 + nosing * 0.5

		# 1. Huella (tablón suspendido con volado ergonómico)
		var tread_mesh := BoxMesh.new()
		tread_mesh.size = Vector3(w, plank_thickness, tread_d + nosing)

		var mi := MeshInstance3D.new()
		mi.mesh = tread_mesh
		mi.material_override = mat
		mi.position = Vector3(0.0, step_top_y - plank_thickness * 0.5, z_center)
		_steps_node.add_child(mi)

		# 2. Contrahuella delgada estilizada (2cm de espesor, NO bloque sólido al suelo)
		var riser_mesh := BoxMesh.new()
		riser_mesh.size = Vector3(w, riser_h - plank_thickness, 0.02)
		var riser_inst := MeshInstance3D.new()
		riser_inst.mesh = riser_mesh
		riser_inst.material_override = mat
		riser_inst.position = Vector3(0.0, step_top_y - riser_h * 0.5, z_start + 0.01)
		_steps_node.add_child(riser_inst)

	# 3. Zancas laterales estructurales a los costados
	var hyp := sqrt(total_l * total_l + total_h * total_h)
	var angle := -atan2(total_h, total_l)
	for side in [-1.0, 1.0]:
		var stringer := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(0.04, 0.16, hyp)
		stringer.mesh = s_box
		stringer.material_override = stringer_mat
		stringer.rotation.x = angle
		stringer.position = Vector3(side * (w * 0.5 - 0.02), total_h * 0.5 - 0.05, total_l * 0.5)
		_steps_node.add_child(stringer)

	# Rampa de colisión inclinada continua
	var col_shape := CollisionShape3D.new()
	col_shape.name = "SlopeCollision"
	var convex := ConvexPolygonShape3D.new()
	var hw := w * 0.5
	var p0 := Vector3(-hw, 0.0, 0.0)
	var p1 := Vector3(hw, 0.0, 0.0)
	var p2 := Vector3(hw, total_h, total_l)
	var p3 := Vector3(-hw, total_h, total_l)
	var p4 := Vector3(-hw, 0.0, total_l)
	var p5 := Vector3(hw, 0.0, total_l)

	convex.points = PackedVector3Array([p0, p1, p2, p3, p0, p3, p4, p0, p1, p2, p5, p1, p3, p2, p5, p4])
	col_shape.shape = convex
	_static_body.add_child(col_shape)

	# Barandales inclinados a lo largo del tiro
	if railing_left:
		_build_straight_railing(-hw + 0.04, total_l, total_h)
	if railing_right:
		_build_straight_railing(hw - 0.04, total_l, total_h)

	# Barandal superior horizontal en planta alta protegiendo el hueco de la escalera
	if add_upper_guardrails:
		var rail_x := (hw - 0.04) if railing_right else (-hw + 0.04)
		var guard_len := maxf(1.0, total_l - 0.85)
		_build_horizontal_guardrail(Vector3(rail_x, total_h, guard_len * 0.5), guard_len, 0.90, false)


func _build_straight_railing(x_pos: float, length: float, height: float) -> void:
	var rail_mat := _get_railing_material()
	var rail_h := 0.90
	var num_posts := maxi(3, int(length / 0.75) + 1)

	for i in range(num_posts):
		var t := float(i) / float(num_posts - 1)
		var post_z := t * length
		var post_y_base := t * height

		var post := MeshInstance3D.new()
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.04, rail_h, 0.04)
		post.mesh = p_mesh
		post.material_override = rail_mat
		post.position = Vector3(x_pos, post_y_base + rail_h * 0.5, post_z)
		_railings_node.add_child(post)

	# Pasamanos inclinado
	var handrail := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	var hyp := sqrt(length * length + height * height)
	h_mesh.size = Vector3(0.06, 0.04, hyp)
	handrail.mesh = h_mesh
	handrail.material_override = _get_handrail_material()

	var angle := -atan2(height, length)
	handrail.rotation.x = angle
	handrail.position = Vector3(x_pos, height * 0.5 + rail_h, length * 0.5)
	_railings_node.add_child(handrail)

	var rail_col := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(0.08, rail_h, hyp)
	rail_col.shape = col_box
	rail_col.rotation.x = angle
	rail_col.position = Vector3(x_pos, height * 0.5 + rail_h * 0.5, length * 0.5)
	_static_body.add_child(rail_col)


# =============================================================================
# --- 2. ESCALERA EN "U" (DOBLE TRAMO CON DESCANSO) ---------------------------
# =============================================================================

func _build_u_shape_stair() -> void:
	var flight_w := 0.95
	var flight_len := 2.0
	var landing_depth := 1.20
	var mid_y := target_height * 0.5
	var mat := _get_tread_material()
	var post_mat := _get_railing_material()

	var steps_per_flight := 8
	var riser_1 := mid_y / float(steps_per_flight)
	var tread_1 := flight_len / float(steps_per_flight)
	var plank_thickness := 0.045
	var nosing := 0.025

	# Tramo 1 (Subida frontal izquierda, hacia +Z en X = -0.5)
	for i in range(steps_per_flight):
		var step_top_y := float(i + 1) * riser_1
		var z_start := float(i) * tread_1
		var z_center := z_start + tread_1 * 0.5 + nosing * 0.5

		var mesh := BoxMesh.new()
		mesh.size = Vector3(flight_w, plank_thickness, tread_1 + nosing)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(-flight_w * 0.5, step_top_y - plank_thickness * 0.5, z_center)
		_steps_node.add_child(mi)

		var riser_m := BoxMesh.new()
		riser_m.size = Vector3(flight_w, riser_1 - plank_thickness, 0.02)
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = riser_m
		r_inst.material_override = mat
		r_inst.position = Vector3(-flight_w * 0.5, step_top_y - riser_1 * 0.5, z_start + 0.01)
		_steps_node.add_child(r_inst)

	_add_slope_collision(Vector3(-flight_w * 0.5, 0.0, 0.0), flight_w, flight_len, mid_y, true)

	# Descanso intermedio (Losa delgada de 10cm sobre 4 postes de esquina, NO cubo sólido de 1.4m)
	var landing_mesh := BoxMesh.new()
	landing_mesh.size = Vector3(flight_w * 2.0, 0.10, landing_depth)
	var landing_inst := MeshInstance3D.new()
	landing_inst.mesh = landing_mesh
	landing_inst.material_override = mat
	landing_inst.position = Vector3(0.0, mid_y - 0.05, flight_len + landing_depth * 0.5)
	_steps_node.add_child(landing_inst)

	var landing_col := CollisionShape3D.new()
	var l_shape := BoxShape3D.new()
	l_shape.size = Vector3(flight_w * 2.0, 0.10, landing_depth)
	landing_col.shape = l_shape
	landing_col.position = Vector3(0.0, mid_y - 0.05, flight_len + landing_depth * 0.5)
	_static_body.add_child(landing_col)

	# 4 columnas metálicas de soporte en las esquinas del descanso
	var post_corners = [
		Vector3(-flight_w + 0.05, 0.0, flight_len + 0.05),
		Vector3(flight_w - 0.05, 0.0, flight_len + 0.05),
		Vector3(-flight_w + 0.05, 0.0, flight_len + landing_depth - 0.05),
		Vector3(flight_w - 0.05, 0.0, flight_len + landing_depth - 0.05)
	]
	for p_pos in post_corners:
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.06, mid_y - 0.10, 0.06)
		var p_inst := MeshInstance3D.new()
		p_inst.mesh = p_mesh
		p_inst.material_override = post_mat
		p_inst.position = Vector3(p_pos.x, (mid_y - 0.10) * 0.5, p_pos.z)
		_steps_node.add_child(p_inst)

	# Tramo 2 (Subida de regreso derecha, hacia -Z en X = +0.5)
	var riser_2 := (target_height - mid_y) / float(steps_per_flight)
	for i in range(steps_per_flight):
		var step_top_y := mid_y + float(i + 1) * riser_2
		var z_start := flight_len - float(i) * tread_1
		var z_center := z_start - tread_1 * 0.5 - nosing * 0.5

		var mesh := BoxMesh.new()
		mesh.size = Vector3(flight_w, plank_thickness, tread_1 + nosing)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(flight_w * 0.5, step_top_y - plank_thickness * 0.5, z_center)
		_steps_node.add_child(mi)

		var riser_m := BoxMesh.new()
		riser_m.size = Vector3(flight_w, riser_2 - plank_thickness, 0.02)
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = riser_m
		r_inst.material_override = mat
		r_inst.position = Vector3(flight_w * 0.5, step_top_y - riser_2 * 0.5, z_start - 0.01)
		_steps_node.add_child(r_inst)

	_add_slope_collision(Vector3(flight_w * 0.5, mid_y, flight_len), flight_w, -flight_len, target_height - mid_y, false)
	_build_center_guardrail(flight_len, landing_depth, mid_y, target_height)


# =============================================================================
# --- 3. ESCALERA EN "L" (ESQUINA CON DESCANSO DE 90 GRADOS) ------------------
# =============================================================================

## Construye la escalera en L con tiros amplios, descanso a media altura y peldaños de proporción ergonómica (17.5cm contrahuella, 25cm huella).
func _build_l_shape_stair() -> void:
	var flight_w := 0.90
	var mid_y := target_height * 0.5
	var mat := _get_tread_material()
	var post_mat := _get_railing_material()
	var steps_per_flight := 8
	var plank_thickness := 0.045
	var nosing := 0.025

	var l_root := Node3D.new()
	l_root.name = "LRoot"
	match orientation:
		0: l_root.rotation.y = 0.0
		1: l_root.rotation.y = -PI * 0.5
		2: l_root.rotation.y = PI * 0.5
		3: l_root.rotation.y = PI
	add_child(l_root)

	# --- 3.1 Descanso Cuadrado en la Esquina (Losa delgada de 10cm en (-0.5, -0.5)) ---
	var land_m := BoxMesh.new()
	land_m.size = Vector3(flight_w, 0.10, flight_w)
	var land_inst := MeshInstance3D.new()
	land_inst.mesh = land_m
	land_inst.material_override = mat
	land_inst.position = Vector3(-0.5, mid_y - 0.05, -0.5)
	l_root.add_child(land_inst)

	var land_col := CollisionShape3D.new()
	var l_box := BoxShape3D.new()
	l_box.size = Vector3(flight_w, 0.10, flight_w)
	land_col.shape = l_box
	land_col.transform = l_root.transform * Transform3D(Basis(), Vector3(-0.5, mid_y - 0.05, -0.5))
	_static_body.add_child(land_col)

	# Postes esquineros bajo el descanso
	var l_posts = [
		Vector3(-0.5 - flight_w * 0.5 + 0.05, 0.0, -0.5 - flight_w * 0.5 + 0.05),
		Vector3(-0.5 + flight_w * 0.5 - 0.05, 0.0, -0.5 - flight_w * 0.5 + 0.05),
		Vector3(-0.5 - flight_w * 0.5 + 0.05, 0.0, -0.5 + flight_w * 0.5 - 0.05),
		Vector3(-0.5 + flight_w * 0.5 - 0.05, 0.0, -0.5 + flight_w * 0.5 - 0.05)
	]
	for lp in l_posts:
		var pm := BoxMesh.new()
		pm.size = Vector3(0.05, mid_y - 0.10, 0.05)
		var p_inst := MeshInstance3D.new()
		p_inst.mesh = pm
		p_inst.material_override = post_mat
		p_inst.position = Vector3(lp.x, (mid_y - 0.10) * 0.5, lp.z)
		l_root.add_child(p_inst)

	# --- 3.2 Tramo 1: Sube hacia el descanso en el Norte ---
	var leg1_len := 2.0
	var riser_1 := mid_y / float(steps_per_flight)
	var tread_1 := leg1_len / float(steps_per_flight)
	var leg1_start_z := -0.5 + flight_w * 0.5 + leg1_len

	for i in range(steps_per_flight):
		var step_top_y := float(i + 1) * riser_1
		var z_pos := leg1_start_z - (float(i) * tread_1 + tread_1 * 0.5)

		var m := BoxMesh.new()
		m.size = Vector3(flight_w, plank_thickness, tread_1 + nosing)
		var inst := MeshInstance3D.new()
		inst.mesh = m
		inst.material_override = mat
		inst.position = Vector3(-0.5, step_top_y - plank_thickness * 0.5, z_pos)
		l_root.add_child(inst)

		var rm := BoxMesh.new()
		rm.size = Vector3(flight_w, riser_1 - plank_thickness, 0.02)
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = rm
		r_inst.material_override = mat
		r_inst.position = Vector3(-0.5, step_top_y - riser_1 * 0.5, leg1_start_z - float(i) * tread_1 - 0.01)
		l_root.add_child(r_inst)

	_add_slope_collision_local(l_root, Vector3(-0.5, 0.0, leg1_start_z), flight_w, -leg1_len, mid_y)

	# --- 3.3 Tramo 2: Gira 90° hacia el Este (+X) rumbo a Planta Alta ---
	var leg2_len := 1.8
	var riser_2 := (target_height - mid_y) / float(steps_per_flight)
	var tread_2 := leg2_len / float(steps_per_flight)
	var leg2_start_x := -0.5 + flight_w * 0.5

	for i in range(steps_per_flight):
		var step_top_y := mid_y + float(i + 1) * riser_2
		var x_pos := leg2_start_x + float(i) * tread_2 + tread_2 * 0.5

		var m := BoxMesh.new()
		m.size = Vector3(tread_2 + nosing, plank_thickness, flight_w)
		var inst := MeshInstance3D.new()
		inst.mesh = m
		inst.material_override = mat
		inst.position = Vector3(x_pos, step_top_y - plank_thickness * 0.5, -0.5)
		l_root.add_child(inst)

		var rm := BoxMesh.new()
		rm.size = Vector3(0.02, riser_2 - plank_thickness, flight_w)
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = rm
		r_inst.material_override = mat
		r_inst.position = Vector3(leg2_start_x + float(i) * tread_2 + 0.01, step_top_y - riser_2 * 0.5, -0.5)
		l_root.add_child(r_inst)

	_add_slope_collision_x_local(l_root, Vector3(leg2_start_x, mid_y, -0.5), leg2_len, flight_w, target_height - mid_y)

	# --- 3.4 Barandal Interior (ojo de la escalera) ---
	var rail_mat := _get_railing_material()
	var inner_post := MeshInstance3D.new()
	var ip_box := BoxMesh.new()
	ip_box.size = Vector3(0.04, target_height + 0.90, 0.04)
	inner_post.mesh = ip_box
	inner_post.material_override = rail_mat
	inner_post.position = Vector3(-0.05, (target_height + 0.90) * 0.5, -0.05)
	l_root.add_child(inner_post)

	# Barandal superior en planta alta a lo largo del hueco de la escalera
	if add_upper_guardrails:
		_build_horizontal_guardrail_local(l_root, Vector3(leg2_start_x + leg2_len * 0.5, target_height, -0.5 + flight_w * 0.5), leg2_len, 0.90, true)
		_build_horizontal_guardrail_local(l_root, Vector3(-0.5 + flight_w * 0.5, target_height, leg1_start_z - leg1_len * 0.5), leg1_len, 0.90, false)


# =============================================================================
# --- 4. AYUDANTES DE FÍSICA Y BARANDALES ---------------------------------------
# =============================================================================

func _add_slope_collision(base_pos: Vector3, width: float, length: float, height: float, positive_z: bool) -> void:
	var col := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var hw := width * 0.5

	var x0 := base_pos.x - hw
	var x1 := base_pos.x + hw
	var y0 := base_pos.y
	var y1 := base_pos.y + height
	var z0 := base_pos.z
	var z1 := base_pos.z + length

	var pts := PackedVector3Array([
		Vector3(x0, y0, z0), Vector3(x1, y0, z0),
		Vector3(x1, y1, z1), Vector3(x0, y1, z1),
		Vector3(x0, y0, z1), Vector3(x1, y0, z1)
	])
	convex.points = pts
	col.shape = convex
	_static_body.add_child(col)


func _add_slope_collision_local(parent: Node3D, base_pos: Vector3, width: float, length: float, height: float) -> void:
	var col := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var hw := width * 0.5

	var x0 := base_pos.x - hw
	var x1 := base_pos.x + hw
	var y0 := base_pos.y
	var y1 := base_pos.y + height
	var z0 := base_pos.z
	var z1 := base_pos.z + length

	convex.points = PackedVector3Array([
		Vector3(x0, y0, z0), Vector3(x1, y0, z0),
		Vector3(x1, y1, z1), Vector3(x0, y1, z1),
		Vector3(x0, y0, z1), Vector3(x1, y0, z1)
	])
	col.shape = convex
	col.transform = parent.transform
	_static_body.add_child(col)


func _add_slope_collision_x_local(parent: Node3D, base_pos: Vector3, length_x: float, width_z: float, height: float) -> void:
	var col := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var hz := width_z * 0.5

	var x0 := base_pos.x
	var x1 := base_pos.x + length_x
	var y0 := base_pos.y
	var y1 := base_pos.y + height
	var z0 := base_pos.z - hz
	var z1 := base_pos.z + hz

	convex.points = PackedVector3Array([
		Vector3(x0, y0, z0), Vector3(x0, y0, z1),
		Vector3(x1, y1, z0), Vector3(x1, y1, z1),
		Vector3(x1, y0, z0), Vector3(x1, y0, z1)
	])
	col.shape = convex
	col.transform = parent.transform
	_static_body.add_child(col)


func _build_horizontal_guardrail(pos: Vector3, length: float, height: float, along_x: bool) -> void:
	var rail_mat := _get_railing_material()
	var hand_mat := _get_handrail_material()

	var guard := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	if along_x:
		g_box.size = Vector3(length, height, 0.04)
	else:
		g_box.size = Vector3(0.04, height, length)
	guard.mesh = g_box
	guard.material_override = rail_mat
	guard.position = pos + Vector3(0.0, height * 0.5, 0.0)
	_railings_node.add_child(guard)

	# Pasamanos superior
	var hand := MeshInstance3D.new()
	var h_box := BoxMesh.new()
	if along_x:
		h_box.size = Vector3(length, 0.04, 0.06)
	else:
		h_box.size = Vector3(0.06, 0.04, length)
	hand.mesh = h_box
	hand.material_override = hand_mat
	hand.position = pos + Vector3(0.0, height + 0.02, 0.0)
	_railings_node.add_child(hand)

	# Colisión de seguridad
	var col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = g_box.size
	col.shape = b_shape
	col.position = pos + Vector3(0.0, height * 0.5, 0.0)
	_static_body.add_child(col)


func _build_horizontal_guardrail_local(parent: Node3D, pos: Vector3, length: float, height: float, along_x: bool) -> void:
	var rail_mat := _get_railing_material()
	var hand_mat := _get_handrail_material()

	var guard := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	if along_x:
		g_box.size = Vector3(length, height, 0.04)
	else:
		g_box.size = Vector3(0.04, height, length)
	guard.mesh = g_box
	guard.material_override = rail_mat
	guard.position = pos + Vector3(0.0, height * 0.5, 0.0)
	parent.add_child(guard)

	var col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = g_box.size
	col.shape = b_shape
	col.transform = parent.transform * Transform3D(Basis(), pos + Vector3(0.0, height * 0.5, 0.0))
	_static_body.add_child(col)


func _build_center_guardrail(flight_len: float, landing_depth: float, mid_y: float, top_y: float) -> void:
	var rail_mat := _get_railing_material()
	var rail_h := 0.90
	var div_len := maxf(0.5, flight_len - 0.25)

	var divider := MeshInstance3D.new()
	var d_mesh := BoxMesh.new()
	d_mesh.size = Vector3(0.04, top_y + rail_h, div_len)
	divider.mesh = d_mesh
	divider.material_override = rail_mat
	divider.position = Vector3(0.0, (top_y + rail_h) * 0.5, div_len * 0.5)
	_railings_node.add_child(divider)

	var div_col := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(0.04, top_y + rail_h, div_len)
	div_col.shape = c_box
	div_col.position = Vector3(0.0, (top_y + rail_h) * 0.5, div_len * 0.5)
	_static_body.add_child(div_col)

	var back_rail := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(2.0, rail_h, 0.05)
	back_rail.mesh = b_mesh
	back_rail.material_override = rail_mat
	back_rail.position = Vector3(0.0, mid_y + rail_h * 0.5, flight_len + landing_depth - 0.03)
	_railings_node.add_child(back_rail)

	var back_col := CollisionShape3D.new()
	var bc_box := BoxShape3D.new()
	bc_box.size = Vector3(2.0, rail_h, 0.05)
	back_col.shape = bc_box
	back_col.position = Vector3(0.0, mid_y + rail_h * 0.5, flight_len + landing_depth - 0.03)
	_static_body.add_child(back_col)


# =============================================================================
# --- 5. MATERIALES PSX ESTILIZADOS -------------------------------------------
# =============================================================================

func _get_tread_material() -> Material:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.82

	match material_style:
		MaterialStyle.WOOD:
			var tex: Texture2D = load("res://assets/building/wood_floor.png")
			if tex:
				mat.albedo_texture = tex
				mat.uv1_scale = Vector3(1.5, 1.5, 1.5)
			else:
				mat.albedo_color = Color(0.68, 0.48, 0.32)
		MaterialStyle.CONCRETE:
			mat.albedo_color = Color(0.62, 0.63, 0.60)
			mat.roughness = 0.95
		MaterialStyle.DARK_OAK:
			var tex: Texture2D = load("res://assets/building/wood_floor.png")
			if tex:
				mat.albedo_texture = tex
				mat.albedo_color = Color(0.42, 0.28, 0.18)
				mat.uv1_scale = Vector3(1.2, 1.2, 1.2)
			else:
				mat.albedo_color = Color(0.40, 0.26, 0.16)

	return mat


func _get_railing_material() -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.20) # Herrería negra mate
	mat.metallic = 0.40
	mat.roughness = 0.65
	return mat


func _get_handrail_material() -> Material:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = load("res://assets/building/wood_floor.png")
	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.55, 0.38, 0.24)
	else:
		mat.albedo_color = Color(0.52, 0.34, 0.20)
	mat.roughness = 0.70
	return mat
