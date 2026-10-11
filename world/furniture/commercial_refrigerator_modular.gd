class_name CommercialRefrigeratorModular
extends Node3D

## Vitrina Refrigerada Comercial Modular para Bebidas y Lácteos (Play Sector X)
## - Modelos basados en vitrinas comerciales reales (1 puerta de ~1x1m y 2 puertas de ~2x1m).
## - Marquesina iluminada superior (Header Lightbox con backlight).
## - Puertas de cristal templado abatibles con bisagras y tiradores verticales.
## - Rejilla inferior de compresor con display digital de temperatura (-2.5°C).
## - 5 Repisas internas de alambre con tecnología de Planograma (carriles de bebidas en profundidad Z).
## - GPU Instancing y Atlas Inteligente:
##   * Mapeado a res://assets/textures/furniture/commercial_cooler.png
##   * get_shared_body_mesh(): Retorna la malla del refrigerador para MultiMeshInstance3D.
##   * Renderiza decenas de vitrinas y miles de bebidas en GPU en solo 3-4 Draw Calls.

const TEXTURE_PATH: String = "res://assets/textures/furniture/commercial_cooler.png"
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")

enum RefrigeratorType {
	SINGLE_DOOR = 0, ## Vitrina de 1 puerta (aprox 1.0m frente x 0.90m fondo x 2.05m alto)
	DOUBLE_DOOR = 1  ## Vitrina de 2 puertas (aprox 1.80m a 2.0m frente x 0.90m fondo x 2.05m alto)
}

enum FinishColor {
	WHITE_HOSPITALITY = 0, ## Blanco comercial esmaltado (estilo hostelero)
	BLACK_MODERN = 1       ## Negro antracita mate (estilo boutique/refrescos)
}

@export_group("Tipo y Acabado")
@export var refrigerator_type: RefrigeratorType = RefrigeratorType.DOUBLE_DOOR:
	set(val):
		refrigerator_type = val
		_apply_type_defaults()
		if is_inside_tree():
			_build_refrigerator()

@export var finish_color: FinishColor = FinishColor.WHITE_HOSPITALITY:
	set(val):
		finish_color = val
		if is_inside_tree():
			_build_refrigerator()

@export_group("Dimensiones")
@export var width: float = 1.80           ## Ancho total frontal (1.0m en single, 1.8m en double)
@export var depth: float = 0.90           ## Fondo total (90cm)
@export var height: float = 2.05          ## Altura total (2.05m)
@export var shelf_levels_count: int = 5   ## Cantidad de repisas de alambre
@export var enable_collision: bool = true ## Colisión física sólida StaticBody3D

@export_group("Apertura de Puertas")
@export_range(0.0, 1.0) var left_door_open_ratio: float = 0.0:
	set(val):
		left_door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angles()

@export_range(0.0, 1.0) var right_door_open_ratio: float = 0.0:
	set(val):
		right_door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angles()

@export_group("Stock de Mercancía")
@export var auto_stock: bool = true       ## Llena las repisas automáticamente con botellas y latas
@export var stock_seed: int = 0           ## Semilla para variación de bebidas

const MAX_DOOR_ANGLE: float = deg_to_rad(105.0)

# Nodos internos de la instancia individual
var _body_mesh_instance: MeshInstance3D = null
var _left_door_pivot: Node3D = null
var _left_door_mesh: MeshInstance3D = null
var _right_door_pivot: Node3D = null
var _right_door_mesh: MeshInstance3D = null
var _collision_body: StaticBody3D = null
var _stock_container: Node3D = null

# Caché estático de mallas compartidas y materiales
static var _cached_body_meshes: Dictionary = {} # "type_color" -> ArrayMesh
static var _cached_door_mesh_single: ArrayMesh = null
static var _cached_door_mesh_double: ArrayMesh = null
static var _cached_cooler_material: StandardMaterial3D = null
static var _cached_glass_material: StandardMaterial3D = null


func _init() -> void:
	_apply_type_defaults()


func _ready() -> void:
	_build_refrigerator()


func _apply_type_defaults() -> void:
	if refrigerator_type == RefrigeratorType.SINGLE_DOOR:
		width = 1.00
		depth = 0.88
		height = 2.05
	else:
		width = 1.80
		depth = 0.88
		height = 2.05


# =========================================================================
# CONSTRUCCIÓN VISUAL Y NODOS STANDALONE
# =========================================================================

func _build_refrigerator() -> void:
	for child in get_children():
		child.queue_free()
	_body_mesh_instance = null
	_left_door_pivot = null
	_left_door_mesh = null
	_right_door_pivot = null
	_right_door_mesh = null
	_collision_body = null
	_stock_container = null

	var mat_body := get_cooler_material(finish_color)
	var mat_glass := get_glass_material()

	# 1. Cuerpo Principal (Gabinete, Cavidad interior, Marquesina superior, Rejilla compresor y Repisas)
	var body_mesh := get_shared_body_mesh(refrigerator_type, finish_color, width, depth, height, shelf_levels_count)
	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "CoolerBodyMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat_body
	add_child(_body_mesh_instance)

	# 2. Puertas de Cristal Templado con Marcos de Aluminio
	var kick_h := 0.32
	var canopy_h := 0.28
	var door_h := height - kick_h - canopy_h
	var door_y := kick_h
	var front_z := depth * 0.5

	if refrigerator_type == RefrigeratorType.SINGLE_DOOR:
		var single_door_w := width - 0.08
		var d_mesh := _get_door_mesh(single_door_w, door_h, 0.035, true)

		# Bisagra a la derecha en X = +half_w - 0.04
		_right_door_pivot = Node3D.new()
		_right_door_pivot.name = "RightDoorPivot"
		_right_door_pivot.position = Vector3(width * 0.5 - 0.04, door_y, front_z)
		add_child(_right_door_pivot)

		_right_door_mesh = MeshInstance3D.new()
		_right_door_mesh.name = "DoorMesh"
		_right_door_mesh.mesh = d_mesh
		_right_door_mesh.material_override = mat_glass
		_right_door_mesh.position = Vector3(-single_door_w, 0.0, 0.0) # Se extiende hacia -X
		_right_door_pivot.add_child(_right_door_mesh)
	else:
		var double_door_w := (width - 0.10) * 0.5
		var d_mesh_l := _get_door_mesh(double_door_w, door_h, 0.035, false) # Jaladera a la derecha
		var d_mesh_r := _get_door_mesh(double_door_w, door_h, 0.035, true)  # Jaladera a la izquierda

		# Bisagra izquierda en X = -half_w + 0.04
		_left_door_pivot = Node3D.new()
		_left_door_pivot.name = "LeftDoorPivot"
		_left_door_pivot.position = Vector3(-width * 0.5 + 0.04, door_y, front_z)
		add_child(_left_door_pivot)

		_left_door_mesh = MeshInstance3D.new()
		_left_door_mesh.name = "LeftDoorMesh"
		_left_door_mesh.mesh = d_mesh_l
		_left_door_mesh.material_override = mat_glass
		_left_door_mesh.position = Vector3(0.0, 0.0, 0.0) # Se extiende hacia +X
		_left_door_pivot.add_child(_left_door_mesh)

		# Bisagra derecha en X = +half_w - 0.04
		_right_door_pivot = Node3D.new()
		_right_door_pivot.name = "RightDoorPivot"
		_right_door_pivot.position = Vector3(width * 0.5 - 0.04, door_y, front_z)
		add_child(_right_door_pivot)

		_right_door_mesh = MeshInstance3D.new()
		_right_door_mesh.name = "RightDoorMesh"
		_right_door_mesh.mesh = d_mesh_r
		_right_door_mesh.material_override = mat_glass
		_right_door_mesh.position = Vector3(-double_door_w, 0.0, 0.0) # Se extiende hacia -X
		_right_door_pivot.add_child(_right_door_mesh)

	_update_door_angles()

	# 3. Colisión física sólida
	if enable_collision:
		_setup_collision(width, height, depth)

	# 4. Stock de Bebidas en Repisas
	if auto_stock:
		stock_shelves_visually([], stock_seed)


func _update_door_angles() -> void:
	if _left_door_pivot:
		_left_door_pivot.rotation.y = -left_door_open_ratio * MAX_DOOR_ANGLE
	if _right_door_pivot:
		_right_door_pivot.rotation.y = right_door_open_ratio * MAX_DOOR_ANGLE


func _setup_collision(w: float, h: float, d: float) -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "CoolerCollision"

	var cshape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(w, h, d)
	cshape.shape = bshape
	cshape.position = Vector3(0.0, h * 0.5, 0.0)
	_collision_body.add_child(cshape)
	add_child(_collision_body)


# =========================================================================
# MATERIALES Y TEXTURAS DEL ATLAS INTELIGENTE
# =========================================================================

## Limpia todos los cachés estáticos para recarga inmediata de texturas y mallas
static func clear_cache() -> void:
	_cached_body_meshes.clear()
	_cached_door_mesh_single = null
	_cached_door_mesh_double = null
	_cached_cooler_material = null
	_cached_glass_material = null


static func get_cooler_material(color: FinishColor = FinishColor.WHITE_HOSPITALITY) -> StandardMaterial3D:
	if _cached_cooler_material != null:
		return _cached_cooler_material

	_cached_cooler_material = StandardMaterial3D.new()
	_cached_cooler_material.roughness = 0.35
	_cached_cooler_material.metallic = 0.15

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	if FileAccess.file_exists(gpath):
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_cached_cooler_material.albedo_texture = tex
			return _cached_cooler_material

	if ResourceLoader.exists(TEXTURE_PATH):
		_cached_cooler_material.albedo_texture = load(TEXTURE_PATH)
	else:
		var col := Color(0.95, 0.95, 0.96) if color == FinishColor.WHITE_HOSPITALITY else Color(0.18, 0.18, 0.20)
		_cached_cooler_material.albedo_color = col

	return _cached_cooler_material


static func get_glass_material() -> StandardMaterial3D:
	if _cached_glass_material != null:
		return _cached_glass_material

	_cached_glass_material = StandardMaterial3D.new()
	_cached_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cached_glass_material.albedo_color = Color(0.85, 0.95, 1.0, 0.30) # Vidrio transparente con reflejo cian
	_cached_glass_material.roughness = 0.05
	_cached_glass_material.metallic = 0.20
	return _cached_glass_material


# =========================================================================
# GENERACIÓN DE MALLA PROCEDURAL (ARRAYMESH & GPU INSTANCING)
# =========================================================================

## Retorna la malla compartida del refrigerador para GPU Instancing
static func get_shared_body_mesh(
	type: int = 1,
	color: int = 0,
	w: float = 1.80,
	d: float = 0.90,
	h: float = 2.05,
	levels: int = 5
) -> ArrayMesh:
	var cache_key := "%d_%d_%.2f_%.2f_%.2f_%d" % [type, color, w, d, h, levels]
	if _cached_body_meshes.has(cache_key):
		return _cached_body_meshes[cache_key]

	var mesh := _build_cooler_body_mesh(type, color, w, d, h, levels)
	_cached_body_meshes[cache_key] = mesh
	return mesh


static func _build_cooler_body_mesh(
	type: int,
	color: int,
	w: float,
	d: float,
	h: float,
	levels: int
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas UV Regions de commercial_cooler.png (512x512):
	# 1. Carcasa exterior esmaltada (blanca o negra)
	var uv_body_min := Vector2(0.005, 0.005)
	var uv_body_max := Vector2(0.245, 0.245)
	if color == int(FinishColor.BLACK_MODERN):
		uv_body_min = Vector2(0.005, 0.505)
		uv_body_max = Vector2(0.245, 0.745)

	# 2. Cavidad interior fría iluminada
	var uv_inner_min := Vector2(0.255, 0.005)
	var uv_inner_max := Vector2(0.495, 0.245)

	# 3. Marquesina superior (Logo centrado y alas de luz laterales)
	var uv_canopy_logo_min := Vector2(0.505, 0.005)
	var uv_canopy_logo_max := Vector2(0.995, 0.245)
	var uv_canopy_wing_min := Vector2(0.755, 0.255)
	var uv_canopy_wing_max := Vector2(0.995, 0.495)

	# 4. Rejilla louver de compresor inferior (Rayas horizontales continuas)
	var uv_grille_min := Vector2(0.005, 0.255)
	var uv_grille_max := Vector2(0.495, 0.495)
	if color == int(FinishColor.BLACK_MODERN):
		uv_grille_min = Vector2(0.255, 0.505)
		uv_grille_max = Vector2(0.495, 0.995)

	# 5. Display termostato digital dedicado (-2.4 °C con LED verde, sin estirar)
	var uv_thermo_min := Vector2(0.505, 0.255)
	var uv_thermo_max := Vector2(0.745, 0.495)

	# 6. Repisas de alambre y aluminio
	var uv_wire_min := Vector2(0.505, 0.755)
	var uv_wire_max := Vector2(0.995, 0.995)

	var half_w := w * 0.5
	var half_d := d * 0.5
	var wall_t := 0.045
	var kick_h := 0.32
	var canopy_h := 0.28
	var open_h := h - kick_h - canopy_h

	# 1. CARCASA EXTERIOR (Pared trasera, laterales, techo y base)
	# Pared trasera (-Z)
	_add_box_st(st, Vector3(0.0, h * 0.5, -half_d + wall_t * 0.5), Vector3(w, h, wall_t), uv_body_min, uv_body_max)
	# Lateral izquierdo (-X)
	_add_box_st(st, Vector3(-half_w + wall_t * 0.5, h * 0.5, 0.0), Vector3(wall_t, h, d), uv_body_min, uv_body_max)
	# Lateral derecho (+X)
	_add_box_st(st, Vector3(half_w - wall_t * 0.5, h * 0.5, 0.0), Vector3(wall_t, h, d), uv_body_min, uv_body_max)
	# Techo superior (+Y)
	_add_box_st(st, Vector3(0.0, h - wall_t * 0.5, 0.0), Vector3(w, wall_t, d), uv_body_min, uv_body_max)
	# Base inferior (-Y)
	_add_box_st(st, Vector3(0.0, wall_t * 0.5, 0.0), Vector3(w, wall_t, d), uv_body_min, uv_body_max)

	# 2. ZÓCALO INFERIOR / REJILLA DE COMPRESOR
	var grille_w := w - wall_t * 2.0
	var grille_z := half_d - 0.03
	# Cara frontal con rayas louver continuas, caras laterales/top/bottom con textura de carcasa limpia
	_add_box_st(st, Vector3(0.0, kick_h * 0.5, grille_z), Vector3(grille_w, kick_h, 0.06), uv_body_min, uv_body_max, uv_grille_min, uv_grille_max)

	# 2.1 DISPLAY DIGITAL TERMOSTATO (Colocado en la esquina derecha de la rejilla, SIN estirar)
	var thermo_w := 0.18
	var thermo_h := 0.09
	var thermo_x := half_w - wall_t - thermo_w * 0.5 - 0.06
	var thermo_y := kick_h * 0.5 + 0.02
	var thermo_z := half_d + 0.008
	_add_box_st(st, Vector3(thermo_x, thermo_y, thermo_z), Vector3(thermo_w, thermo_h, 0.016), uv_thermo_min, uv_thermo_min + Vector2(0.02, 0.02), uv_thermo_min, uv_thermo_max)

	# 3. MARQUESINA SUPERIOR ILUMINADA (LIGHTBOX CANOPY)
	# En lugar de estirar el logotipo a lo ancho, se centra el logotipo y se extienden las alas iluminadas
	var canopy_y := h - canopy_h * 0.5
	var canopy_box_center := Vector3(0.0, canopy_y, grille_z)
	var canopy_box_size := Vector3(grille_w, canopy_h, 0.06)

	if grille_w > 1.10:
		# Vitrina ancha de 2 puertas:
		# Logotipo centrado de ancho fijo (0.92m, proporción ~3.3:1)
		var logo_w := 0.92
		# Cuerpo base de la marquesina (caja con fondo de alas blancas)
		_add_box_st(st, canopy_box_center, canopy_box_size, uv_body_min, uv_body_max, uv_canopy_wing_min, uv_canopy_wing_max)

		# Sección central frontal con el Logotipo e icono de chef
		var logo_z := half_d + 0.002
		_add_quad_front_st(st, Vector3(0.0, canopy_y, logo_z), Vector2(logo_w, canopy_h - 0.02), uv_canopy_logo_min, uv_canopy_logo_max)
	else:
		# Vitrina individual de 1 puerta: El logo abarca el frente con márgenes limpios
		_add_box_st(st, canopy_box_center, canopy_box_size, uv_body_min, uv_body_max, uv_canopy_logo_min, uv_canopy_logo_max)

	# 4. CAVIDAD INTERIOR ILUMINADA (Fondo blanco reflectante con rieles)
	var inner_w := w - wall_t * 2.0 - 0.01
	var inner_d := d - wall_t - 0.08
	var inner_center_z := -half_d + wall_t + inner_d * 0.5
	var inner_y := kick_h + open_h * 0.5
	_add_box_st(st, Vector3(0.0, inner_y, -half_d + wall_t + 0.01), Vector3(inner_w, open_h, 0.02), uv_inner_min, uv_inner_max)

	# 5. REPISAS INTERNAS DE ALAMBRE (Wire Shelves)
	var shelf_wire_t := 0.02
	var shelf_d := inner_d - 0.04
	var shelf_z := inner_center_z + 0.01

	for lvl in range(levels):
		var sy := kick_h + 0.04 + (float(lvl) / float(levels - 1)) * (open_h - 0.10)
		_add_box_st(st, Vector3(0.0, sy, shelf_z), Vector3(inner_w, shelf_wire_t, shelf_d), uv_wire_min, uv_wire_max)

	# 6. Poste divisor central si es vitrina de 2 puertas
	if type == int(RefrigeratorType.DOUBLE_DOOR):
		_add_box_st(st, Vector3(0.0, inner_y, half_d - 0.02), Vector3(0.04, open_h, 0.04), uv_body_min, uv_body_max)

	# Las normales explícitas ya fueron asignadas con precisión por cara
	st.generate_tangents()
	return st.commit()


static func _get_door_mesh(door_w: float, door_h: float, door_t: float, handle_on_left: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var uv_glass := Vector2(0.35, 0.15)
	var uv_frame := Vector2(0.65, 0.65) # Región de aluminio pulido en [256..511, 256..383]

	var half_w := door_w * 0.5
	var half_h := door_h * 0.5
	var frame_t := 0.04

	# Vidrio templado translúcido central
	_add_box_st(st, Vector3(half_w, half_h, 0.0), Vector3(door_w - frame_t * 2.0, door_h - frame_t * 2.0, 0.01), uv_glass, uv_glass)

	# Marco perimetral de aluminio
	_add_box_st(st, Vector3(frame_t * 0.5, half_h, 0.0), Vector3(frame_t, door_h, door_t), uv_frame, uv_frame)
	_add_box_st(st, Vector3(door_w - frame_t * 0.5, half_h, 0.0), Vector3(frame_t, door_h, door_t), uv_frame, uv_frame)
	_add_box_st(st, Vector3(half_w, door_h - frame_t * 0.5, 0.0), Vector3(door_w, frame_t, door_t), uv_frame, uv_frame)
	_add_box_st(st, Vector3(half_w, frame_t * 0.5, 0.0), Vector3(door_w, frame_t, door_t), uv_frame, uv_frame)

	# Jaladera vertical cilíndrica/curva
	var handle_x := (frame_t * 1.5) if handle_on_left else (door_w - frame_t * 1.5)
	_add_box_st(st, Vector3(handle_x, half_h, 0.035), Vector3(0.025, 0.45, 0.03), uv_frame, uv_frame)

	st.generate_tangents()
	return st.commit()


# =========================================================================
# UTILIDADES SURFACE TOOL CON NORMALES Y UVS PRECISAS
# =========================================================================

static func _add_box_st(
	st: SurfaceTool,
	center: Vector3,
	size: Vector3,
	uv_min: Vector2,
	uv_max: Vector2,
	front_uv_min: Vector2 = Vector2.ZERO,
	front_uv_max: Vector2 = Vector2.ZERO
) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var f_uv_min := front_uv_min if front_uv_min != Vector2.ZERO else uv_min
	var f_uv_max := front_uv_max if front_uv_max != Vector2.ZERO else uv_max

	# 1. Front face (+Z en espacio local, mirando de frente al usuario)
	# Normal exterior exacta: Vector3.BACK (0, 0, 1). Winding Clockwise: TL -> TR -> BR, TL -> BR -> BL
	var v_front_tl := center + Vector3(-hx,  hy,  hz)
	var v_front_tr := center + Vector3( hx,  hy,  hz)
	var v_front_br := center + Vector3( hx, -hy,  hz)
	var v_front_bl := center + Vector3(-hx, -hy,  hz)
	_add_quad_st(st, v_front_tl, v_front_tr, v_front_br, v_front_bl, Vector3.BACK, f_uv_min, f_uv_max)

	# 2. Back face (-Z en espacio local)
	# Normal exterior exacta: Vector3.FORWARD (0, 0, -1)
	var v_back_tl := center + Vector3( hx,  hy, -hz)
	var v_back_tr := center + Vector3(-hx,  hy, -hz)
	var v_back_br := center + Vector3(-hx, -hy, -hz)
	var v_back_bl := center + Vector3( hx, -hy, -hz)
	_add_quad_st(st, v_back_tl, v_back_tr, v_back_br, v_back_bl, Vector3.FORWARD, uv_min, uv_max)

	# 3. Right face (+X en espacio local)
	# Normal exterior exacta: Vector3.RIGHT (1, 0, 0)
	var v_right_tl := center + Vector3( hx,  hy,  hz)
	var v_right_tr := center + Vector3( hx,  hy, -hz)
	var v_right_br := center + Vector3( hx, -hy, -hz)
	var v_right_bl := center + Vector3( hx, -hy,  hz)
	_add_quad_st(st, v_right_tl, v_right_tr, v_right_br, v_right_bl, Vector3.RIGHT, uv_min, uv_max)

	# 4. Left face (-X en espacio local)
	# Normal exterior exacta: Vector3.LEFT (-1, 0, 0)
	var v_left_tl := center + Vector3(-hx,  hy, -hz)
	var v_left_tr := center + Vector3(-hx,  hy,  hz)
	var v_left_br := center + Vector3(-hx, -hy,  hz)
	var v_left_bl := center + Vector3(-hx, -hy, -hz)
	_add_quad_st(st, v_left_tl, v_left_tr, v_left_br, v_left_bl, Vector3.LEFT, uv_min, uv_max)

	# 5. Top face (+Y en espacio local)
	# Normal exterior exacta: Vector3.UP (0, 1, 0)
	var v_top_tl := center + Vector3(-hx,  hy, -hz)
	var v_top_tr := center + Vector3( hx,  hy, -hz)
	var v_top_br := center + Vector3( hx,  hy,  hz)
	var v_top_bl := center + Vector3(-hx,  hy,  hz)
	_add_quad_st(st, v_top_tl, v_top_tr, v_top_br, v_top_bl, Vector3.UP, uv_min, uv_max)

	# 6. Bottom face (-Y en espacio local)
	# Normal exterior exacta: Vector3.DOWN (0, -1, 0)
	var v_bot_tl := center + Vector3(-hx, -hy,  hz)
	var v_bot_tr := center + Vector3( hx, -hy,  hz)
	var v_bot_br := center + Vector3( hx, -hy, -hz)
	var v_bot_bl := center + Vector3(-hx, -hy, -hz)
	_add_quad_st(st, v_bot_tl, v_bot_tr, v_bot_br, v_bot_bl, Vector3.DOWN, uv_min, uv_max)


static func _add_quad_front_st(st: SurfaceTool, center: Vector3, size: Vector2, uv_min: Vector2, uv_max: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var v_tl := center + Vector3(-hx,  hy, 0.0)
	var v_tr := center + Vector3( hx,  hy, 0.0)
	var v_br := center + Vector3( hx, -hy, 0.0)
	var v_bl := center + Vector3(-hx, -hy, 0.0)
	_add_quad_st(st, v_tl, v_tr, v_br, v_bl, Vector3.BACK, uv_min, uv_max)


static func _add_quad_st(
	st: SurfaceTool,
	v_tl: Vector3,
	v_tr: Vector3,
	v_br: Vector3,
	v_bl: Vector3,
	norm: Vector3,
	uv_min: Vector2,
	uv_max: Vector2
) -> void:
	var u_tl := Vector2(uv_min.x, uv_min.y)
	var u_tr := Vector2(uv_max.x, uv_min.y)
	var u_br := Vector2(uv_max.x, uv_max.y)
	var u_bl := Vector2(uv_min.x, uv_max.y)

	# Triángulo 1: TL -> TR -> BR (Clockwise estándar de Godot)
	st.set_normal(norm); st.set_uv(u_tl); st.add_vertex(v_tl)
	st.set_normal(norm); st.set_uv(u_tr); st.add_vertex(v_tr)
	st.set_normal(norm); st.set_uv(u_br); st.add_vertex(v_br)

	# Triángulo 2: TL -> BR -> BL (Clockwise estándar de Godot)
	st.set_normal(norm); st.set_uv(u_tl); st.add_vertex(v_tl)
	st.set_normal(norm); st.set_uv(u_br); st.add_vertex(v_br)
	st.set_normal(norm); st.set_uv(u_bl); st.add_vertex(v_bl)




# =========================================================================
# COLISIONES FÍSICAS CONSOLIDADAS
# =========================================================================

static func get_collision_boxes(type: int = 1, w: float = 1.80, d: float = 0.90, h: float = 2.05) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		}
	]


# =========================================================================
# SISTEMA DE PLANOGRAMA Y CARRILES DE BEBIDAS
# =========================================================================

## Retorna la información de niveles de repisas para acomodar bebidas
func get_shelf_levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var wall_t := 0.045
	var kick_h := 0.32
	var canopy_h := 0.28
	var open_h := height - kick_h - canopy_h
	var usable_w := width - wall_t * 2.0 - 0.04
	var usable_d := depth - wall_t - 0.12
	var center_z := 0.0

	for lvl in range(shelf_levels_count):
		var y_bottom := kick_h + 0.06 + (float(lvl) / float(shelf_levels_count - 1)) * (open_h - 0.10)
		var clearance_h := (open_h - 0.10) / float(shelf_levels_count - 1)
		result.append({
			"level": lvl,
			"y": y_bottom,
			"z": center_z,
			"usable_width": usable_w,
			"usable_depth": usable_d,
			"clearance_height": clearance_h
		})

	return result


## Llena proceduralmente las repisas con bebidas en filas hacia el fondo (Eje Z)
func stock_cooler_procedural(drinks_catalog: Array[Dictionary] = [], rng_seed: int = 0) -> Array[Dictionary]:
	var stocked: Array[Dictionary] = []

	var catalog := drinks_catalog
	if catalog.is_empty():
		catalog = [
			{"id": "water_bottle", "name": "Botella de Agua", "size": Vector3(0.075, 0.26, 0.075), "type": "bottle", "color": Color(0.20, 0.65, 0.95)},
			{"id": "soda_cola", "name": "Refresco Cola", "size": Vector3(0.070, 0.24, 0.070), "type": "bottle", "color": Color(0.85, 0.12, 0.12)},
			{"id": "soda_orange", "name": "Refresco Naranja", "size": Vector3(0.070, 0.24, 0.070), "type": "bottle", "color": Color(0.95, 0.55, 0.10)},
			{"id": "beer_lager", "name": "Cerveza Lata", "size": Vector3(0.065, 0.13, 0.065), "type": "can", "color": Color(0.25, 0.45, 0.85)},
			{"id": "energy_drink", "name": "Bebida Energética", "size": Vector3(0.060, 0.15, 0.060), "type": "can", "color": Color(0.15, 0.85, 0.35)},
			{"id": "juice_bottle", "name": "Jugo Tropical", "size": Vector3(0.070, 0.20, 0.070), "type": "bottle", "color": Color(0.95, 0.80, 0.15)}
		]

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else randi()

	var shelves := get_shelf_levels()
	var margin := 0.010 # 1cm entre columnas

	for shelf in shelves:
		var usable_w: float = shelf["usable_width"]
		var usable_d: float = shelf["usable_depth"]
		var clear_h: float = shelf["clearance_height"]
		var base_y: float = shelf["y"]
		var center_z: float = shelf["z"]

		var start_x := -usable_w * 0.5
		var current_x := start_x

		while current_x < (usable_w * 0.5 - 0.03):
			var item: Dictionary = catalog[rng.randi() % catalog.size()]
			var p_size: Vector3 = item["size"]

			if (current_x + p_size.x) > (usable_w * 0.5):
				break

			# Cuántas botellas/latas caben en profundidad (Eje Z hacia atrás)
			var count_z := maxi(1, int(usable_d / p_size.z))
			var item_center_x := current_x + p_size.x * 0.5

			# Generar la fila de bebidas hacia el fondo
			for zi in range(count_z):
				# Frontal pegado al vidrio, filas posteriores hacia el fondo
				var front_edge := center_z + usable_d * 0.5
				var local_z := front_edge - (float(zi) * p_size.z + p_size.z * 0.5)
				var local_y := base_y + p_size.y * 0.5
				var pos := Vector3(item_center_x, local_y, local_z)

				stocked.append({
					"transform": Transform3D(Basis.IDENTITY, pos),
					"item": item,
					"shelf_level": shelf["level"],
					"size": p_size
				})

			current_x += p_size.x + margin

	return stocked


## Llena visualmente las repisas con MultiMesh de botellas y latas en GPU
func stock_shelves_visually(catalog: Array[Dictionary] = [], custom_seed: int = 0) -> void:
	if _stock_container != null and is_instance_valid(_stock_container):
		_stock_container.queue_free()
		_stock_container = null

	var stocked := stock_cooler_procedural(catalog, custom_seed)
	if stocked.is_empty():
		return

	_stock_container = Node3D.new()
	_stock_container.name = "CoolerVisualDrinks"
	add_child(_stock_container)

	var bottles_transforms: Array[Transform3D] = []
	var bottles_colors: Array[Color] = []
	var cans_transforms: Array[Transform3D] = []
	var cans_colors: Array[Color] = []

	for entry in stocked:
		var item: Dictionary = entry["item"]
		var t: Transform3D = entry["transform"]
		var itype: String = item.get("type", "bottle")

		if itype == "bottle":
			bottles_transforms.append(t)
			bottles_colors.append(item.get("color", Color(0.2, 0.6, 0.9)))
		else:
			cans_transforms.append(t)
			cans_colors.append(item.get("color", Color(0.85, 0.15, 0.15)))

	# 1. MultiMesh de Botellas de Refresco y Agua
	if not bottles_transforms.is_empty():
		var bottle_mesh := CylinderMesh.new()
		bottle_mesh.top_radius = 0.024
		bottle_mesh.bottom_radius = 0.035
		bottle_mesh.height = 0.24
		var mat_bottle := StandardMaterial3D.new()
		mat_bottle.vertex_color_use_as_albedo = true
		mat_bottle.roughness = 0.20
		mat_bottle.metallic = 0.10

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = bottle_mesh
		mm.instance_count = bottles_transforms.size()
		for i in range(bottles_transforms.size()):
			mm.set_instance_transform(i, bottles_transforms[i])
			mm.set_instance_color(i, bottles_colors[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Drinks_Bottles"
		mmi.multimesh = mm
		mmi.material_override = mat_bottle
		_stock_container.add_child(mmi)

	# 2. MultiMesh de Latas de Bebidas
	if not cans_transforms.is_empty():
		var can_mesh := CylinderMesh.new()
		can_mesh.top_radius = 0.032
		can_mesh.bottom_radius = 0.032
		can_mesh.height = 0.13
		var mat_can := StandardMaterial3D.new()
		mat_can.vertex_color_use_as_albedo = true
		mat_can.roughness = 0.30
		mat_can.metallic = 0.75

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = can_mesh
		mm.instance_count = cans_transforms.size()
		for i in range(cans_transforms.size()):
			mm.set_instance_transform(i, cans_transforms[i])
			mm.set_instance_color(i, cans_colors[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Drinks_Cans"
		mmi.multimesh = mm
		mmi.material_override = mat_can
		_stock_container.add_child(mmi)
