class_name ArmchairLeather
extends Node3D

## Sillón Orejero Clásico de Cuero Marrón (Wingback Armchair)
## - Generado por geometría paramétrica optimizada en 1 SOLO Draw Call para GPU Instancing.
## - Utiliza el atlas oficial de 128x128 con botones capitoné, cojín acolchado y patas con remaches.
## - Compatible con MultiMeshInstance3D y con caché estática de VRAM.

const TEXTURE_PATH: String = "res://assets/textures/furniture/sofa_leather.png"

@export_group("Dimensiones")
@export var width: float = 0.86        ## Ancho total (86cm)
@export var depth: float = 0.84        ## Profundidad total (84cm)
@export var height: float = 1.02       ## Altura total del respaldo orejero (1.02m)
@export var seat_height: float = 0.42  ## Altura de la superficie del cojín (42cm)

var _mesh_instance: MeshInstance3D = null
var _collision_body: StaticBody3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_shared_mesh: ArrayMesh = null


func _ready() -> void:
	_build_armchair()


func _build_armchair() -> void:
	for child in get_children():
		child.queue_free()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "ArmchairMesh"

	var is_default_dim := (
		is_equal_approx(width, 0.86)
		and is_equal_approx(depth, 0.84)
		and is_equal_approx(height, 1.02)
		and is_equal_approx(seat_height, 0.42)
	)

	if is_default_dim:
		_mesh_instance.mesh = get_shared_mesh()
	else:
		_mesh_instance.mesh = build_armchair_mesh(width, depth, height, seat_height)

	_mesh_instance.material_override = _get_or_create_material()
	add_child(_mesh_instance)

	_setup_collision(width, depth, height, seat_height)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.65
	mat.metallic = 0.05

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return _cached_material


## Obtiene la malla compartida en VRAM para miles de instancias
static func get_shared_mesh() -> ArrayMesh:
	if _cached_shared_mesh == null:
		_cached_shared_mesh = build_armchair_mesh(0.86, 0.84, 1.02, 0.42)
	return _cached_shared_mesh


## Construye toda la geometría del sillón orejero en 1 sola malla (1 draw call)
static func build_armchair_mesh(w: float, d: float, h: float, s_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Coordenadas UV del Atlas 128x128 (sofa_leather.png):
	var uv_capitone_min := Vector2(87.0 / 128.0, 2.0 / 128.0)
	var uv_capitone_max := Vector2(125.0 / 128.0, 42.0 / 128.0)

	var uv_smooth_min := Vector2(87.0 / 128.0, 44.0 / 128.0)
	var uv_smooth_max := Vector2(125.0 / 128.0, 85.0 / 128.0)

	var uv_leg_min := Vector2(68.0 / 128.0, 2.0 / 128.0)
	var uv_leg_max := Vector2(85.0 / 128.0, 42.0 / 128.0)

	var uv_cushion_min := Vector2(21.0 / 128.0, 34.0 / 128.0)
	var uv_cushion_max := Vector2(68.0 / 128.0, 80.0 / 128.0)

	var uv_side_min := Vector2(12.0 / 128.0, 82.0 / 128.0)
	var uv_side_max := Vector2(102.0 / 128.0, 126.0 / 128.0)

	var uv_arm_min := Vector2(5.0 / 128.0, 43.0 / 128.0)
	var uv_arm_max := Vector2(20.0 / 128.0, 80.0 / 128.0)

	var hw := w * 0.5
	var hd := d * 0.5
	var leg_h := 0.21           # Altura de patas (21cm)
	var base_y := leg_h
	var apron_h := 0.08         # Faldón perimetral bajo el asiento
	var arm_w := 0.11           # Grosor descansabrazos: 11cm
	var arm_h := 0.56           # Altura superior de descansabrazos: 56cm
	var back_t := 0.10          # Grosor del respaldo: 10cm

	# -------------------------------------------------------------------------
	# 1. 4 PATAS EN PIRÁMIDE TRUNCADA (Frustums oscuros con remaches)
	# -------------------------------------------------------------------------
	var top_sz := 0.052
	var bot_sz := 0.028
	var leg_inset_x := 0.045
	var leg_inset_z := 0.045

	var fx := hw - leg_inset_x
	var fz_front := hd - leg_inset_z
	var fz_back := -hd + leg_inset_z

	# Pata delantera izquierda (-X, +Z) con splay hacia afuera
	_add_tapered_leg(st, Vector3(-fx, base_y, fz_front), Vector3(-fx - 0.015, 0.0, fz_front + 0.015), top_sz, bot_sz, uv_leg_min, uv_leg_max)
	# Pata delantera derecha (+X, +Z)
	_add_tapered_leg(st, Vector3( fx, base_y, fz_front), Vector3( fx + 0.015, 0.0, fz_front + 0.015), top_sz, bot_sz, uv_leg_min, uv_leg_max)
	# Pata trasera izquierda (-X, -Z)
	_add_tapered_leg(st, Vector3(-fx, base_y, fz_back), Vector3(-fx - 0.015, 0.0, fz_back - 0.020), top_sz, bot_sz, uv_leg_min, uv_leg_max)
	# Pata trasera derecha (+X, -Z)
	_add_tapered_leg(st, Vector3( fx, base_y, fz_back), Vector3( fx + 0.015, 0.0, fz_back - 0.020), top_sz, bot_sz, uv_leg_min, uv_leg_max)

	# -------------------------------------------------------------------------
	# 2. BASTIDOR / BASE INFERIOR DEL ASIENTO (Faldón perimetral de cuero)
	# -------------------------------------------------------------------------
	var apron_cy := base_y + apron_h * 0.5
	_add_box(st, Vector3(0.0, apron_cy, 0.0), Vector3(w, apron_h, d), uv_smooth_min, uv_smooth_max)

	# -------------------------------------------------------------------------
	# 3. COJÍN DE ASIENTO (Plush Cushion)
	# -------------------------------------------------------------------------
	var c_w := w - (arm_w * 2.0) + 0.01
	var c_d := d - back_t - 0.06
	var c_cz := (-hd + back_t) + c_d * 0.5 + 0.03
	var c_t := 0.12
	var c_cy := (base_y + apron_h) + c_t * 0.5

	# Cojín: cara superior con la textura de cojín acolchado
	_add_cushion_box(st, Vector3(0.0, c_cy, c_cz), Vector3(c_w, c_t, c_d), uv_cushion_min, uv_cushion_max, uv_smooth_min, uv_smooth_max)

	# -------------------------------------------------------------------------
	# 4. DESCANSABRAZOS LATERALES (Con caída biselada y frente estilizado)
	# -------------------------------------------------------------------------
	var arm_len := d - back_t - 0.02
	var arm_cz := (-hd + back_t) + arm_len * 0.5
	var arm_base_y := base_y + apron_h
	var arm_total_h := arm_h - arm_base_y

	# Brazo izquierdo (-X)
	var lx := -hw + arm_w * 0.5
	_add_armrest(st, Vector3(lx, arm_base_y, arm_cz), arm_w, arm_len, arm_total_h, uv_arm_min, uv_arm_max, uv_smooth_min, uv_smooth_max, true)

	# Brazo derecho (+X)
	var rx := hw - arm_w * 0.5
	_add_armrest(st, Vector3(rx, arm_base_y, arm_cz), arm_w, arm_len, arm_total_h, uv_arm_min, uv_arm_max, uv_smooth_min, uv_smooth_max, false)

	# -------------------------------------------------------------------------
	# 5. OREJERAS LATERALES (Wings que nacen del descansabrazos y abrazan el respaldo)
	# -------------------------------------------------------------------------
	var wing_base_y := arm_h - 0.08
	var wing_top_y := h
	_add_wing(st, -hw, wing_base_y, wing_top_y, arm_w, -hd, -hd + back_t + 0.26, uv_side_min, uv_side_max, uv_smooth_min, uv_smooth_max, true)
	_add_wing(st,  hw, wing_base_y, wing_top_y, arm_w, -hd, -hd + back_t + 0.26, uv_side_min, uv_side_max, uv_smooth_min, uv_smooth_max, false)

	# -------------------------------------------------------------------------
	# 6. RESPALDO ALTO CON CAPITONÉ (Botones romboidales en cuero)
	# -------------------------------------------------------------------------
	var back_w := w - (arm_w * 2.0) + 0.04
	var back_base_y := base_y + apron_h + 0.02
	var back_h := h - back_base_y
	var tilt_z := 0.065 # Inclinación suave hacia atrás (~8°)

	_add_tufted_backrest(st, back_w, back_base_y, back_h, back_t, -hd + back_t * 0.5, tilt_z, uv_capitone_min, uv_capitone_max, uv_smooth_min, uv_smooth_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# =========================================================================
# GENERADORES DE PRIMITIVAS Y COMPONENTES
# =========================================================================

## Genera una pata en pirámide truncada cuadrangular (4 caras trapezoidales + tapa inferior)
static func _add_tapered_leg(st: SurfaceTool, top_c: Vector3, bot_c: Vector3, top_s: float, bot_s: float, uv_min: Vector2, uv_max: Vector2) -> void:
	var ht := top_s * 0.5
	var hb := bot_s * 0.5

	# Vértices superiores (Y superior)
	var t0 := top_c + Vector3(-ht, 0.0, -ht)
	var t1 := top_c + Vector3( ht, 0.0, -ht)
	var t2 := top_c + Vector3( ht, 0.0,  ht)
	var t3 := top_c + Vector3(-ht, 0.0,  ht)

	# Vértices inferiores (Y inferior / suelo)
	var b0 := bot_c + Vector3(-hb, 0.0, -hb)
	var b1 := bot_c + Vector3( hb, 0.0, -hb)
	var b2 := bot_c + Vector3( hb, 0.0,  hb)
	var b3 := bot_c + Vector3(-hb, 0.0,  hb)

	# 4 Caras trapezoidales con la textura oscura/remachada
	# Front (+Z)
	_add_quad(st, b3, b2, t2, t3, Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# Back (-Z)
	_add_quad(st, b1, b0, t0, t1, Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# Left (-X)
	_add_quad(st, b0, b3, t3, t0, Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# Right (+X)
	_add_quad(st, b2, b1, t1, t2, Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))

	# Tapa inferior (suelo -Y)
	_add_quad(st, b0, b1, b2, b3, uv_min, Vector2(uv_max.x, uv_min.y), uv_max, Vector2(uv_min.x, uv_max.y))


## Caja simple texturizada
static func _add_box(st: SurfaceTool, center: Vector3, sz: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	var hx := sz.x * 0.5
	var hy := sz.y * 0.5
	var hz := sz.z * 0.5

	var v := [
		center + Vector3(-hx, -hy,  hz),
		center + Vector3( hx, -hy,  hz),
		center + Vector3( hx,  hy,  hz),
		center + Vector3(-hx,  hy,  hz),
		center + Vector3(-hx, -hy, -hz),
		center + Vector3( hx, -hy, -hz),
		center + Vector3( hx,  hy, -hz),
		center + Vector3(-hx,  hy, -hz)
	]

	# +Z
	_add_quad(st, v[0], v[1], v[2], v[3], Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# -Z
	_add_quad(st, v[5], v[4], v[7], v[6], Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# +X
	_add_quad(st, v[1], v[5], v[6], v[2], Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# -X
	_add_quad(st, v[4], v[0], v[3], v[7], Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# +Y
	_add_quad(st, v[3], v[2], v[6], v[7], Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))
	# -Y
	_add_quad(st, v[4], v[5], v[1], v[0], Vector2(uv_min.x, uv_max.y), Vector2(uv_max.x, uv_max.y), Vector2(uv_max.x, uv_min.y), Vector2(uv_min.x, uv_min.y))


## Cojín de asiento con cara superior mapeada a la textura de cojín acolchado
static func _add_cushion_box(st: SurfaceTool, center: Vector3, sz: Vector3, uv_top_min: Vector2, uv_top_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2) -> void:
	var hx := sz.x * 0.5
	var hy := sz.y * 0.5
	var hz := sz.z * 0.5

	var v := [
		center + Vector3(-hx, -hy,  hz),
		center + Vector3( hx, -hy,  hz),
		center + Vector3( hx,  hy,  hz),
		center + Vector3(-hx,  hy,  hz),
		center + Vector3(-hx, -hy, -hz),
		center + Vector3( hx, -hy, -hz),
		center + Vector3( hx,  hy, -hz),
		center + Vector3(-hx,  hy, -hz)
	]

	# +Z Frente del cojín
	_add_quad(st, v[0], v[1], v[2], v[3], Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# -Z
	_add_quad(st, v[5], v[4], v[7], v[6], Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# +X
	_add_quad(st, v[1], v[5], v[6], v[2], Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# -X
	_add_quad(st, v[4], v[0], v[3], v[7], Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# +Y Cara Superior: Textura de Cojín con botones/bordes redondeados del atlas
	_add_quad(st, v[3], v[2], v[6], v[7], Vector2(uv_top_min.x, uv_top_max.y), Vector2(uv_top_max.x, uv_top_max.y), Vector2(uv_top_max.x, uv_top_min.y), Vector2(uv_top_min.x, uv_top_min.y))
	# -Y
	_add_quad(st, v[4], v[5], v[1], v[0], uv_side_min, Vector2(uv_side_max.x, uv_side_min.y), uv_side_max, Vector2(uv_side_min.x, uv_side_max.y))


## Descansabrazos con caída suave hacia el frente y remate biselado
static func _add_armrest(st: SurfaceTool, base_pos: Vector3, aw: float, alen: float, ah: float, uv_top_min: Vector2, uv_top_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2, _is_left: bool) -> void:
	var haw := aw * 0.5
	var hlen := alen * 0.5
	var front_h := ah * 0.90 # Suave caída hacia el frente
	var back_h := ah

	var by := base_pos.y
	var cz := base_pos.z
	var cx := base_pos.x

	# 4 vértices inferiores
	var b_fl := Vector3(cx - haw, by, cz + hlen)
	var b_fr := Vector3(cx + haw, by, cz + hlen)
	var b_bl := Vector3(cx - haw, by, cz - hlen)
	var b_br := Vector3(cx + haw, by, cz - hlen)

	# 4 vértices superiores
	var t_fl := Vector3(cx - haw, by + front_h, cz + hlen)
	var t_fr := Vector3(cx + haw, by + front_h, cz + hlen)
	var t_bl := Vector3(cx - haw, by + back_h,  cz - hlen)
	var t_br := Vector3(cx + haw, by + back_h,  cz - hlen)

	# Frente (+Z)
	_add_quad(st, b_fl, b_fr, t_fr, t_fl, Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# Atrás (-Z)
	_add_quad(st, b_br, b_bl, t_bl, t_br, Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# Lado exterior
	_add_quad(st, b_bl, b_fl, t_fl, t_bl, Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# Lado interior
	_add_quad(st, b_fr, b_br, t_br, t_fr, Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
	# Cara Superior (Acolchada con leve caída frontal)
	_add_quad(st, t_fl, t_fr, t_br, t_bl, Vector2(uv_top_min.x, uv_top_max.y), Vector2(uv_top_max.x, uv_top_max.y), Vector2(uv_top_max.x, uv_top_min.y), Vector2(uv_top_min.x, uv_top_min.y))


## Orejera lateral (Wing) clásica en forma de abanico diagonal hacia adelante
static func _add_wing(st: SurfaceTool, edge_x: float, by: float, ty: float, aw: float, z_back: float, z_front: float, uv_side_min: Vector2, uv_side_max: Vector2, uv_smooth_min: Vector2, uv_smooth_max: Vector2, is_left: bool) -> void:
	var sign_x := -1.0 if is_left else 1.0
	var out_x := edge_x + sign_x * 0.02 # Leve ensanchamiento en la cima
	var in_x := edge_x - sign_x * (aw - 0.02)

	# Vértices de la cuña orejera
	var b_back_out := Vector3(edge_x, by, z_back)
	var b_back_in  := Vector3(in_x, by, z_back)
	var b_front_out := Vector3(edge_x, by, z_front * 0.70)
	var b_front_in  := Vector3(in_x, by, z_front * 0.70)

	var t_back_out := Vector3(out_x, ty, z_back)
	var t_back_in  := Vector3(in_x, ty, z_back)
	var t_front_out := Vector3(out_x, ty * 0.96, z_front)
	var t_front_in  := Vector3(in_x, ty * 0.96, z_front - 0.04)

	if is_left:
		# Cara exterior lateral (-X)
		_add_quad(st, b_back_out, b_front_out, t_front_out, t_back_out, Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
		# Cara interior (+X)
		_add_quad(st, b_front_in, b_back_in, t_back_in, t_front_in, Vector2(uv_smooth_min.x, uv_smooth_max.y), Vector2(uv_smooth_max.x, uv_smooth_max.y), Vector2(uv_smooth_max.x, uv_smooth_min.y), Vector2(uv_smooth_min.x, uv_smooth_min.y))
		# Borde frontal biselado
		_add_quad(st, b_front_out, b_front_in, t_front_in, t_front_out, uv_smooth_min, Vector2(uv_smooth_max.x, uv_smooth_min.y), uv_smooth_max, Vector2(uv_smooth_min.x, uv_smooth_max.y))
		# Borde superior
		_add_quad(st, t_front_out, t_front_in, t_back_in, t_back_out, uv_smooth_min, Vector2(uv_smooth_max.x, uv_smooth_min.y), uv_smooth_max, Vector2(uv_smooth_min.x, uv_smooth_max.y))
	else:
		# Cara exterior lateral (+X)
		_add_quad(st, b_front_out, b_back_out, t_back_out, t_front_out, Vector2(uv_side_min.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_max.y), Vector2(uv_side_max.x, uv_side_min.y), Vector2(uv_side_min.x, uv_side_min.y))
		# Cara interior (-X)
		_add_quad(st, b_back_in, b_front_in, t_front_in, t_back_in, Vector2(uv_smooth_min.x, uv_smooth_max.y), Vector2(uv_smooth_max.x, uv_smooth_max.y), Vector2(uv_smooth_max.x, uv_smooth_min.y), Vector2(uv_smooth_min.x, uv_smooth_min.y))
		# Borde frontal biselado
		_add_quad(st, b_front_in, b_front_out, t_front_out, t_front_in, uv_smooth_min, Vector2(uv_smooth_max.x, uv_smooth_min.y), uv_smooth_max, Vector2(uv_smooth_min.x, uv_smooth_max.y))
		# Borde superior
		_add_quad(st, t_front_in, t_front_out, t_back_out, t_back_in, uv_smooth_min, Vector2(uv_smooth_max.x, uv_smooth_min.y), uv_smooth_max, Vector2(uv_smooth_min.x, uv_smooth_max.y))


## Respaldo alto con capitoné (inclinación suave hacia atrás y leve cresta superior)
static func _add_tufted_backrest(st: SurfaceTool, bw: float, by: float, bh: float, bt: float, bz: float, tilt: float, uv_cap_min: Vector2, uv_cap_max: Vector2, uv_smooth_min: Vector2, uv_smooth_max: Vector2) -> void:
	var hbw := bw * 0.5
	var hbt := bt * 0.5
	var top_y := by + bh
	var crest_extra := 0.035 # Arco sutil en la cresta superior del respaldo

	# Base frontal e inferior
	var b_fl := Vector3(-hbw, by, bz + hbt)
	var b_fr := Vector3( hbw, by, bz + hbt)
	var b_bl := Vector3(-hbw, by, bz - hbt)
	var b_br := Vector3( hbw, by, bz - hbt)

	# Cima frontal e inclinada hacia atrás
	var top_z := bz - tilt
	var t_fl := Vector3(-hbw, top_y, top_z + hbt)
	var t_fr := Vector3( hbw, top_y, top_z + hbt)
	var t_fc := Vector3( 0.0,  top_y + crest_extra, top_z + hbt) # Cresta central

	var t_bl := Vector3(-hbw, top_y, top_z - hbt)
	var t_br := Vector3( hbw, top_y, top_z - hbt)
	var t_bc := Vector3( 0.0,  top_y + crest_extra, top_z - hbt)

	# Cara frontal con CAPITONÉ (Botones romboidales en 2 triángulos superiores para la cresta suave)
	# Cuadrilátero inferior principal
	_add_quad(st, b_fl, b_fr, t_fr, t_fl, Vector2(uv_cap_min.x, uv_cap_max.y), Vector2(uv_cap_max.x, uv_cap_max.y), Vector2(uv_cap_max.x, uv_cap_min.y + 0.03), Vector2(uv_cap_min.x, uv_cap_min.y + 0.03))
	# Cresta triangular superior izquierda
	st.set_uv(Vector2(uv_cap_min.x, uv_cap_min.y + 0.03))
	st.add_vertex(t_fl)
	st.set_uv(Vector2((uv_cap_min.x + uv_cap_max.x) * 0.5, uv_cap_min.y))
	st.add_vertex(t_fc)
	st.set_uv(Vector2(uv_cap_max.x, uv_cap_min.y + 0.03))
	st.add_vertex(t_fr)

	# Cara trasera de cuero liso
	_add_quad(st, b_br, b_bl, t_bl, t_br, Vector2(uv_smooth_min.x, uv_smooth_max.y), Vector2(uv_smooth_max.x, uv_smooth_max.y), Vector2(uv_smooth_max.x, uv_smooth_min.y), Vector2(uv_smooth_min.x, uv_smooth_min.y))
	st.set_uv(Vector2(uv_smooth_max.x, uv_smooth_min.y))
	st.add_vertex(t_br)
	st.set_uv(Vector2((uv_smooth_min.x + uv_smooth_max.x) * 0.5, uv_smooth_min.y))
	st.add_vertex(t_bc)
	st.set_uv(Vector2(uv_smooth_min.x, uv_smooth_min.y))
	st.add_vertex(t_bl)

	# Canto superior (tapa)
	_add_quad(st, t_fl, t_fc, t_bc, t_bl, uv_smooth_min, Vector2(uv_smooth_max.x, uv_smooth_min.y), uv_smooth_max, Vector2(uv_smooth_min.x, uv_smooth_max.y))
	_add_quad(st, t_fc, t_fr, t_br, t_bc, uv_smooth_min, Vector2(uv_smooth_max.x, uv_smooth_min.y), uv_smooth_max, Vector2(uv_smooth_min.x, uv_smooth_max.y))


## Helper para agregar un cuadrilátero con 4 vértices y UVs
static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2) -> void:
	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv1)
	st.add_vertex(v1)
	st.set_uv(uv2)
	st.add_vertex(v2)

	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv2)
	st.add_vertex(v2)
	st.set_uv(uv3)
	st.add_vertex(v3)


## Retorna las cajas de colisión para instanciamiento MultiMesh
static func get_collision_boxes(w: float = 0.86, d: float = 0.84, h: float = 1.02, s_h: float = 0.42) -> Array[Dictionary]:
	var back_h := h - s_h
	return [
		{
			"position": Vector3(0.0, s_h * 0.5, 0.0),
			"size": Vector3(w * 0.92, s_h, d * 0.88)
		},
		{
			"position": Vector3(0.0, s_h + back_h * 0.5, -d * 0.5 + 0.10),
			"size": Vector3(w * 0.94, back_h, 0.18)
		}
	]


## Configura el cuerpo de colisiones estáticas para el jugador
func _setup_collision(w: float, d: float, h: float, s_h: float) -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "ArmchairCollision"
	add_child(_collision_body)

	for b_dict in get_collision_boxes(w, d, h, s_h):
		var c_shape := CollisionShape3D.new()
		var b_shape := BoxShape3D.new()
		b_shape.size = b_dict["size"]
		c_shape.shape = b_shape
		c_shape.position = b_dict["position"]
		_collision_body.add_child(c_shape)
