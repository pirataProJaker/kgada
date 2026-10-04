class_name ApplianceDryer
extends Node3D

## Secadora de Ropa Procedural de Carga Frontal (Front-Loading)
## - Copete trasero inclinado (~20°) idéntico y coordinado con la lavadora
## - Textura con filtrado NEAREST para máxima nitidez estilo retro/PSX
## - Encimera superior completamente lisa, plana y cerrada
## - Puerta frontal abatible con recuadro negro
## - Tambor interior cilíndrico horizontal (12 segmentos) con 3 paletas de volteo de ropa
## - Portal circular de carga con marco de goma oscuro y bisel
## - Construida 100% con geometría paramétrica optimizada para GPU Instancing (1 draw call)

const TEXTURE_PATH: String = "res://assets/textures/furniture/dryer.png"

@export_group("Dimensiones")
@export var width: float = 0.68           ## Ancho total (68cm)
@export var depth: float = 0.68           ## Profundidad total (68cm)
@export var height: float = 0.88          ## Altura hasta la encimera plana (88cm)
@export var console_height: float = 0.16  ## Altura del copete trasero (16cm, total 1.04m)
@export var console_depth: float = 0.12   ## Profundidad de la base del copete (12cm)
@export var door_thickness: float = 0.022 ## Grosor de la puerta frontal (2.2cm)

@export_group("Apertura")
@export_range(0.0, 1.0) var door_open_ratio: float = 0.0:
	set(val):
		door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angle()

const MAX_DOOR_ANGLE: float = deg_to_rad(105.0)

var _body_mesh_instance: MeshInstance3D = null
var _door_pivot: Node3D = null
var _door_mesh_instance: MeshInstance3D = null
var _body_collision: StaticBody3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_body_mesh: ArrayMesh = null
static var _cached_door_mesh: ArrayMesh = null
static var _cached_complete_mesh: ArrayMesh = null


## Retorna la malla compartida del cuerpo para GPU Instancing
static func get_shared_body_mesh() -> ArrayMesh:
	if _cached_body_mesh == null:
		var door_w := 0.68 * 0.70
		var door_h := 0.88 * 0.52
		var door_y := 0.88 * 0.43
		_cached_body_mesh = _build_dryer_body_mesh(0.68, 0.68, 0.88, 0.16, 0.12, door_w, door_h, door_y, 0.025)
	return _cached_body_mesh


## Retorna la malla compartida de la puerta frontal
static func get_shared_door_mesh() -> ArrayMesh:
	if _cached_door_mesh == null:
		var door_w := 0.68 * 0.70
		var door_h := 0.88 * 0.52
		_cached_door_mesh = _build_door_mesh(door_w, door_h, 0.025)
	return _cached_door_mesh


## Retorna la malla compartida completa (cuerpo + puerta cerrada) para GPU Instancing en 1 Draw Call
static func get_shared_mesh() -> ArrayMesh:
	if _cached_complete_mesh != null:
		return _cached_complete_mesh

	var body := get_shared_body_mesh()
	var door := get_shared_door_mesh()

	var door_w := 0.68 * 0.70
	var hinge_x := -door_w * 0.5
	var hinge_z := 0.68 * 0.5
	var door_y := 0.88 * 0.43
	var door_xform := Transform3D(Basis.IDENTITY, Vector3(hinge_x, door_y, hinge_z))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(body, 0, Transform3D.IDENTITY)
	st.append_from(door, 0, door_xform)
	st.generate_normals()
	st.generate_tangents()
	_cached_complete_mesh = st.commit()
	return _cached_complete_mesh


## Retorna las cajas de colisión para el sistema MultiMesh
static func get_collision_boxes(w: float = 0.68, d: float = 0.68, h: float = 0.88, c_h: float = 0.16, c_d: float = 0.12) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		},
		{
			"position": Vector3(0.0, h + c_h * 0.5, -d * 0.5 + c_d * 0.5),
			"size": Vector3(w, c_h, c_d)
		}
	]


func _ready() -> void:
	_build_dryer()


func _build_dryer() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()

	# Dimensiones y posición de la puerta frontal de la secadora:
	var door_w := width * 0.70 # 0.476m
	var door_h := height * 0.52 # 0.458m
	var door_y := height * 0.43 # Centrada en la parte media-frontal
	var hinge_x := -door_w * 0.5
	var hinge_z := depth * 0.5 - door_thickness * 0.5

	var is_default_dim := is_equal_approx(width, 0.68) and is_equal_approx(depth, 0.68) and is_equal_approx(height, 0.88) and is_equal_approx(console_height, 0.16) and is_equal_approx(console_depth, 0.12)

	# 1. Carcasa / Cuerpo Principal con Copete Inclinado, Encimera Plana y Tambor Cilíndrico
	var body_mesh: ArrayMesh
	if is_default_dim and is_equal_approx(door_thickness, 0.025):
		body_mesh = get_shared_body_mesh()
	else:
		body_mesh = _build_dryer_body_mesh(width, depth, height, console_height, console_depth, door_w, door_h, door_y, door_thickness)

	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "DryerBodyMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat
	add_child(_body_mesh_instance)

	# 2. Puerta Frontal Abatible (Bisagra a la izquierda)
	_door_pivot = Node3D.new()
	_door_pivot.name = "DryerDoorPivot"
	_door_pivot.position = Vector3(hinge_x, door_y, hinge_z)
	add_child(_door_pivot)

	var door_mesh: ArrayMesh
	if is_default_dim and is_equal_approx(door_thickness, 0.025):
		if not _cached_door_mesh:
			_cached_door_mesh = _build_door_mesh(door_w, door_h, door_thickness)
		door_mesh = _cached_door_mesh
	else:
		door_mesh = _build_door_mesh(door_w, door_h, door_thickness)

	_door_mesh_instance = MeshInstance3D.new()
	_door_mesh_instance.name = "DryerDoorMesh"
	_door_mesh_instance.mesh = door_mesh
	_door_mesh_instance.material_override = mat
	_door_mesh_instance.position = Vector3(0.0, 0.0, 0.0) # Se extiende hacia +X
	_door_pivot.add_child(_door_mesh_instance)

	# 3. Colisiones Físicas Interactivas con tecla [E]
	_setup_collision(width, depth, height, console_height, door_w, door_h, door_y, door_thickness)
	_update_door_angle()


func _update_door_angle() -> void:
	if _door_pivot:
		_door_pivot.rotation.y = -door_open_ratio * MAX_DOOR_ANGLE


## Abre o cierra la puerta de la secadora
func toggle_door(animated: bool = true) -> void:
	var target := 1.0 if door_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "door_open_ratio", target, 0.40)
	else:
		door_open_ratio = target


## Punto de interacción al presionar [E] (ver InteractController)
func interact(_interactor: Node = null) -> void:
	toggle_door()


# =========================================================================
# GENERACIÓN DE GEOMETRÍA (SurfaceTool)
# =========================================================================

static func _build_dryer_body_mesh(w: float, d: float, h: float, c_h: float, c_d: float, dw: float, dh: float, dy: float, dt: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas dryer.png (128x128):
	var uv_white_min := Vector2(0.008, 0.008)
	var uv_white_max := Vector2(0.250, 0.180)

	var uv_ctrl_min := Vector2(0.383, 0.203)
	var uv_ctrl_max := Vector2(0.664, 0.273)

	var uv_steel_min := Vector2(56.0 / 128.0, 30.0 / 128.0)
	var uv_steel_max := Vector2(80.0 / 128.0, 33.0 / 128.0)

	var uv_black_min := Vector2(0.010, 73.5 / 128.0)
	var uv_black_max := Vector2(0.990, 74.5 / 128.0)

	var hw := w * 0.5
	var hd := d * 0.5
	var wall_t := 0.030

	# ---------------------------------------------------------------------
	# 1. Copete Trasero Inclinado (Backsplash / Panel de control inclinado 20°)
	# ---------------------------------------------------------------------
	var z_back := -hd
	var z_bot_front := -hd + c_d
	var z_top_front := z_bot_front - 0.055
	_add_slanted_console_st(st, w, h, c_h, z_back, z_bot_front, z_top_front, uv_ctrl_min, uv_ctrl_max, uv_white_min, uv_white_max)

	# ---------------------------------------------------------------------
	# 2. Encimera Superior Plana (Top Deck completamente cerrado y liso)
	# ---------------------------------------------------------------------
	var deck_z_start := z_bot_front
	var deck_l := hd - deck_z_start
	var deck_c := Vector3(0.0, h - wall_t * 0.5, deck_z_start + deck_l * 0.5)
	_add_simple_box_st(st, deck_c, Vector3(w, wall_t, deck_l), uv_white_min, uv_white_max)

	# ---------------------------------------------------------------------
	# 3. Base, Trasera y Laterales
	# ---------------------------------------------------------------------
	# Base inferior (-Y)
	_add_simple_box_st(st, Vector3(0.0, wall_t * 0.5, 0.0), Vector3(w, wall_t, d), uv_white_min, uv_white_max)

	# Pared Trasera (-Z)
	_add_simple_box_st(st, Vector3(0.0, h * 0.5, -hd + wall_t * 0.5), Vector3(w, h - wall_t * 2.0, wall_t), uv_white_min, uv_white_max)

	# Pared Lateral Izquierda (-X)
	_add_simple_box_st(st, Vector3(-hw + wall_t * 0.5, h * 0.5, wall_t * 0.5), Vector3(wall_t, h - wall_t * 2.0, d - wall_t), uv_white_min, uv_white_max)

	# Pared Lateral Derecha (+X)
	_add_simple_box_st(st, Vector3( hw - wall_t * 0.5, h * 0.5, wall_t * 0.5), Vector3(wall_t, h - wall_t * 2.0, d - wall_t), uv_white_min, uv_white_max)

	# ---------------------------------------------------------------------
	# 4. Frontal (+Z) alrededor del hueco de la puerta
	# ---------------------------------------------------------------------
	var front_z := hd - dt * 0.5

	# Franja superior sobre la puerta con costura negra fina en el borde superior
	var top_band_h := (h - wall_t) - (dy + dh * 0.5)
	if top_band_h > 0.005:
		var seam_h := minf(top_band_h, 0.014)
		var white_h := top_band_h - seam_h

		# Costura negra superior fina (Y=74)
		var seam_c := Vector3(0.0, (h - wall_t) - seam_h * 0.5, front_z)
		_add_box_front_custom_st(st, seam_c, Vector3(w, seam_h, dt), uv_black_min, uv_black_max, uv_white_min, uv_white_max)

		# Panel blanco limpio sobre la puerta
		if white_h > 0.005:
			var wh_c := Vector3(0.0, (dy + dh * 0.5) + white_h * 0.5, front_z)
			_add_simple_box_st(st, wh_c, Vector3(w, white_h, dt), uv_white_min, uv_white_max)

	# Faldón inferior bajo la puerta
	var skirt_h := (dy - dh * 0.5) - wall_t
	if skirt_h > 0.005:
		var sk_c := Vector3(0.0, wall_t + skirt_h * 0.5, front_z)
		_add_simple_box_st(st, sk_c, Vector3(w, skirt_h, dt), uv_white_min, uv_white_max)

	# Mochetas laterales izquierda y derecha
	var mocheta_w := (w - dw) * 0.5
	if mocheta_w > 0.005:
		var moch_l_c := Vector3(-hw + mocheta_w * 0.5, dy, front_z)
		var moch_r_c := Vector3( hw - mocheta_w * 0.5, dy, front_z)
		_add_simple_box_st(st, moch_l_c, Vector3(mocheta_w, dh, dt), uv_white_min, uv_white_max)
		_add_simple_box_st(st, moch_r_c, Vector3(mocheta_w, dh, dt), uv_white_min, uv_white_max)

	# ---------------------------------------------------------------------
	# 5. Tambor Interior Cilíndrico de Secado Horizontal (12 segmentos)
	# ---------------------------------------------------------------------
	var drum_r := minf(dw, dh) * 0.46
	var drum_len := (d - wall_t - dt) * 0.78
	var drum_cz := -hd + wall_t + drum_len * 0.5

	# Collarín oscuro de goma en la boca del portal
	var collar_r_out := drum_r + 0.025
	_add_ring_z_st(st, Vector3(0.0, dy, hd - dt - 0.002), drum_r, collar_r_out, 12, uv_black_min, uv_black_max)

	# Cilindro horizontal del tambor en acero metálico (12 lados)
	_add_cylinder_z_st(st, Vector3(0.0, dy, drum_cz), drum_r, drum_len, 12, uv_steel_min, uv_steel_max, true)

	# Placa circular de fondo del tambor
	_add_disk_z_st(st, Vector3(0.0, dy, -hd + wall_t + 0.002), drum_r, 12, uv_black_min, uv_black_max)

	# 3 Paletas / Baffles de volteo de ropa en el interior del tambor
	_add_dryer_baffles_st(st, Vector3(0.0, dy, drum_cz), drum_r, drum_len * 0.85, 0.034, 0.016, uv_white_min, uv_white_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _build_door_mesh(dw: float, dh: float, dt: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Puerta cuadrada de la secadora (Y:[79..107], X:[50..83])
	var uv_door_min := Vector2(50.0 / 128.0, 79.0 / 128.0)
	var uv_door_max := Vector2(83.0 / 128.0, 107.0 / 128.0)

	var uv_white_min := Vector2(0.008, 0.008)
	var uv_white_max := Vector2(0.250, 0.180)

	var center := Vector3(dw * 0.5, 0.0, dt * 0.5)
	var size := Vector3(dw, dh, dt)

	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v0 := center + Vector3(-hx, -hy, -hz)
	var v1 := center + Vector3( hx, -hy, -hz)
	var v2 := center + Vector3( hx,  hy, -hz)
	var v3 := center + Vector3(-hx,  hy, -hz)
	var v4 := center + Vector3(-hx, -hy,  hz)
	var v5 := center + Vector3( hx, -hy,  hz)
	var v6 := center + Vector3( hx,  hy,  hz)
	var v7 := center + Vector3(-hx,  hy,  hz)

	# +Z Cara frontal de la puerta con recuadro negro
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_door_min, uv_door_max)
	# Cantos y trasera (blancos)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_white_min, uv_white_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_white_min, uv_white_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_white_min, uv_white_max)
	_add_quad_st(st, v7, v6, v2, v3, Vector3.UP, uv_white_min, uv_white_max)
	_add_quad_st(st, v4, v0, v1, v5, Vector3.DOWN, uv_white_min, uv_white_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# =========================================================================
# PRIMITIVAS PARAMÉTRICAS Y MÉTODOS AUXILIARES (SurfaceTool)
# =========================================================================

static func _add_slanted_console_st(st: SurfaceTool, w: float, h: float, c_h: float, z_back: float, z_bot_front: float, z_top_front: float, uv_ctrl_min: Vector2, uv_ctrl_max: Vector2, uv_white_min: Vector2, uv_white_max: Vector2) -> void:
	var hw := w * 0.5
	var y_bot := h
	var y_top := h + c_h

	var vb_bl := Vector3(-hw, y_bot, z_back)
	var vb_br := Vector3( hw, y_bot, z_back)
	var vb_tr := Vector3( hw, y_top, z_back)
	var vb_tl := Vector3(-hw, y_top, z_back)

	var vf_bl := Vector3(-hw, y_bot, z_bot_front)
	var vf_br := Vector3( hw, y_bot, z_bot_front)
	var vf_tr := Vector3( hw, y_top, z_top_front)
	var vf_tl := Vector3(-hw, y_top, z_top_front)

	var slant_norm := Vector3(0.0, z_bot_front - z_top_front, y_top - y_bot).normalized()

	var ctrl_w := minf(w * 0.68, 0.46)
	var h_ctrl := ctrl_w * 0.5

	var vc_bl := Vector3(-h_ctrl, y_bot, z_bot_front)
	var vc_br := Vector3( h_ctrl, y_bot, z_bot_front)
	var vc_tr := Vector3( h_ctrl, y_top, z_top_front)
	var vc_tl := Vector3(-h_ctrl, y_top, z_top_front)

	_add_quad_custom_norm_st(st, vf_bl, vc_bl, vc_tl, vf_tl, slant_norm, uv_white_min, uv_white_max)
	_add_quad_custom_norm_st(st, vc_bl, vc_br, vc_tr, vc_tl, slant_norm, uv_ctrl_min, uv_ctrl_max)
	_add_quad_custom_norm_st(st, vc_br, vf_br, vf_tr, vc_tr, slant_norm, uv_white_min, uv_white_max)

	_add_quad_st(st, vf_tl, vf_tr, vb_tr, vb_tl, Vector3.UP, uv_white_min, uv_white_max)
	_add_quad_st(st, vb_br, vb_bl, vb_tl, vb_tr, Vector3.BACK, uv_white_min, uv_white_max)
	_add_quad_st(st, vb_bl, vf_bl, vf_tl, vb_tl, Vector3.LEFT, uv_white_min, uv_white_max)
	_add_quad_st(st, vf_br, vb_br, vb_tr, vf_tr, Vector3.RIGHT, uv_white_min, uv_white_max)


static func _add_cylinder_z_st(st: SurfaceTool, center: Vector3, radius: float, length: float, segments: int, uv_min: Vector2, uv_max: Vector2, inside: bool = false) -> void:
	var half_l := length * 0.5
	var step := TAU / float(segments)
	for i in range(segments):
		var a0 := float(i) * step
		var a1 := float(i + 1) * step
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)

		var p0_front := center + Vector3(c0 * radius, s0 * radius,  half_l)
		var p0_back  := center + Vector3(c0 * radius, s0 * radius, -half_l)
		var p1_front := center + Vector3(c1 * radius, s1 * radius,  half_l)
		var p1_back  := center + Vector3(c1 * radius, s1 * radius, -half_l)

		var n0 := Vector3(c0, s0, 0.0) * (-1.0 if inside else 1.0)
		var n1 := Vector3(c1, s1, 0.0) * (-1.0 if inside else 1.0)

		var u_a := lerpf(uv_min.x, uv_max.x, float(i) / float(segments))
		var u_b := lerpf(uv_min.x, uv_max.x, float(i + 1) / float(segments))

		if not inside:
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_back)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_max.y)); st.add_vertex(p1_back)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_front)

			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_back)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_front)
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_min.y)); st.add_vertex(p0_front)
		else:
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_back)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_front)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_max.y)); st.add_vertex(p1_back)

			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_back)
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_min.y)); st.add_vertex(p0_front)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_front)


static func _add_ring_z_st(st: SurfaceTool, center: Vector3, r_in: float, r_out: float, segments: int, uv_min: Vector2, uv_max: Vector2) -> void:
	var step := TAU / float(segments)
	var norm := Vector3.FORWARD
	for i in range(segments):
		var a0 := float(i) * step
		var a1 := float(i + 1) * step
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)

		var p0_in  := center + Vector3(c0 * r_in,  s0 * r_in,  0.0)
		var p0_out := center + Vector3(c0 * r_out, s0 * r_out, 0.0)
		var p1_in  := center + Vector3(c1 * r_in,  s1 * r_in,  0.0)
		var p1_out := center + Vector3(c1 * r_out, s1 * r_out, 0.0)

		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p0_in)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p0_out)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p1_out)

		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p0_in)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p1_out)
		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p1_in)


static func _add_disk_z_st(st: SurfaceTool, center: Vector3, radius: float, segments: int, uv_min: Vector2, uv_max: Vector2) -> void:
	var step := TAU / float(segments)
	var norm := Vector3.FORWARD
	var uv_c := (uv_min + uv_max) * 0.5
	for i in range(segments):
		var a0 := float(i) * step
		var a1 := float(i + 1) * step
		var p0 := center + Vector3(cos(a0) * radius, sin(a0) * radius, 0.0)
		var p1 := center + Vector3(cos(a1) * radius, sin(a1) * radius, 0.0)

		st.set_normal(norm); st.set_uv(uv_c); st.add_vertex(center)
		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p0)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p1)


static func _add_dryer_baffles_st(st: SurfaceTool, center: Vector3, drum_r: float, length: float, b_h: float, b_t: float, uv_min: Vector2, uv_max: Vector2) -> void:
	for i in range(3):
		var angle := float(i) * (TAU / 3.0) + (PI * 0.5)
		var rad_dir := Vector3(cos(angle), sin(angle), 0.0)
		var tan_dir := Vector3(-sin(angle), cos(angle), 0.0)

		var b_center := center + rad_dir * (drum_r - b_h * 0.5)
		var hx := b_t * 0.5
		var hy := b_h * 0.5
		var hz := length * 0.5

		var v0 := b_center - tan_dir * hx - rad_dir * hy - Vector3(0, 0, hz)
		var v1 := b_center + tan_dir * hx - rad_dir * hy - Vector3(0, 0, hz)
		var v2 := b_center + tan_dir * hx + rad_dir * hy - Vector3(0, 0, hz)
		var v3 := b_center - tan_dir * hx + rad_dir * hy - Vector3(0, 0, hz)

		var v4 := b_center - tan_dir * hx - rad_dir * hy + Vector3(0, 0, hz)
		var v5 := b_center + tan_dir * hx - rad_dir * hy + Vector3(0, 0, hz)
		var v6 := b_center + tan_dir * hx + rad_dir * hy + Vector3(0, 0, hz)
		var v7 := b_center - tan_dir * hx + rad_dir * hy + Vector3(0, 0, hz)

		_add_quad_custom_norm_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_min, uv_max)
		_add_quad_custom_norm_st(st, v1, v0, v3, v2, Vector3.BACK, uv_min, uv_max)
		_add_quad_custom_norm_st(st, v5, v1, v2, v6, tan_dir, uv_min, uv_max)
		_add_quad_custom_norm_st(st, v0, v4, v7, v3, -tan_dir, uv_min, uv_max)
		_add_quad_custom_norm_st(st, v7, v6, v2, v3, rad_dir, uv_min, uv_max)


static func _add_box_front_custom_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_front_min: Vector2, uv_front_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v0 := center + Vector3(-hx, -hy, -hz)
	var v1 := center + Vector3( hx, -hy, -hz)
	var v2 := center + Vector3( hx,  hy, -hz)
	var v3 := center + Vector3(-hx,  hy, -hz)
	var v4 := center + Vector3(-hx, -hy,  hz)
	var v5 := center + Vector3( hx, -hy,  hz)
	var v6 := center + Vector3( hx,  hy,  hz)
	var v7 := center + Vector3(-hx,  hy,  hz)

	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_front_min, uv_front_max)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_side_min, uv_side_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_side_min, uv_side_max)
	_add_quad_st(st, v7, v6, v2, v3, Vector3.UP, uv_side_min, uv_side_max)
	_add_quad_st(st, v4, v0, v1, v5, Vector3.DOWN, uv_side_min, uv_side_max)


static func _add_simple_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v0 := center + Vector3(-hx, -hy, -hz)
	var v1 := center + Vector3( hx, -hy, -hz)
	var v2 := center + Vector3( hx,  hy, -hz)
	var v3 := center + Vector3(-hx,  hy, -hz)
	var v4 := center + Vector3(-hx, -hy,  hz)
	var v5 := center + Vector3( hx, -hy,  hz)
	var v6 := center + Vector3( hx,  hy,  hz)
	var v7 := center + Vector3(-hx,  hy,  hz)

	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_min, uv_max)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_min, uv_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_min, uv_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_min, uv_max)
	_add_quad_st(st, v7, v6, v2, v3, Vector3.UP, uv_min, uv_max)
	_add_quad_st(st, v4, v0, v1, v5, Vector3.DOWN, uv_min, uv_max)


static func _add_quad_st(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	_add_quad_custom_norm_st(st, v0, v1, v2, v3, norm, uv_min, uv_max)


static func _add_quad_custom_norm_st(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	var u0 := Vector2(uv_min.x, uv_max.y)
	var u1 := Vector2(uv_max.x, uv_max.y)
	var u2 := Vector2(uv_max.x, uv_min.y)
	var u3 := Vector2(uv_min.x, uv_min.y)

	st.set_normal(norm); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(u1); st.add_vertex(v1)
	st.set_normal(norm); st.set_uv(u2); st.add_vertex(v2)

	st.set_normal(norm); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(u2); st.add_vertex(v2)
	st.set_normal(norm); st.set_uv(u3); st.add_vertex(v3)


func _setup_collision(w: float, d: float, h: float, c_h: float, dw: float, dh: float, dy: float, dt: float) -> void:
	var body_col := FurnitureInteractProxy.new()
	body_col.name = "DryerCollision"
	body_col.target_callable = Callable(self, "toggle_door")

	var base_shape := CollisionShape3D.new()
	var base_box := BoxShape3D.new()
	base_box.size = Vector3(w, h, d)
	base_shape.shape = base_box
	base_shape.position = Vector3(0.0, h * 0.5, 0.0)
	body_col.add_child(base_shape)

	var console_shape := CollisionShape3D.new()
	var console_box := BoxShape3D.new()
	console_box.size = Vector3(w, c_h, console_depth)
	console_shape.shape = console_box
	console_shape.position = Vector3(0.0, h + c_h * 0.5, -d * 0.5 + console_depth * 0.5)
	body_col.add_child(console_shape)

	_body_collision = body_col
	add_child(_body_collision)

	if _door_pivot:
		var door_body := FurnitureInteractProxy.new()
		door_body.name = "DryerDoorCollision"
		door_body.target_callable = Callable(self, "toggle_door")
		var d_col := CollisionShape3D.new()
		var d_box := BoxShape3D.new()
		d_box.size = Vector3(dw, dh, dt)
		d_col.shape = d_box
		d_col.position = Vector3(dw * 0.5, 0.0, dt * 0.5)
		door_body.add_child(d_col)
		_door_pivot.add_child(door_body)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Look nítido PSX / retro pixel-art
	mat.roughness = 0.40
	mat.metallic = 0.04
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return mat
