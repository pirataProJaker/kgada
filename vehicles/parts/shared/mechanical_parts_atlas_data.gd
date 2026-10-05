class_name MechanicalPartsAtlasData
extends RefCounted

## Coordenadas UV exactas y generador procedural para piezas mecánicas PSX (1536x1024)
## Soporta Batería LTH 12V, Radiador y Motores Inline-4 y Inline-6.

const ATLAS_SIZE := Vector2(1536.0, 1024.0)
const TEXTURE_PATH := "res://vehicles/parts/shared/mechanical_parts_atlas.png"

# Helper para normalizar píxeles a UV (0..1)
static func _rect(px_x: float, px_y: float, px_w: float, px_h: float) -> Rect2:
	return Rect2(px_x / ATLAS_SIZE.x, px_y / ATLAS_SIZE.y, px_w / ATLAS_SIZE.x, px_h / ATLAS_SIZE.y)

# =========================================================================
# RECTÁNGULOS UV SEMÁNTICOS (Píxeles calibrados sobre el atlas)
# =========================================================================

# 1. BATERÍA LTH 12V
static var RECT_BATTERY_TOP: Rect2:
	get: return _rect(23.0, 30.0, 460.0, 170.0)

static var RECT_BATTERY_FRONT: Rect2:
	get: return _rect(22.0, 190.0, 478.0, 209.0)

static var RECT_BATTERY_SIDE: Rect2:
	get: return _rect(500.0, 190.0, 250.0, 202.0)

static var RECT_BATTERY_BOTTOM: Rect2:
	get: return _rect(23.0, 390.0, 468.0, 109.0)

# 2. RADIADOR
static var RECT_RADIATOR_FRONT: Rect2:
	get: return _rect(871.0, 30.0, 494.0, 381.0)

static var RECT_RADIATOR_SIDE_L: Rect2:
	get: return _rect(794.0, 65.0, 68.0, 354.0)

static var RECT_RADIATOR_SIDE_R: Rect2:
	get: return _rect(1408.0, 50.0, 92.0, 369.0)

static var RECT_RADIATOR_BOTTOM: Rect2:
	get: return _rect(880.0, 410.0, 494.0, 88.0)

# 3. MOTOR INLINE-4 (DOHC 16V)
static var RECT_ENGINE_I4_TOP: Rect2:
	get: return _rect(90.0, 546.0, 429.0, 113.0)

static var RECT_ENGINE_I4_SIDE_BLOCK: Rect2:
	get: return _rect(96.0, 665.0, 313.0, 204.0)

static var RECT_ENGINE_I4_SIDE_EXHAUST: Rect2:
	get: return _rect(410.0, 660.0, 189.0, 209.0)

static var RECT_ENGINE_I4_FRONT_PULLEYS: Rect2:
	get: return _rect(600.0, 571.0, 138.0, 298.0)

static var RECT_ENGINE_I4_OIL_PAN: Rect2:
	get: return _rect(90.0, 870.0, 329.0, 119.0)

# 4. MOTOR INLINE-6 (DOHC 24V)
static var RECT_ENGINE_I6_TOP: Rect2:
	get: return _rect(860.0, 530.0, 497.0, 129.0)

static var RECT_ENGINE_I6_SIDE_BLOCK: Rect2:
	get: return _rect(860.0, 660.0, 399.0, 209.0)

static var RECT_ENGINE_I6_FRONT_PULLEYS: Rect2:
	get: return _rect(1270.0, 660.0, 138.0, 229.0)

static var RECT_ENGINE_I6_OIL_PAN: Rect2:
	get: return _rect(860.0, 870.0, 399.0, 119.0)


# =========================================================================
# MATERIAL PSX COMPARTIDO (Filtro Nearest + Sin Especular)
# =========================================================================
static var _cached_texture: Texture2D = null
static var _cached_material: StandardMaterial3D = null

static func get_atlas_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture
	if ResourceLoader.exists(TEXTURE_PATH):
		_cached_texture = load(TEXTURE_PATH)
		if _cached_texture != null:
			return _cached_texture
	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	if FileAccess.file_exists(gpath):
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			_cached_texture = ImageTexture.create_from_image(img)
			return _cached_texture
	return _cached_texture


static func get_mechanical_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = get_atlas_texture()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Evita caras transparentes / culling inverso
	mat.roughness = 0.65
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cached_material = mat
	return mat


# =========================================================================
# CONSTRUCTORES GEOMÉTRICOS MATEMÁTICOS (SurfaceTool)
# =========================================================================

static func add_quad_direct(
	st: SurfaceTool,
	v0: Vector3, uv0: Vector2,
	v1: Vector3, uv1: Vector2,
	v2: Vector3, uv2: Vector2,
	v3: Vector3, uv3: Vector2,
	normal: Vector3,
	color: Color = Color.WHITE
) -> void:
	st.set_color(color); st.set_normal(normal); st.set_uv(uv0); st.add_vertex(v0)
	st.set_color(color); st.set_normal(normal); st.set_uv(uv1); st.add_vertex(v1)
	st.set_color(color); st.set_normal(normal); st.set_uv(uv2); st.add_vertex(v2)

	st.set_color(color); st.set_normal(normal); st.set_uv(uv0); st.add_vertex(v0)
	st.set_color(color); st.set_normal(normal); st.set_uv(uv2); st.add_vertex(v2)
	st.set_color(color); st.set_normal(normal); st.set_uv(uv3); st.add_vertex(v3)


static func add_box(
	st: SurfaceTool,
	center: Vector3, size: Vector3,
	uv_top: Rect2, uv_front: Rect2, uv_back: Rect2,
	uv_left: Rect2, uv_right: Rect2, uv_bottom: Rect2,
	color: Color = Color.WHITE
) -> void:
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var hd := size.z * 0.5

	var p000 := center + Vector3(-hw, -hh, -hd) # Front-bottom-left (-X, -Y, -Z)
	var p100 := center + Vector3( hw, -hh, -hd) # Front-bottom-right (+X, -Y, -Z)
	var p110 := center + Vector3( hw,  hh, -hd) # Front-top-right (+X, +Y, -Z)
	var p010 := center + Vector3(-hw,  hh, -hd) # Front-top-left (-X, +Y, -Z)

	var p001 := center + Vector3(-hw, -hh,  hd) # Back-bottom-left (-X, -Y, +Z)
	var p101 := center + Vector3( hw, -hh,  hd) # Back-bottom-right (+X, -Y, +Z)
	var p111 := center + Vector3( hw,  hh,  hd) # Back-top-right (+X, +Y, +Z)
	var p011 := center + Vector3(-hw,  hh,  hd) # Back-top-left (-X, +Y, +Z)

	# 1. Frente (-Z): viendo desde -Z hacia +Z, +X queda a la izquierda de la pantalla
	# Vértices CCW con normal hacia afuera (-Z) y texto LTH sin espejo
	add_quad_direct(
		st,
		p100, Vector2(uv_front.position.x, uv_front.end.y),
		p000, Vector2(uv_front.end.x, uv_front.end.y),
		p010, Vector2(uv_front.end.x, uv_front.position.y),
		p110, Vector2(uv_front.position.x, uv_front.position.y),
		Vector3.FORWARD, color
	)

	# 2. Trasera (+Z): viendo desde +Z hacia -Z, -X queda a la izquierda de la pantalla
	# Vértices CCW con normal hacia afuera (+Z)
	add_quad_direct(
		st,
		p001, Vector2(uv_back.position.x, uv_back.end.y),
		p101, Vector2(uv_back.end.x, uv_back.end.y),
		p111, Vector2(uv_back.end.x, uv_back.position.y),
		p011, Vector2(uv_back.position.x, uv_back.position.y),
		Vector3.BACK, color
	)

	# 3. Izquierda (-X): viendo desde -X hacia +X, +Z queda a la izquierda de la pantalla
	# Vértices CCW con normal hacia afuera (-X)
	add_quad_direct(
		st,
		p001, Vector2(uv_left.position.x, uv_left.end.y),
		p000, Vector2(uv_left.end.x, uv_left.end.y),
		p010, Vector2(uv_left.end.x, uv_left.position.y),
		p011, Vector2(uv_left.position.x, uv_left.position.y),
		Vector3.LEFT, color
	)

	# 4. Derecha (+X): viendo desde +X hacia -X, -Z queda a la izquierda de la pantalla
	# Vértices CCW con normal hacia afuera (+X)
	add_quad_direct(
		st,
		p100, Vector2(uv_right.position.x, uv_right.end.y),
		p101, Vector2(uv_right.end.x, uv_right.end.y),
		p111, Vector2(uv_right.end.x, uv_right.position.y),
		p110, Vector2(uv_right.position.x, uv_right.position.y),
		Vector3.RIGHT, color
	)

	# 5. Arriba (+Y): viendo desde +Y hacia -Y con frente a -Z
	# Vértices CCW con normal hacia afuera (+Y)
	add_quad_direct(
		st,
		p011, Vector2(uv_top.position.x, uv_top.end.y),
		p111, Vector2(uv_top.end.x, uv_top.end.y),
		p110, Vector2(uv_top.end.x, uv_top.position.y),
		p010, Vector2(uv_top.position.x, uv_top.position.y),
		Vector3.UP, color
	)

	# 6. Abajo (-Y): viendo desde -Y hacia +Y con frente a -Z
	# Vértices CCW con normal hacia afuera (-Y)
	add_quad_direct(
		st,
		p101, Vector2(uv_bottom.position.x, uv_bottom.end.y),
		p001, Vector2(uv_bottom.end.x, uv_bottom.end.y),
		p000, Vector2(uv_bottom.end.x, uv_bottom.position.y),
		p100, Vector2(uv_bottom.position.x, uv_bottom.position.y),
		Vector3.DOWN, color
	)





# =========================================================================
# GENERADORES DE MALLAS PARA GODOT
# =========================================================================

## Genera la malla 3D de la Batería LTH 12V
static func create_battery_mesh(w: float = 0.24, h: float = 0.18, d: float = 0.16) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Caja principal
	add_box(
		st,
		Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d),
		RECT_BATTERY_TOP,
		RECT_BATTERY_FRONT, # Logotipo LTH al frente
		RECT_BATTERY_SIDE,  # Lateral plástico
		RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE,
		RECT_BATTERY_BOTTOM
	)

	# Bornes 3D en la parte superior
	var post_h := 0.025
	var post_r := 0.015
	# Borne positivo (Rojo)
	add_box(
		st,
		Vector3(-w * 0.32, h + post_h * 0.5, -d * 0.15),
		Vector3(post_r * 2.0, post_h, post_r * 2.0),
		RECT_BATTERY_TOP, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(1.0, 0.2, 0.2)
	)
	# Borne negativo (Metal oscuro)
	add_box(
		st,
		Vector3(w * 0.32, h + post_h * 0.5, -d * 0.15),
		Vector3(post_r * 2.0, post_h, post_r * 2.0),
		RECT_BATTERY_TOP, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.5, 0.5, 0.55)
	)

	var m := st.commit()
	m.surface_set_material(0, get_mechanical_material())
	return m


## Genera la malla 3D del Radiador
static func create_radiator_mesh(w: float = 0.48, h: float = 0.34, d: float = 0.06) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Panel central de enfriamiento y tanques
	add_box(
		st,
		Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d),
		RECT_RADIATOR_BOTTOM, # Tanque superior
		RECT_RADIATOR_FRONT,  # Frente (Aletas + tapón amarillo)
		RECT_RADIATOR_FRONT,  # Espalda
		RECT_RADIATOR_SIDE_L, # Lateral izquierdo
		RECT_RADIATOR_SIDE_R, # Lateral derecho
		RECT_RADIATOR_BOTTOM  # Tanque inferior
	)

	var m := st.commit()
	m.surface_set_material(0, get_mechanical_material())
	return m


## Genera la malla 3D del Motor Inline-4 (DOHC 16V) con accesorios y relleno completo del vano motor
static func create_engine_i4_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Bloque motor y cárter
	var block_w := 0.26
	var block_h := 0.24
	var block_l := 0.38
	add_box(
		st,
		Vector3(0.0, block_h * 0.5, 0.0), Vector3(block_w, block_h, block_l),
		RECT_ENGINE_I4_SIDE_BLOCK,   # Superior interna
		RECT_ENGINE_I4_FRONT_PULLEYS,# Frente: Correa y poleas
		RECT_ENGINE_I4_SIDE_BLOCK,   # Trasera hacia transmisión
		RECT_ENGINE_I4_SIDE_BLOCK,   # Lado izquierdo (bloque de hierro)
		RECT_ENGINE_I4_SIDE_EXHAUST, # Lado derecho (múltiple de escape + filtro azul)
		RECT_ENGINE_I4_OIL_PAN       # Cárter inferior
	)

	# 2. Tapa de Culata (DOHC - 16V)
	var head_w := 0.22
	var head_h := 0.08
	var head_l := 0.36
	var head_center_y := block_h + head_h * 0.5
	add_box(
		st,
		Vector3(0.0, head_center_y, 0.0), Vector3(head_w, head_h, head_l),
		RECT_ENGINE_I4_TOP,          # Cara superior: DOHC 16V + OIL
		RECT_ENGINE_I4_SIDE_BLOCK,   # Frente tapa
		RECT_ENGINE_I4_SIDE_BLOCK,   # Trasera tapa
		RECT_ENGINE_I4_SIDE_BLOCK,   # Lados
		RECT_ENGINE_I4_SIDE_BLOCK,
		RECT_ENGINE_I4_SIDE_BLOCK
	)

	# 3. Múltiple de Admisión (Intake Runners - Lado Izquierdo)
	add_box(
		st,
		Vector3(-0.16, head_center_y - 0.02, 0.0), Vector3(0.10, 0.09, 0.30),
		RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK,
		RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK,
		Color(0.88, 0.90, 0.95) # Aluminio fundido brillante
	)

	# 4. Cables de Bujías Retro 80s (Rojo de alto rendimiento sobre la tapa)
	var wire_colors := [
		Color(0.95, 0.18, 0.15), Color(0.95, 0.22, 0.18),
		Color(0.95, 0.18, 0.15), Color(0.95, 0.22, 0.18)
	]
	var wire_z_positions := [-0.12, -0.04, 0.04, 0.12]
	for i in range(4):
		# Cable que conecta el centro de la tapa con el distribuidor
		add_box(
			st,
			Vector3(-0.06, head_center_y + head_h * 0.5 + 0.015, wire_z_positions[i]),
			Vector3(0.08, 0.018, 0.018),
			RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
			RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
			wire_colors[i]
		)

	# 5. Varilla de Medición de Aceite (Dipstick amarillo brillante)
	add_box(
		st,
		Vector3(0.15, head_center_y + 0.08, 0.10), Vector3(0.025, 0.06, 0.025),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		Color(1.0, 0.85, 0.05) # Anilla amarilla de extracción
	)

	# 6. Caja del Filtro de Aire (Air Filter Box - Lado Izquierdo)
	# Texturizado con plástico estriado y clips metálicos plateados
	var airbox_pos := Vector3(-0.40, 0.16, -0.06)
	var airbox_size := Vector3(0.24, 0.16, 0.22)
	add_box(
		st,
		airbox_pos, airbox_size,
		RECT_BATTERY_TOP, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.85, 0.85, 0.88) # Plástico estructurado claro
	)
	# 2 Abrazaderas metálicas en la caja del filtro
	add_box(
		st,
		airbox_pos + Vector3(airbox_size.x * 0.5 + 0.005, 0.0, -0.05), Vector3(0.015, 0.05, 0.025),
		RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM,
		RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM,
		Color(0.95, 0.95, 0.98) # Clip metálico brillante
	)
	add_box(
		st,
		airbox_pos + Vector3(airbox_size.x * 0.5 + 0.005, 0.0, 0.05), Vector3(0.015, 0.05, 0.025),
		RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM,
		RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM, RECT_RADIATOR_BOTTOM,
		Color(0.95, 0.95, 0.98) # Clip metálico brillante
	)

	# 7. Manguera / Ducto de Admisión Flexible Corrugada
	add_box(
		st,
		Vector3(-0.28, 0.18, -0.04), Vector3(0.18, 0.08, 0.10),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.55, 0.55, 0.58) # Manguera corrugada con relieve
	)

	# 8. Snorkel frontal de toma de aire frío
	add_box(
		st,
		Vector3(-0.40, 0.18, -0.22), Vector3(0.10, 0.07, 0.12),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.65, 0.65, 0.70)
	)

	# 9. Depósito de Líquido Limpiaparabrisas (Blanco translúcido con tapón azul)
	var washer_pos := Vector3(-0.43, 0.10, -0.34)
	var washer_size := Vector3(0.16, 0.20, 0.14)
	add_box(
		st,
		washer_pos, washer_size,
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.95, 0.97, 1.0) # Blanco translúcido limpio
	)
	# Tapón azul rey del limpiaparabrisas
	add_box(
		st,
		washer_pos + Vector3(0.0, washer_size.y * 0.5 + 0.015, 0.0), Vector3(0.05, 0.03, 0.05),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		Color(0.12, 0.52, 0.98) # Azul vivo
	)

	# 10. Servofreno y Cilindro Maestro (Pared de fuego trasera)
	var brake_pos := Vector3(-0.35, 0.24, 0.24)
	add_box(
		st,
		brake_pos, Vector3(0.18, 0.18, 0.12),
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.35, 0.35, 0.38) # Tambor satinado
	)
	add_box(
		st,
		brake_pos + Vector3(0.0, 0.02, -0.10), Vector3(0.08, 0.08, 0.10),
		RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK,
		RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK, RECT_ENGINE_I4_SIDE_BLOCK,
		Color(0.88, 0.90, 0.95) # Cilindro de aluminio
	)
	# Depósito de líquido de frenos con plástico ámbar
	add_box(
		st,
		brake_pos + Vector3(0.0, 0.08, -0.10), Vector3(0.07, 0.05, 0.08),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(1.0, 0.85, 0.35) # Ámbar característico
	)

	# 11. Caja de Fusibles y Relés (Lado derecho, con etiqueta amarilla)
	var fusebox_pos := Vector3(0.44, 0.10, 0.06)
	add_box(
		st,
		fusebox_pos, Vector3(0.16, 0.12, 0.16),
		RECT_BATTERY_TOP, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.50, 0.50, 0.55)
	)
	# Etiqueta de diagrama de fusibles en la tapa
	add_box(
		st,
		fusebox_pos + Vector3(0.0, 0.062, 0.0), Vector3(0.12, 0.005, 0.10),
		RECT_BATTERY_TOP, RECT_BATTERY_TOP, RECT_BATTERY_TOP,
		RECT_BATTERY_TOP, RECT_BATTERY_TOP, RECT_BATTERY_TOP,
		Color(1.0, 0.92, 0.60) # Etiqueta amarilla técnica
	)

	# 12. Depósito de Expansión / Anticongelante (Lado derecho, pegado al radiador)
	var coolant_pos := Vector3(0.40, 0.12, -0.34)
	add_box(
		st,
		coolant_pos, Vector3(0.12, 0.18, 0.12),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.88, 0.98, 0.85) # Translúcido con líquido verde
	)
	add_box(
		st,
		coolant_pos + Vector3(0.0, 0.10, 0.0), Vector3(0.045, 0.025, 0.045),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		Color(0.20, 0.20, 0.20)
	)


	var m := st.commit()
	m.surface_set_material(0, get_mechanical_material())
	return m


## Genera la malla 3D del Motor Inline-6 (DOHC 24V) con accesorios y relleno completo
static func create_engine_i6_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Bloque motor largo 6 cilindros
	var block_w := 0.26
	var block_h := 0.24
	var block_l := 0.52
	add_box(
		st,
		Vector3(0.0, block_h * 0.5, 0.0), Vector3(block_w, block_h, block_l),
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_FRONT_PULLEYS, # Frente: Correa y poleas
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_OIL_PAN
	)

	# 2. Tapa de Culata larga (DOHC - 24V)
	var head_w := 0.22
	var head_h := 0.08
	var head_l := 0.50
	var head_center_y := block_h + head_h * 0.5
	add_box(
		st,
		Vector3(0.0, head_center_y, 0.0), Vector3(head_w, head_h, head_l),
		RECT_ENGINE_I6_TOP,           # Cara superior: DOHC 24V + OIL
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_SIDE_BLOCK,
		RECT_ENGINE_I6_SIDE_BLOCK
	)

	# 3. Admisión y Caja de Filtro para 6 cilindros
	var airbox_pos := Vector3(-0.40, 0.16, -0.06)
	add_box(
		st,
		airbox_pos, Vector3(0.24, 0.16, 0.22),
		RECT_BATTERY_TOP, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.25, 0.25, 0.28)
	)
	add_box(
		st,
		Vector3(-0.28, 0.18, -0.04), Vector3(0.18, 0.08, 0.10),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.18, 0.18, 0.20)
	)

	# 4. Depósito Limpiaparabrisas
	var washer_pos := Vector3(-0.43, 0.10, -0.34)
	add_box(
		st,
		washer_pos, Vector3(0.16, 0.20, 0.14),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.88, 0.92, 0.96)
	)
	add_box(
		st,
		washer_pos + Vector3(0.0, 0.115, 0.0), Vector3(0.05, 0.03, 0.05),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM, RECT_BATTERY_BOTTOM,
		Color(0.15, 0.45, 0.95)
	)

	# 5. Servofreno
	var brake_pos := Vector3(-0.35, 0.24, 0.26)
	add_box(
		st,
		brake_pos, Vector3(0.18, 0.18, 0.12),
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.12, 0.12, 0.14)
	)

	# 6. Caja de Fusibles
	var fusebox_pos := Vector3(0.44, 0.10, 0.06)
	add_box(
		st,
		fusebox_pos, Vector3(0.16, 0.12, 0.16),
		RECT_BATTERY_TOP, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.18, 0.18, 0.20)
	)

	# 7. Depósito de Expansión
	var coolant_pos := Vector3(0.40, 0.12, -0.34)
	add_box(
		st,
		coolant_pos, Vector3(0.12, 0.18, 0.12),
		RECT_BATTERY_BOTTOM, RECT_BATTERY_SIDE, RECT_BATTERY_SIDE,
		RECT_BATTERY_SIDE, RECT_BATTERY_SIDE, RECT_BATTERY_BOTTOM,
		Color(0.90, 0.95, 0.85)
	)

	var m := st.commit()
	m.surface_set_material(0, get_mechanical_material())
	return m

