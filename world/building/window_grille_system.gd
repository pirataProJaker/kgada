class_name WindowGrilleSystem
extends RefCounted

## Sistema Procedural de Protecciones de Herrería para Ventanas (Estilo Mexicano)
## Genera texturas 2D procedurales transparentes adaptadas a las medidas métricas del vano.
##
## Estilos soportados:
## 0: HORIZONTAL_BARS - Barrotes horizontales tradicionales con soleras intermedias y poste central (Foto 1)
## 1: FLOATING_LOOPS  - Marcos rectangulares horizontales flotantes minimalistas (Foto 2)
## 2: GEOMETRIC_GRID  - Retícula geométrica asimétrica desfasada tipo contemporánea (Foto 3)
## 3: VERTICAL_BARS   - Barrotes verticales clásicos coloniales

enum GrilleStyle {
	HORIZONTAL_BARS = 0,
	FLOATING_LOOPS = 1,
	GEOMETRIC_GRID = 2,
	VERTICAL_BARS = 3
}

## Paleta de acabados de esmalte y pintura anticorrosiva de herrería
const FINISH_COLORS: Array[Color] = [
	Color(0.12, 0.12, 0.13, 1.0), # Negro mate / hierro forjado (el más común)
	Color(0.92, 0.93, 0.94, 1.0), # Blanco brillante / anticorrosivo (típico infonavit)
	Color(0.24, 0.16, 0.12, 1.0), # Café chocolate oscuro
	Color(0.28, 0.30, 0.32, 1.0)  # Gris grafito / antracita contemporáneo
]

## Caché de materiales generados para evitar trabajo redundante en GPU
static var _material_cache: Dictionary = {} # hash_key -> StandardMaterial3D
static var _unit_quad: QuadMesh = null


static func get_unit_quad() -> QuadMesh:
	if _unit_quad == null:
		_unit_quad = QuadMesh.new()
		_unit_quad.size = Vector2(1.0, 1.0)
	return _unit_quad


## Genera y construye todas las protecciones de herrería de una casa
static func build_house_grilles(windows: Array, house_seed: int, zone_type: int) -> Node3D:
	if windows.is_empty():
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = house_seed ^ 0x9B8A7C6D

	# 1. Reglas urbanas mexicanas para instalación de protecciones:
	# - Colonia Vieja (0): Muy alta presencia (100% planta baja, 35% planta alta).
	# - Infonavit / Fraccionamiento (1): 100% planta baja, 40% planta alta.
	# - Zona X (2 - Residencial de lujo): Baja presencia (25% solo en accesos, herrería minimalista).
	# - Comercial / OTXO (3): CERO protecciones (ventanales panorámicos de exhibición comercial).
	if zone_type == 3:
		return null

	var has_grilles_at_all := true
	if zone_type == 2:
		# Zona X: muchas casas tienen barda perimetral con cerca electrificada y no ponen herrería
		has_grilles_at_all = rng.randf() < 0.30

	if not has_grilles_at_all:
		return null

	# 2. Selección de Estilo y Acabado uniforme para TODA la casa:
	var style_idx: int = 0
	if zone_type == 2:
		# En Zona X predomina lo minimalista contemporáneo
		style_idx = GrilleStyle.FLOATING_LOOPS if rng.randf() < 0.65 else GrilleStyle.GEOMETRIC_GRID
	elif zone_type == 1:
		# En Infonavit se mezcla horizontal tradicional y minimalista
		var roll := rng.randf()
		if roll < 0.40:
			style_idx = GrilleStyle.HORIZONTAL_BARS
		elif roll < 0.75:
			style_idx = GrilleStyle.FLOATING_LOOPS
		else:
			style_idx = GrilleStyle.GEOMETRIC_GRID
	else:
		# En Colonia Vieja predomina lo tradicional y barrotes
		var roll := rng.randf()
		if roll < 0.55:
			style_idx = GrilleStyle.HORIZONTAL_BARS
		elif roll < 0.80:
			style_idx = GrilleStyle.VERTICAL_BARS
		else:
			style_idx = GrilleStyle.GEOMETRIC_GRID

	# Acabado de color uniforme para toda la vivienda:
	var color_idx := rng.randi() % FINISH_COLORS.size()
	var grille_color: Color = FINISH_COLORS[color_idx]

	# 3. Filtrar ventanas que califiquen para llevar protección:
	var target_windows: Array[Dictionary] = []
	for w in windows:
		var floor_num: int = w.get("floor", 1)
		var place_it := false

		if floor_num == 1:
			# Planta baja: seguridad prioritaria (95% probabilidad)
			place_it = rng.randf() < 0.95
		else:
			# Planta alta: menor probabilidad (25% a 35%)
			place_it = rng.randf() < 0.30

		if place_it:
			target_windows.append(w)

	if target_windows.is_empty():
		return null

	var root_node := Node3D.new()
	root_node.name = "WindowGrilles"

	# 4. Generar quads orientados con su respectivo material procedural adaptado al tamaño
	for w_dict in target_windows:
		var w_pos: Vector3 = w_dict.get("position", Vector3.ZERO)
		var w_size: Vector2 = w_dict.get("size", Vector2(1.5, 1.2))
		var w_norm: Vector3 = w_dict.get("normal", Vector3.FORWARD)

		var mat := _get_or_create_material(style_idx, color_idx, house_seed, w_size.x, w_size.y, grille_color)

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "Grille"
		mesh_inst.mesh = get_unit_quad()
		mesh_inst.material_override = mat

		# Orientación perpendicular hacia la normal de la pared exterior
		var rot_y: float = atan2(w_norm.x, w_norm.z)
		mesh_inst.position = w_pos
		mesh_inst.rotation = Vector3(0.0, rot_y, 0.0)
		mesh_inst.scale = Vector3(w_size.x, w_size.y, 1.0)

		root_node.add_child(mesh_inst)

	return root_node


## Genera una textura 2D transparente de herrería procedural adaptada a las medidas métricas
static func generate_grille_image(style: int, color: Color, p_seed: int, w_m: float, h_m: float) -> Image:
	const RES := 512
	var img := Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # 100% transparente en el fondo

	match style:
		GrilleStyle.HORIZONTAL_BARS:
			_draw_horizontal_bars(img, RES, color, p_seed, w_m, h_m)
		GrilleStyle.FLOATING_LOOPS:
			_draw_floating_loops(img, RES, color, p_seed, w_m, h_m)
		GrilleStyle.GEOMETRIC_GRID:
			_draw_geometric_grid(img, RES, color, p_seed, w_m, h_m)
		GrilleStyle.VERTICAL_BARS:
			_draw_vertical_bars(img, RES, color, p_seed, w_m, h_m)
		_:
			_draw_horizontal_bars(img, RES, color, p_seed, w_m, h_m)

	img.generate_mipmaps()
	return img


# =========================================================================
# ESTILO 0: BARROTES HORIZONTALES TRADICIONALES (Foto 1)
# Bastidor PTR perimetral, poste vertical central si w > 1.2m, soleras gruesas
# y barrotes delgados espaciados cada 11cm.
# =========================================================================
static func _draw_horizontal_bars(img: Image, res: int, color: Color, p_seed: int, w_m: float, h_m: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed ^ 0xABCDE123

	var px_m_x := float(res) / maxf(w_m, 0.3)
	var px_m_y := float(res) / maxf(h_m, 0.3)

	# 1. Bastidor perimetral (PTR de 1.5" = 0.038m)
	var frame_tx := clampi(int(0.038 * px_m_x), 6, res / 8)
	var frame_ty := clampi(int(0.038 * px_m_y), 6, res / 8)

	img.fill_rect(Rect2i(0, 0, res, frame_ty), color) # Superior
	img.fill_rect(Rect2i(0, res - frame_ty, res, frame_ty), color) # Inferior
	img.fill_rect(Rect2i(0, 0, frame_tx, res), color) # Izquierdo
	img.fill_rect(Rect2i(res - frame_tx, 0, frame_tx, res), color) # Derecho

	# 2. Postes verticales de refuerzo (PTR de 1.5" = 0.035m)
	var post_w := clampi(int(0.035 * px_m_x), 5, res / 10)
	if w_m >= 2.2:
		# Dos postes
		var p1 := int(res * 0.33)
		var p2 := int(res * 0.66)
		img.fill_rect(Rect2i(p1 - post_w / 2, 0, post_w, res), color)
		img.fill_rect(Rect2i(p2 - post_w / 2, 0, post_w, res), color)
	elif w_m >= 1.2:
		# Un poste central
		img.fill_rect(Rect2i((res - post_w) / 2, 0, post_w, res), color)

	# 3. Soleras horizontales gruesas intermedias (solera de 1.5" x 1/4" = 0.035m de alto)
	var solera_h := clampi(int(0.035 * px_m_y), 5, res / 12)
	var soleras_y: Array[int] = []
	if h_m >= 1.1:
		var y1 := int(res * 0.33)
		var y2 := int(res * 0.66)
		soleras_y.append(y1)
		soleras_y.append(y2)
		img.fill_rect(Rect2i(frame_tx, y1 - solera_h / 2, res - frame_tx * 2, solera_h), color)
		img.fill_rect(Rect2i(frame_tx, y2 - solera_h / 2, res - frame_tx * 2, solera_h), color)
	else:
		var ym := int(res * 0.50)
		soleras_y.append(ym)
		img.fill_rect(Rect2i(frame_tx, ym - solera_h / 2, res - frame_tx * 2, solera_h), color)

	# 4. Barrotes horizontales delgados (redondo de 1/2" = 0.012m)
	var thin_h := clampi(int(0.012 * px_m_y), 2, res / 24)
	# Separación de seguridad estándar en México: 11cm (0.11m)
	var avail_h := h_m - 0.08
	var num_bars := maxi(2, int(round(avail_h / 0.11)))
	var step_y := float(res - frame_ty * 2) / float(num_bars + 1)

	for i in range(1, num_bars + 1):
		var y := int(frame_ty + i * step_y)
		var collides_solera := false
		for sy in soleras_y:
			if abs(y - sy) < (solera_h / 2 + thin_h + 3):
				collides_solera = true
				break
		if not collides_solera:
			img.fill_rect(Rect2i(frame_tx, y - thin_h / 2, res - frame_tx * 2, thin_h), color)


# =========================================================================
# ESTILO 1: MARCOS HORIZONTALES FLOTANTES / MINIMALISTA (Foto 2)
# Franjas horizontales con rectángulos flotantes y conectores de solera
# =========================================================================
static func _draw_floating_loops(img: Image, res: int, color: Color, _p_seed: int, w_m: float, h_m: float) -> void:
	var px_m_x := float(res) / maxf(w_m, 0.3)
	var px_m_y := float(res) / maxf(h_m, 0.3)

	# Bastidor perimetral exterior
	var frame_tx := clampi(int(0.040 * px_m_x), 6, res / 8)
	var frame_ty := clampi(int(0.040 * px_m_y), 6, res / 8)

	img.fill_rect(Rect2i(0, 0, res, frame_ty), color)
	img.fill_rect(Rect2i(0, res - frame_ty, res, frame_ty), color)
	img.fill_rect(Rect2i(0, 0, frame_tx, res), color)
	img.fill_rect(Rect2i(res - frame_tx, 0, frame_tx, res), color)

	# Marcos rectangulares flotantes
	# Cada lazo mide ~0.16m de alto, con separación de ~0.12m
	var num_loops := maxi(1, int(round((h_m - 0.10) / 0.28)))
	var loop_border_x := clampi(int(0.030 * px_m_x), 4, res / 12)
	var loop_border_y := clampi(int(0.030 * px_m_y), 4, res / 12)
	var loop_h := clampi(int(0.16 * px_m_y), loop_border_y * 2 + 4, res / 2)
	var margin_x := clampi(int(0.10 * px_m_x), frame_tx + 4, res / 3)

	var step_y := float(res - frame_ty * 2) / float(num_loops + 1)
	for i in range(1, num_loops + 1):
		var cy := int(frame_ty + i * step_y)
		var top_y := cy - loop_h / 2
		var w_loop := res - margin_x * 2

		# Marco rectangular hueco
		img.fill_rect(Rect2i(margin_x, top_y, w_loop, loop_border_y), color) # Borde superior
		img.fill_rect(Rect2i(margin_x, top_y + loop_h - loop_border_y, w_loop, loop_border_y), color) # Borde inferior
		img.fill_rect(Rect2i(margin_x, top_y, loop_border_x, loop_h), color) # Borde izquierdo
		img.fill_rect(Rect2i(margin_x + w_loop - loop_border_x, top_y, loop_border_x, loop_h), color) # Borde derecho

		# Conectores laterales de solera al bastidor exterior
		var conn_h := clampi(int(0.030 * px_m_y), 4, res / 16)
		img.fill_rect(Rect2i(frame_tx, cy - conn_h / 2, margin_x - frame_tx, conn_h), color)
		img.fill_rect(Rect2i(margin_x + w_loop, cy - conn_h / 2, margin_x - frame_tx, conn_h), color)


# =========================================================================
# ESTILO 2: RETÍCULA GEOMÉTRICA ASIMÉTRICA (Foto 3)
# Retícula abstracta con líneas horizontales pasantes y bloques verticales desfasados
# =========================================================================
static func _draw_geometric_grid(img: Image, res: int, color: Color, p_seed: int, w_m: float, h_m: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed ^ 0x33445566

	var px_m_x := float(res) / maxf(w_m, 0.3)
	var px_m_y := float(res) / maxf(h_m, 0.3)

	# Bastidor exterior
	var frame_tx := clampi(int(0.040 * px_m_x), 6, res / 8)
	var frame_ty := clampi(int(0.040 * px_m_y), 6, res / 8)

	img.fill_rect(Rect2i(0, 0, res, frame_ty), color)
	img.fill_rect(Rect2i(0, res - frame_ty, res, frame_ty), color)
	img.fill_rect(Rect2i(0, 0, frame_tx, res), color)
	img.fill_rect(Rect2i(res - frame_tx, 0, frame_tx, res), color)

	# Niveles horizontales pasantes (espaciados cada ~0.24m)
	var num_horiz := maxi(2, int(round(h_m / 0.24)) - 1)
	var horiz_t := clampi(int(0.028 * px_m_y), 4, res / 16)
	var step_y := float(res - frame_ty * 2) / float(num_horiz + 1)
	var y_levels: Array[int] = []

	for i in range(1, num_horiz + 1):
		var y := int(frame_ty + i * step_y)
		y_levels.append(y)
		img.fill_rect(Rect2i(frame_tx, y - horiz_t / 2, res - frame_tx * 2, horiz_t), color)

	# Postes verticales desfasados entre niveles horizontales
	var vert_t := clampi(int(0.028 * px_m_x), 4, res / 16)
	var all_y: Array[int] = [frame_ty]
	all_y.append_array(y_levels)
	all_y.append(res - frame_ty)

	# Candidatos de columnas verticales (cada ~0.35m)
	var num_cols := maxi(2, int(round(w_m / 0.35)))
	var col_step := float(res - frame_tx * 2) / float(num_cols + 1)
	var col_x_candidates: Array[int] = []
	for c in range(1, num_cols + 1):
		col_x_candidates.append(int(frame_tx + c * col_step))

	for i in range(all_y.size() - 1):
		var y_top: int = all_y[i]
		var y_bot: int = all_y[i + 1]
		var seg_h: int = y_bot - y_top

		for cx in col_x_candidates:
			if rng.randf() < 0.48:
				img.fill_rect(Rect2i(cx - vert_t / 2, y_top, vert_t, seg_h), color)


# =========================================================================
# ESTILO 3: BARROTES VERTICALES CLÁSICOS COLONIALES
# Bastidor perimetral, soleras horizontales pasantes y barrotes verticales cada 11cm
# =========================================================================
static func _draw_vertical_bars(img: Image, res: int, color: Color, _p_seed: int, w_m: float, h_m: float) -> void:
	var px_m_x := float(res) / maxf(w_m, 0.3)
	var px_m_y := float(res) / maxf(h_m, 0.3)

	var frame_tx := clampi(int(0.038 * px_m_x), 6, res / 8)
	var frame_ty := clampi(int(0.038 * px_m_y), 6, res / 8)

	# Bastidor exterior
	img.fill_rect(Rect2i(0, 0, res, frame_ty), color)
	img.fill_rect(Rect2i(0, res - frame_ty, res, frame_ty), color)
	img.fill_rect(Rect2i(0, 0, frame_tx, res), color)
	img.fill_rect(Rect2i(res - frame_tx, 0, frame_tx, res), color)

	# Soleras horizontales superior e inferior
	var solera_t := clampi(int(0.025 * px_m_y), 4, res / 16)
	var y_top_solera := int(res * 0.18)
	var y_bot_solera := int(res * 0.82)
	img.fill_rect(Rect2i(frame_tx, y_top_solera, res - frame_tx * 2, solera_t), color)
	img.fill_rect(Rect2i(frame_tx, y_bot_solera, res - frame_tx * 2, solera_t), color)

	# Barrotes verticales cada 11cm (0.11m)
	var avail_w := w_m - 0.08
	var num_bars := maxi(2, int(round(avail_w / 0.11)))
	var step_x := float(res - frame_tx * 2) / float(num_bars + 1)
	var bar_w := clampi(int(0.014 * px_m_x), 3, res / 20)

	for i in range(1, num_bars + 1):
		var x := int(frame_tx + i * step_x)
		img.fill_rect(Rect2i(x - bar_w / 2, frame_ty, bar_w, res - frame_ty * 2), color)


static func _get_or_create_material(style: int, color_idx: int, p_seed: int, w_m: float, h_m: float, grille_color: Color) -> StandardMaterial3D:
	var qw := snappedf(w_m, 0.1)
	var qh := snappedf(h_m, 0.1)
	var cache_key := "%d_%d_%d_%.1f_%.1f" % [style, color_idx, p_seed % 100, qw, qh]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]

	var grille_img := generate_grille_image(style, grille_color, p_seed, qw, qh)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.50
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var tex := ImageTexture.create_from_image(grille_img)
	mat.albedo_texture = tex

	_material_cache[cache_key] = mat
	return mat
