class_name ApplianceWasher
extends Node3D

## Lavadora de Ropa Procedural de Carga Superior (Top-Loading)
## - Copete trasero inclinado (~20°) con panel de mandos central (perillas y display azul PSX pixel-art)
## - Textura con filtrado NEAREST para máxima nitidez estilo retro/PSX
## - Tapa superior abatible con apertura vertical hacia el copete
## - Tina interior cilíndrica (12 segmentos) con collarín de sellado oscuro
## - Agitador central ("rodillo de lavado") con faldón cónico, eje y 4 aspas/aletas de alto contraste
## - Construida 100% con geometría paramétrica optimizada para GPU Instancing (1 draw call)

const TEXTURE_PATH: String = "res://assets/textures/furniture/washer.png"

@export_group("Dimensiones")
@export var width: float = 0.68           ## Ancho total (68cm)
@export var depth: float = 0.68           ## Profundidad total (68cm)
@export var height: float = 0.88          ## Altura hasta la encimera/tapa (88cm)
@export var console_height: float = 0.16  ## Altura del copete trasero (16cm, total 1.04m)
@export var console_depth: float = 0.12   ## Profundidad de la base del copete (12cm)
@export var lid_thickness: float = 0.018  ## Grosor de la tapa superior (1.8cm)

@export_group("Apertura")
@export_range(0.0, 1.0) var door_open_ratio: float = 0.0:
	set(val):
		door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angle()

const MAX_DOOR_ANGLE: float = deg_to_rad(78.0)

var _body_mesh_instance: MeshInstance3D = null
var _door_pivot: Node3D = null
var _door_mesh_instance: MeshInstance3D = null
var _body_collision: StaticBody3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_body_mesh: ArrayMesh = null
static var _cached_lid_mesh: ArrayMesh = null
static var _cached_complete_mesh: ArrayMesh = null


## Retorna la malla compartida del cuerpo para GPU Instancing
static func get_shared_body_mesh() -> ArrayMesh:
	if _cached_body_mesh == null:
		var lid_w := 0.68 * 0.70
		var lid_d := 0.42
		var lid_hinge_z := -0.68 * 0.5 + 0.12 + 0.02
		_cached_body_mesh = _build_washer_body_mesh(0.68, 0.68, 0.88, 0.16, 0.12, lid_w, lid_d, lid_hinge_z)
	return _cached_body_mesh


## Retorna la malla compartida de la tapa superior
static func get_shared_lid_mesh() -> ArrayMesh:
	if _cached_lid_mesh == null:
		var lid_w := 0.68 * 0.70
		var lid_d := 0.42
		_cached_lid_mesh = _build_lid_mesh(lid_w, lid_d, 0.018)
	return _cached_lid_mesh


## Retorna la malla compartida completa (cuerpo + tapa cerrada) para GPU Instancing en 1 Draw Call
static func get_shared_mesh() -> ArrayMesh:
	if _cached_complete_mesh != null:
		return _cached_complete_mesh

	var body := get_shared_body_mesh()
	var lid := get_shared_lid_mesh()

	var h := 0.88
	var lid_hinge_z := -0.68 * 0.5 + 0.12 + 0.02
	var lid_xform := Transform3D(Basis.IDENTITY, Vector3(0.0, h, lid_hinge_z))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(body, 0, Transform3D.IDENTITY)
	st.append_from(lid, 0, lid_xform)
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
	_build_washer()


func _build_washer() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()

	# Dimensiones y posición de la tapa superior (carga superior)
	var lid_w := width * 0.70 # 0.476m
	var lid_d := 0.42         # 0.42m
	var lid_hinge_z := -depth * 0.5 + console_depth + 0.02 # Justo frente al copete inclinado

	var is_default_dim := is_equal_approx(width, 0.68) and is_equal_approx(depth, 0.68) and is_equal_approx(height, 0.88) and is_equal_approx(console_height, 0.16) and is_equal_approx(console_depth, 0.12)

	# 1. Carcasa / Cuerpo Principal con Copete Inclinado, Tina Redonda y Rodillo Agitador
	var body_mesh: ArrayMesh
	if is_default_dim:
		body_mesh = get_shared_body_mesh()
	else:
		body_mesh = _build_washer_body_mesh(width, depth, height, console_height, console_depth, lid_w, lid_d, lid_hinge_z)

	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "WasherBodyMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat
	add_child(_body_mesh_instance)

	# 2. Tapa Superior Abatible (Bisagra posterior, se abre hacia arriba y atrás)
	_door_pivot = Node3D.new()
	_door_pivot.name = "WasherLidPivot"
	_door_pivot.position = Vector3(0.0, height, lid_hinge_z)
	add_child(_door_pivot)

	var lid_mesh: ArrayMesh
	if is_default_dim and is_equal_approx(lid_thickness, 0.018):
		if not _cached_lid_mesh:
			_cached_lid_mesh = _build_lid_mesh(lid_w, lid_d, lid_thickness)
		lid_mesh = _cached_lid_mesh
	else:
		lid_mesh = _build_lid_mesh(lid_w, lid_d, lid_thickness)

	_door_mesh_instance = MeshInstance3D.new()
	_door_mesh_instance.name = "WasherLidMesh"
	_door_mesh_instance.mesh = lid_mesh
	_door_mesh_instance.material_override = mat
	_door_pivot.add_child(_door_mesh_instance)

	# 3. Colisiones Físicas Interactivas con tecla [E]
	_setup_collision(width, depth, height, console_height, lid_w, lid_d, lid_thickness, lid_hinge_z)
	_update_door_angle()


func _update_door_angle() -> void:
	if _door_pivot:
		_door_pivot.rotation.x = -door_open_ratio * MAX_DOOR_ANGLE


## Abre o cierra la tapa de la lavadora
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

static func _build_washer_body_mesh(w: float, d: float, h: float, c_h: float, c_d: float, lw: float, ld: float, lz: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas washer.png (128x128):
	var uv_white_min := Vector2(0.008, 0.008)
	var uv_white_max := Vector2(0.250, 0.180)

	var uv_ctrl_min := Vector2(0.383, 0.203)
	var uv_ctrl_max := Vector2(0.664, 0.273)

	var uv_front_min := Vector2(0.008, 0.574) # Incluye costura negra Y=74
	var uv_front_max := Vector2(0.992, 0.992)

	# Región gris acero cepillado metálico para el tambor (Y:[30..33], X:[56..80])
	var uv_steel_min := Vector2(56.0 / 128.0, 30.0 / 128.0)
	var uv_steel_max := Vector2(80.0 / 128.0, 33.0 / 128.0)

	# Región negra oscura para empaque/collarín de goma (Y=74)
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
	# 2. Carcasa Principal: Base, Trasera, Laterales y Frontal
	# ---------------------------------------------------------------------
	# Base inferior (-Y)
	_add_simple_box_st(st, Vector3(0.0, wall_t * 0.5, 0.0), Vector3(w, wall_t, d), uv_white_min, uv_white_max)

	# Pared Trasera (-Z)
	_add_simple_box_st(st, Vector3(0.0, wall_t + (h - wall_t) * 0.5, -hd + wall_t * 0.5), Vector3(w, h - wall_t, wall_t), uv_white_min, uv_white_max)

	# Pared Lateral Izquierda (-X)
	_add_simple_box_st(st, Vector3(-hw + wall_t * 0.5, wall_t + (h - wall_t) * 0.5, 0.0), Vector3(wall_t, h - wall_t, d - wall_t * 2.0), uv_white_min, uv_white_max)

	# Pared Lateral Derecha (+X)
	_add_simple_box_st(st, Vector3( hw - wall_t * 0.5, wall_t + (h - wall_t) * 0.5, 0.0), Vector3(wall_t, h - wall_t, d - wall_t * 2.0), uv_white_min, uv_white_max)

	# Frontal (+Z): Cara lisa blanca con costura negra perimetral superior
	_add_box_front_custom_st(st, Vector3(0.0, wall_t + (h - wall_t) * 0.5, hd - wall_t * 0.5), Vector3(w, h - wall_t, wall_t), uv_front_min, uv_front_max, uv_white_min, uv_white_max)

	# ---------------------------------------------------------------------
	# 3. Encimera Superior (Top Deck): Marco perimetral alrededor de la tina
	# ---------------------------------------------------------------------
	var deck_z_start := z_bot_front
	var deck_z_end := hd
	var deck_t := wall_t

	var rear_rim_l := lz - deck_z_start
	if rear_rim_l > 0.005:
		_add_simple_box_st(st, Vector3(0.0, h - deck_t * 0.5, deck_z_start + rear_rim_l * 0.5), Vector3(w, deck_t, rear_rim_l), uv_white_min, uv_white_max)

	var front_rim_l := deck_z_end - (lz + ld)
	if front_rim_l > 0.005:
		_add_simple_box_st(st, Vector3(0.0, h - deck_t * 0.5, deck_z_end - front_rim_l * 0.5), Vector3(w, deck_t, front_rim_l), uv_white_min, uv_white_max)

	var side_rim_w := (w - lw) * 0.5
	if side_rim_w > 0.005:
		_add_simple_box_st(st, Vector3(-hw + side_rim_w * 0.5, h - deck_t * 0.5, lz + ld * 0.5), Vector3(side_rim_w, deck_t, ld), uv_white_min, uv_white_max)
		_add_simple_box_st(st, Vector3( hw - side_rim_w * 0.5, h - deck_t * 0.5, lz + ld * 0.5), Vector3(side_rim_w, deck_t, ld), uv_white_min, uv_white_max)

	# ---------------------------------------------------------------------
	# 4. Tina Cilíndrica Interior de Lavado (12 lados con acabado metálico de acero)
	# ---------------------------------------------------------------------
	var tub_center_z := lz + ld * 0.5
	var tub_r := minf(lw, ld) * 0.48 # ~0.20m de radio
	var tub_floor_y := wall_t + 0.12
	var tub_h := (h - deck_t) - tub_floor_y
	var tub_center_y := tub_floor_y + tub_h * 0.5
	var tub_pos := Vector3(0.0, tub_center_y, tub_center_z)

	# Bisel / Repisa de la boca de la tina
	var bezel_r_out := tub_r + 0.035
	var bezel_r_mid := tub_r + 0.015
	_add_ring_st(st, Vector3(0.0, h - 0.002, tub_center_z), bezel_r_mid, bezel_r_out, 12, uv_white_min, uv_white_max)

	# Empaque / Collarín oscuro de goma en el borde interior del agujero (contraste visual rotundo)
	_add_ring_st(st, Vector3(0.0, h - 0.004, tub_center_z), tub_r, bezel_r_mid, 12, uv_black_min, uv_black_max)

	# Pared cilíndrica interior de acero metálico (12 lados con normales hacia adentro)
	_add_cylinder_st(st, tub_pos, tub_r, tub_h, 12, uv_steel_min, uv_steel_max, true)

	# Anillo escalonado inferior
	_add_ring_st(st, Vector3(0.0, tub_floor_y + 0.01, tub_center_z), tub_r * 0.5, tub_r, 12, uv_steel_min, uv_steel_max)

	# Fondo redondo oscuro de la tina
	_add_disk_st(st, Vector3(0.0, tub_floor_y, tub_center_z), tub_r * 0.5, 12, uv_black_min, uv_black_max)

	# ---------------------------------------------------------------------
	# 5. Agitador Central ("Rodillo de Lavado" con columna estriada y 4 aspas/aletas)
	# ---------------------------------------------------------------------
	var agitator_cz := tub_center_z
	var agitator_h := tub_h * 0.88
	var rod_r := 0.038
	var skirt_r := 0.078
	var skirt_h := 0.080

	# Falda cónica de la base del agitador en acero metálico
	_add_cylinder_tapered_st(st, Vector3(0.0, tub_floor_y + skirt_h * 0.5, agitator_cz), skirt_r, rod_r, skirt_h, 12, uv_steel_min, uv_steel_max)

	# Eje cilíndrico central ("rodillo" blanco limpio)
	var col_h := agitator_h - skirt_h - 0.035
	var col_cy := tub_floor_y + skirt_h + col_h * 0.5
	_add_cylinder_st(st, Vector3(0.0, col_cy, agitator_cz), rod_r, col_h, 12, uv_white_min, uv_white_max, false)

	# Tapa / Taza dispensadora superior del agitador con anillo oscuro
	var cap_r := rod_r * 1.18
	var cap_h := 0.030
	var cap_cy := tub_floor_y + skirt_h + col_h + cap_h * 0.5
	_add_cylinder_st(st, Vector3(0.0, cap_cy, agitator_cz), cap_r, cap_h, 12, uv_steel_min, uv_steel_max, false)
	_add_disk_st(st, Vector3(0.0, cap_cy + cap_h * 0.5, agitator_cz), cap_r, 12, uv_black_min, uv_black_max)

	# 4 Aspas / Vanes helicoidales de lavado (color acero metálico de alto contraste)
	var fin_ext := 0.054
	var fin_h := agitator_h * 0.68
	var fin_t := 0.015
	var fin_base_y := tub_floor_y + 0.015
	_add_agitator_fins_st(st, Vector3(0.0, fin_base_y, agitator_cz), rod_r, fin_ext, fin_h, fin_t, uv_steel_min, uv_steel_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _build_lid_mesh(lw: float, ld: float, lt: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tapa de la lavadora con recuadro negro (Y:[38..66], X:[50..83])
	var uv_lid_min := Vector2(50.0 / 128.0, 38.0 / 128.0)
	var uv_lid_max := Vector2(83.0 / 128.0, 66.0 / 128.0)

	var uv_white_min := Vector2(0.008, 0.008)
	var uv_white_max := Vector2(0.250, 0.180)

	var center := Vector3(0.0, lt * 0.5, ld * 0.5)
	var size := Vector3(lw, lt, ld)

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

	# +Y Cara Superior de la Tapa (con recuadro negro de la puerta, orientando X=U, Z=V)
	_add_quad_st(st, v7, v6, v2, v3, Vector3.UP, uv_lid_min, uv_lid_max)
	# -Y Cara Inferior de la Tapa
	_add_quad_st(st, v4, v0, v1, v5, Vector3.DOWN, uv_white_min, uv_white_max)
	# Cantos
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_white_min, uv_white_max)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_white_min, uv_white_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_white_min, uv_white_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_white_min, uv_white_max)

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

	# Ala Izquierda frontal
	_add_quad_custom_norm_st(st, vf_bl, vc_bl, vc_tl, vf_tl, slant_norm, uv_white_min, uv_white_max)
	# Centro con mandos y pantalla
	_add_quad_custom_norm_st(st, vc_bl, vc_br, vc_tr, vc_tl, slant_norm, uv_ctrl_min, uv_ctrl_max)
	# Ala Derecha frontal
	_add_quad_custom_norm_st(st, vc_br, vf_br, vf_tr, vc_tr, slant_norm, uv_white_min, uv_white_max)

	# Cara Superior
	_add_quad_st(st, vf_tl, vf_tr, vb_tr, vb_tl, Vector3.UP, uv_white_min, uv_white_max)
	# Cara Trasera
	_add_quad_st(st, vb_br, vb_bl, vb_tl, vb_tr, Vector3.BACK, uv_white_min, uv_white_max)
	# Mejilla Izquierda (Trapezoide inclinado)
	_add_quad_st(st, vb_bl, vf_bl, vf_tl, vb_tl, Vector3.LEFT, uv_white_min, uv_white_max)
	# Mejilla Derecha (Trapezoide inclinado)
	_add_quad_st(st, vf_br, vb_br, vb_tr, vf_tr, Vector3.RIGHT, uv_white_min, uv_white_max)


static func _add_cylinder_st(st: SurfaceTool, center: Vector3, radius: float, height: float, segments: int, uv_min: Vector2, uv_max: Vector2, inside: bool = false) -> void:
	var half_h := height * 0.5
	var step := TAU / float(segments)
	for i in range(segments):
		var a0 := float(i) * step
		var a1 := float(i + 1) * step
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)

		var p0_bot := center + Vector3(c0 * radius, -half_h, s0 * radius)
		var p0_top := center + Vector3(c0 * radius,  half_h, s0 * radius)
		var p1_bot := center + Vector3(c1 * radius, -half_h, s1 * radius)
		var p1_top := center + Vector3(c1 * radius,  half_h, s1 * radius)

		var n0 := Vector3(c0, 0.0, s0) * (-1.0 if inside else 1.0)
		var n1 := Vector3(c1, 0.0, s1) * (-1.0 if inside else 1.0)

		var u_a := lerpf(uv_min.x, uv_max.x, float(i) / float(segments))
		var u_b := lerpf(uv_min.x, uv_max.x, float(i + 1) / float(segments))

		if not inside:
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_bot)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_max.y)); st.add_vertex(p1_bot)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_top)

			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_bot)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_top)
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_min.y)); st.add_vertex(p0_top)
		else:
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_bot)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_top)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_max.y)); st.add_vertex(p1_bot)

			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_bot)
			st.set_normal(n0); st.set_uv(Vector2(u_a, uv_min.y)); st.add_vertex(p0_top)
			st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_top)


static func _add_cylinder_tapered_st(st: SurfaceTool, center: Vector3, r_bot: float, r_top: float, height: float, segments: int, uv_min: Vector2, uv_max: Vector2) -> void:
	var half_h := height * 0.5
	var step := TAU / float(segments)
	for i in range(segments):
		var a0 := float(i) * step
		var a1 := float(i + 1) * step
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)

		var p0_bot := center + Vector3(c0 * r_bot, -half_h, s0 * r_bot)
		var p0_top := center + Vector3(c0 * r_top,  half_h, s0 * r_top)
		var p1_bot := center + Vector3(c1 * r_bot, -half_h, s1 * r_bot)
		var p1_top := center + Vector3(c1 * r_top,  half_h, s1 * r_top)

		var n0 := Vector3(c0, 0.2, s0).normalized()
		var n1 := Vector3(c1, 0.2, s1).normalized()

		var u_a := lerpf(uv_min.x, uv_max.x, float(i) / float(segments))
		var u_b := lerpf(uv_min.x, uv_max.x, float(i + 1) / float(segments))

		st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_bot)
		st.set_normal(n1); st.set_uv(Vector2(u_b, uv_max.y)); st.add_vertex(p1_bot)
		st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_top)

		st.set_normal(n0); st.set_uv(Vector2(u_a, uv_max.y)); st.add_vertex(p0_bot)
		st.set_normal(n1); st.set_uv(Vector2(u_b, uv_min.y)); st.add_vertex(p1_top)
		st.set_normal(n0); st.set_uv(Vector2(u_a, uv_min.y)); st.add_vertex(p0_top)


static func _add_ring_st(st: SurfaceTool, center: Vector3, r_in: float, r_out: float, segments: int, uv_min: Vector2, uv_max: Vector2) -> void:
	var step := TAU / float(segments)
	var norm := Vector3.UP
	for i in range(segments):
		var a0 := float(i) * step
		var a1 := float(i + 1) * step
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)

		var p0_in := center + Vector3(c0 * r_in, 0.0, s0 * r_in)
		var p0_out := center + Vector3(c0 * r_out, 0.0, s0 * r_out)
		var p1_in := center + Vector3(c1 * r_in, 0.0, s1 * r_in)
		var p1_out := center + Vector3(c1 * r_out, 0.0, s1 * r_out)

		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p0_in)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p0_out)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p1_out)

		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p0_in)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p1_out)
		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p1_in)


static func _add_disk_st(st: SurfaceTool, center: Vector3, radius: float, segments: int, uv_min: Vector2, uv_max: Vector2) -> void:
	var step := TAU / float(segments)
	var norm := Vector3.UP
	var uv_c := (uv_min + uv_max) * 0.5
	for i in range(segments):
		var a0 := float(i) * step
		var a1 := float(i + 1) * step
		var p0 := center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)

		st.set_normal(norm); st.set_uv(uv_c); st.add_vertex(center)
		st.set_normal(norm); st.set_uv(uv_min); st.add_vertex(p0)
		st.set_normal(norm); st.set_uv(uv_max); st.add_vertex(p1)


static func _add_agitator_fins_st(st: SurfaceTool, base_pos: Vector3, rod_r: float, fin_ext: float, fin_h: float, fin_t: float, uv_min: Vector2, uv_max: Vector2) -> void:
	for angle_idx in range(4):
		var angle := float(angle_idx) * (PI * 0.5)
		var f_dir := Vector3(cos(angle), 0.0, sin(angle))
		var r_dir := Vector3(-sin(angle), 0.0, cos(angle))

		var ht := fin_t * 0.5
		var p_root_bot := base_pos + f_dir * rod_r
		var p_tip_bot  := base_pos + f_dir * (rod_r + fin_ext)
		var p_tip_top  := base_pos + f_dir * (rod_r + fin_ext * 0.35) + Vector3(0.0, fin_h * 0.40, 0.0)
		var p_root_top := base_pos + f_dir * rod_r + Vector3(0.0, fin_h, 0.0)

		var v0 := p_root_bot - r_dir * ht
		var v1 := p_tip_bot  - r_dir * ht
		var v2 := p_tip_top  - r_dir * ht
		var v3 := p_root_top - r_dir * ht

		var v4 := p_root_bot + r_dir * ht
		var v5 := p_tip_bot  + r_dir * ht
		var v6 := p_tip_top  + r_dir * ht
		var v7 := p_root_top + r_dir * ht

		var n_l := -r_dir
		var n_r :=  r_dir

		_add_quad_custom_norm_st(st, v0, v1, v2, v3, n_l, uv_min, uv_max)
		_add_quad_custom_norm_st(st, v5, v4, v7, v6, n_r, uv_min, uv_max)
		_add_quad_custom_norm_st(st, v1, v5, v6, v2, f_dir, uv_min, uv_max)
		_add_quad_custom_norm_st(st, v2, v6, v7, v3, Vector3.UP, uv_min, uv_max)


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


func _setup_collision(w: float, d: float, h: float, c_h: float, lw: float, ld: float, lt: float, lz: float) -> void:
	var body_col := FurnitureInteractProxy.new()
	body_col.name = "WasherCollision"
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
		var lid_body := FurnitureInteractProxy.new()
		lid_body.name = "WasherLidCollision"
		lid_body.target_callable = Callable(self, "toggle_door")
		var l_col := CollisionShape3D.new()
		var l_box := BoxShape3D.new()
		l_box.size = Vector3(lw, lt, ld)
		l_col.shape = l_box
		l_col.position = Vector3(0.0, lt * 0.5, ld * 0.5)
		lid_body.add_child(l_col)
		_door_pivot.add_child(lid_body)


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
