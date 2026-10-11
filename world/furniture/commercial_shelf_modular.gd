class_name CommercialShelfModular
extends Node3D

## Estantería Comercial y Góndola Modular con GPU Instancing y Atlas Inteligente (Play Sector X)
## - Soporta Góndola Central de Doble Cara (DOUBLE_SIDED_ISLAND) y Estantería de Pared (SINGLE_SIDED_WALL).
## - Módulos encadenables: Cada módulo estándar mide 1.0m de ancho (coincide con la rejilla de celdas de 1m).
## - Presets integrados:
##   * CONVENIENCE_OTXO: 1.75m alto, 0.88m fondo (isla) / 0.45m (pared), 4 repisas (1 base + 3 colgantes).
##   * SUPERMARKET_WALMART: 2.20m alto, 1.10m fondo (isla) / 0.55m (pared), 5 repisas.
##   * WAREHOUSE_COSTCO: 3.20m alto, 1.30m fondo, 4 niveles de alta capacidad.
##   * CUSTOM: Dimensiones y repisas configurables por @export.
## - Atlas Inteligente: Mapeado a res://assets/textures/furniture/commercial_shelf.png
##   y compilado en el Texture2DArray de FurnitureTextureManager.
## - GPU Instancing:
##   * get_shared_unit_mesh(): Retorna la malla unitaria (1m de ancho) compartida en caché.
##   * Cientos de metros lineales de pasillos pueden renderizarse en 1 solo Draw Call con MultiMeshInstance3D.
## - Sistema de Planograma y Carriles de Productos (Stocking System):
##   * Calcula matemáticamente la colocación de productos por repisa:
##     - Recorre el eje X de izquierda a derecha.
##     - Llena filas hacia atrás en profundidad Z.
##     - Apila en altura Y si hay espacio vertical suficiente.
##     - Desplaza el cursor X con la anchura del siguiente producto.

const TEXTURE_PATH: String = "res://assets/textures/furniture/commercial_shelf.png"
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")

enum ShelfStyle {
	DOUBLE_SIDED_ISLAND = 0, ## Góndola central de tienda (repisas en ambos lados: frente y dorso)
	SINGLE_SIDED_WALL = 1    ## Estantería de pared (repisas solo al frente, dorso liso contra muro)
}

enum ShelfPreset {
	CONVENIENCE_OTXO = 0,    ## Tienda OTXO / conveniencia: 1.75m alto, 4 repisas
	SUPERMARKET_WALMART = 1, ## Supermercado / hipermercado: 2.20m alto, 5 repisas
	WAREHOUSE_COSTCO = 2,    ## Club de precios / bodega: 3.20m alto, vigas pesadas
	CUSTOM = 3               ## Parámetros personalizados manuales
}

@export_group("Configuración Modular")
@export_range(1, 20) var modules_count: int = 1:
	set(val):
		modules_count = maxi(1, val)
		if is_inside_tree():
			_build_shelf()

@export var shelf_style: ShelfStyle = ShelfStyle.DOUBLE_SIDED_ISLAND:
	set(val):
		shelf_style = val
		if is_inside_tree():
			_build_shelf()

@export var shelf_preset: ShelfPreset = ShelfPreset.CONVENIENCE_OTXO:
	set(val):
		shelf_preset = val
		_apply_preset_defaults()
		if is_inside_tree():
			_build_shelf()

@export_group("Dimensiones Unitarias")
@export var unit_width: float = 1.00      ## Ancho por módulo (1.0m estándar del grid)
@export var shelf_height: float = 1.75    ## Altura total del estante
@export var shelf_depth: float = 0.88     ## Fondo total (isla completa o pared)
@export var shelf_levels_count: int = 4   ## Cantidad de niveles de repisas (incluyendo base)
@export var has_price_strips: bool = true ## Portaprecios frontal rojo/comercial en cada repisa
@export var enable_collision: bool = true ## Genera colisión sólida StaticBody3D
@export var auto_stock: bool = true       ## Llena las repisas automáticamente con mercancía usando el planograma
@export var stock_seed: int = 0           ## Semilla para variación de mercancía

# Referencias a nodos internos (cuando se instancia como Node3D standalone)
var _mesh_instance: MeshInstance3D = null
var _collision_body: StaticBody3D = null
var _stock_container: Node3D = null

# Caché estático de mallas unitarias y materiales
static var _cached_unit_meshes: Dictionary = {} # "style_preset" -> ArrayMesh
static var _cached_material: StandardMaterial3D = null


func _init() -> void:
	_apply_preset_defaults()


func _ready() -> void:
	_build_shelf()


## Aplica los valores por defecto del preset seleccionado
func _apply_preset_defaults() -> void:
	match shelf_preset:
		ShelfPreset.CONVENIENCE_OTXO:
			shelf_height = 1.75
			shelf_depth = 0.88 if shelf_style == ShelfStyle.DOUBLE_SIDED_ISLAND else 0.44
			shelf_levels_count = 4
			has_price_strips = true
		ShelfPreset.SUPERMARKET_WALMART:
			shelf_height = 2.20
			shelf_depth = 1.08 if shelf_style == ShelfStyle.DOUBLE_SIDED_ISLAND else 0.54
			shelf_levels_count = 5
			has_price_strips = true
		ShelfPreset.WAREHOUSE_COSTCO:
			shelf_height = 3.20
			shelf_depth = 1.30 if shelf_style == ShelfStyle.DOUBLE_SIDED_ISLAND else 0.65
			shelf_levels_count = 4
			has_price_strips = false
		ShelfPreset.CUSTOM:
			pass


# =========================================================================
# CONSTRUCCIÓN VISUAL Y FÍSICA (STANDALONE)
# =========================================================================

func _build_shelf() -> void:
	for child in get_children():
		child.queue_free()
	_mesh_instance = null
	_collision_body = null
	_stock_container = null

	var mat := get_material()

	# 1. Crear nodo visual agrupando los módulos
	var total_w := float(modules_count) * unit_width
	var unit_mesh := get_shared_unit_mesh(shelf_style, shelf_preset, unit_width, shelf_height, shelf_depth, shelf_levels_count, has_price_strips)

	if modules_count == 1:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "ShelfMesh"
		_mesh_instance.mesh = unit_mesh
		_mesh_instance.material_override = mat
		add_child(_mesh_instance)
	else:
		# Multi-módulo: Instanciamos réplicas unitarias desplazadas en X
		var group := Node3D.new()
		group.name = "ModularShelvesGroup"
		var start_x := -total_w * 0.5 + unit_width * 0.5
		for m in range(modules_count):
			var m_inst := MeshInstance3D.new()
			m_inst.name = "Module_%d" % m
			m_inst.mesh = unit_mesh
			m_inst.material_override = mat
			m_inst.position = Vector3(start_x + float(m) * unit_width, 0.0, 0.0)
			group.add_child(m_inst)
		add_child(group)

	# 2. Configurar colisión física sólida si está habilitada
	if enable_collision:
		_setup_collision(total_w, shelf_height, shelf_depth, shelf_style)

	# 3. Llenar visualmente con mercancía si auto_stock está habilitado
	if auto_stock:
		stock_shelves_visually([], stock_seed)


func _setup_collision(total_w: float, h: float, d: float, style: ShelfStyle) -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "ShelfCollision"

	var cshape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(total_w, h, d)
	cshape.shape = bshape

	var z_center := 0.0
	if style == ShelfStyle.SINGLE_SIDED_WALL:
		z_center = d * 0.5

	cshape.position = Vector3(0.0, h * 0.5, z_center)
	_collision_body.add_child(cshape)
	add_child(_collision_body)


## Llena visualmente las repisas del estante con productos comerciales usando MultiMesh
func stock_shelves_visually(catalog: Array[Dictionary] = [], custom_seed: int = 0) -> void:
	if _stock_container != null and is_instance_valid(_stock_container):
		_stock_container.queue_free()
		_stock_container = null

	var item_catalog := catalog
	if item_catalog.is_empty():
		item_catalog = [
			{"id": "chips_yellow", "name": "Sabritas Clásicas", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.95, 0.82, 0.10)},
			{"id": "chips_red", "name": "Sabritas Flamin Hot", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.85, 0.15, 0.15)},
			{"id": "chips_orange", "name": "Doritos Nacho", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.90, 0.50, 0.15)},
			{"id": "chips_blue", "name": "Ruffles Queso", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.15, 0.45, 0.85)},
			{"id": "cereal", "name": "Caja de Cereal", "size": Vector3(0.18, 0.26, 0.08), "type": "box", "can_stack": false},
			{"id": "soup", "name": "Lata de Conserva", "size": Vector3(0.08, 0.11, 0.08), "type": "can", "can_stack": true},
			{"id": "beer", "name": "Lata de Refresco/Cerveza", "size": Vector3(0.07, 0.13, 0.07), "type": "can", "can_stack": true},
			{"id": "milk", "name": "Cartón de Leche/Jugo", "size": Vector3(0.09, 0.20, 0.09), "type": "carton", "can_stack": false}
		]

	var stocked := stock_shelves_procedural(item_catalog, custom_seed)
	if stocked.is_empty():
		return

	_stock_container = Node3D.new()
	_stock_container.name = "ShelfVisualStock"
	add_child(_stock_container)

	var chips_transforms: Array[Transform3D] = []
	var chips_colors: Array[Color] = []
	var cans_transforms: Array[Transform3D] = []
	var cans_colors: Array[Color] = []
	var boxes_transforms: Array[Transform3D] = []
	var boxes_colors: Array[Color] = []

	for entry in stocked:
		var item: Dictionary = entry["item"]
		var t: Transform3D = entry["transform"]
		var itype: String = item.get("type", "chips")

		match itype:
			"chips":
				chips_transforms.append(t)
				chips_colors.append(item.get("color", Color(0.95, 0.82, 0.10)))
			"can":
				cans_transforms.append(t)
				var can_col: Color = Color(0.85, 0.15, 0.15) if item.get("id", "") == "soup" else Color(0.30, 0.55, 0.85)
				cans_colors.append(can_col)
			_:
				boxes_transforms.append(t)
				var box_col: Color = Color(0.90, 0.80, 0.30) if item.get("id", "") == "cereal" else Color(0.85, 0.90, 0.95)
				boxes_colors.append(box_col)

	# MultiMeshes de mercancía optimizada por GPU Instancing
	if not chips_transforms.is_empty():
		var chip_mesh := BoxMesh.new()
		chip_mesh.size = Vector3(0.15, 0.21, 0.08)
		var mat_chips := StandardMaterial3D.new()
		mat_chips.vertex_color_use_as_albedo = true
		mat_chips.roughness = 0.65

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = chip_mesh
		mm.instance_count = chips_transforms.size()
		for i in range(chips_transforms.size()):
			mm.set_instance_transform(i, chips_transforms[i])
			mm.set_instance_color(i, chips_colors[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Stock_Chips"
		mmi.multimesh = mm
		mmi.material_override = mat_chips
		_stock_container.add_child(mmi)

	if not cans_transforms.is_empty():
		var can_mesh := CylinderMesh.new()
		can_mesh.top_radius = 0.036
		can_mesh.bottom_radius = 0.036
		can_mesh.height = 0.11
		var mat_cans := StandardMaterial3D.new()
		mat_cans.vertex_color_use_as_albedo = true
		mat_cans.metallic = 0.70
		mat_cans.roughness = 0.30

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = can_mesh
		mm.instance_count = cans_transforms.size()
		for i in range(cans_transforms.size()):
			mm.set_instance_transform(i, cans_transforms[i])
			mm.set_instance_color(i, cans_colors[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Stock_Cans"
		mmi.multimesh = mm
		mmi.material_override = mat_cans
		_stock_container.add_child(mmi)

	if not boxes_transforms.is_empty():
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.16, 0.24, 0.08)
		var mat_boxes := StandardMaterial3D.new()
		mat_boxes.vertex_color_use_as_albedo = true
		mat_boxes.roughness = 0.70

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = box_mesh
		mm.instance_count = boxes_transforms.size()
		for i in range(boxes_transforms.size()):
			mm.set_instance_transform(i, boxes_transforms[i])
			mm.set_instance_color(i, boxes_colors[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Stock_Boxes"
		mmi.multimesh = mm
		mmi.material_override = mat_boxes
		_stock_container.add_child(mmi)


# =========================================================================
# MATERIAL Y TEXTURAS DEL ATLAS INTELIGENTE
# =========================================================================

## Retorna el material StandardMaterial3D configurado con la textura de estantería
static func get_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	_cached_material = StandardMaterial3D.new()
	_cached_material.roughness = 0.45
	_cached_material.metallic = 0.15

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	if FileAccess.file_exists(gpath):
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_cached_material.albedo_texture = tex
			return _cached_material

	if ResourceLoader.exists(TEXTURE_PATH):
		_cached_material.albedo_texture = load(TEXTURE_PATH)
	else:
		_cached_material.albedo_color = Color(0.88, 0.86, 0.83)

	return _cached_material


# =========================================================================
# GENERACIÓN DE MALLA UNITARIA (GPU INSTANCING)
# =========================================================================

## Retorna la malla de 1 módulo unitario (1.0m) compartida para GPU Instancing
static func get_shared_unit_mesh(
	style: int = 0,
	preset: int = 0,
	w: float = 1.0,
	h: float = 1.75,
	d: float = 0.88,
	levels: int = 4,
	price_strips: bool = true
) -> ArrayMesh:
	var cache_key := "%d_%d_%.2f_%.2f_%.2f_%d_%s" % [style, preset, w, h, d, levels, str(price_strips)]
	if _cached_unit_meshes.has(cache_key):
		return _cached_unit_meshes[cache_key]

	var mesh := _build_unit_shelf_mesh(style, w, h, d, levels, price_strips)
	_cached_unit_meshes[cache_key] = mesh
	return mesh


static func _build_unit_shelf_mesh(
	style: int,
	w: float,
	h: float,
	d: float,
	levels: int,
	price_strips: bool
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Coordenadas UV por cuadrantes de commercial_shelf.png (512x512):
	# Top-Left: Chapa de metal lisa / base
	var uv_metal_min := Vector2(0.01, 0.01)
	var uv_metal_max := Vector2(0.49, 0.49)
	# Top-Right: Pegboard / panel perforado central
	var uv_peg_min := Vector2(0.51, 0.01)
	var uv_peg_max := Vector2(0.99, 0.49)
	# Bottom-Left: Charolas horizontales con ranuras
	var uv_tray_min := Vector2(0.01, 0.51)
	var uv_tray_max := Vector2(0.49, 0.99)
	# Bottom-Right Sup: Portaprecios rojo con códigos de barra
	var uv_price_min := Vector2(0.51, 0.51)
	var uv_price_max := Vector2(0.99, 0.74)
	# Bottom-Right Inf: Cremallera ranurada de postes
	var uv_post_min := Vector2(0.51, 0.76)
	var uv_post_max := Vector2(0.99, 0.99)

	var is_island := (style == int(ShelfStyle.DOUBLE_SIDED_ISLAND))
	var half_w := w * 0.5
	var half_d := d * 0.5 if is_island else d

	var post_thick := 0.04
	var back_thick := 0.03
	var kick_h := 0.16
	var tray_t := 0.03
	var lip_h := 0.035

	# 1. POSTES VERTICALES LATERALES (en X = -half_w y X = +half_w)
	var post_z_center := 0.0 if is_island else (half_d * 0.5)
	var post_depth := d if is_island else half_d
	var x_left := -half_w + post_thick * 0.5
	var x_right := half_w - post_thick * 0.5

	# Patas de base y postes esquineros
	_add_box_st(st, Vector3(x_left, h * 0.5, post_z_center), Vector3(post_thick, h, post_thick * 2.0), uv_post_min, uv_post_max)
	_add_box_st(st, Vector3(x_right, h * 0.5, post_z_center), Vector3(post_thick, h, post_thick * 2.0), uv_post_min, uv_post_max)

	# 2. PANEL TRASERO CENTRAL (Pegboard perforado)
	var panel_z := 0.0 if is_island else 0.015
	var panel_w := w - post_thick * 2.0
	var panel_h := h - kick_h
	var panel_y := kick_h + panel_h * 0.5
	_add_box_st(st, Vector3(0.0, panel_y, panel_z), Vector3(panel_w, panel_h, back_thick), uv_peg_min, uv_peg_max)

	# 3. ZÓCALO INFERIOR / PATINES DE BASE (Kickplate)
	if is_island:
		_add_box_st(st, Vector3(0.0, kick_h * 0.5, 0.0), Vector3(panel_w, kick_h, d - 0.04), uv_metal_min, uv_metal_max)
	else:
		_add_box_st(st, Vector3(0.0, kick_h * 0.5, half_d * 0.5), Vector3(panel_w, kick_h, half_d - 0.02), uv_metal_min, uv_metal_max)

	# 4. REPISAS HORIZONTALES (Niveles)
	var shelf_tray_w := panel_w
	var tray_depth := (half_d - back_thick * 0.5) - 0.02

	for lvl in range(levels):
		var y_pos: float
		if lvl == 0:
			y_pos = kick_h # Repisa base
		else:
			var remaining_h := h - kick_h - 0.12
			y_pos = kick_h + (float(lvl) / float(levels - 1)) * remaining_h

		# Cara frontal (+Z)
		var front_z := (panel_z + back_thick * 0.5) + tray_depth * 0.5
		_add_box_st(st, Vector3(0.0, y_pos + tray_t * 0.5, front_z), Vector3(shelf_tray_w, tray_t, tray_depth), uv_tray_min, uv_tray_max)

		# Portaprecios frontal (+Z)
		if price_strips:
			var lip_z := front_z + tray_depth * 0.5 + 0.005
			_add_box_st(st, Vector3(0.0, y_pos + lip_h * 0.5, lip_z), Vector3(shelf_tray_w, lip_h, 0.01), uv_price_min, uv_price_max)

		# Cara posterior (-Z) si es isla de doble cara
		if is_island:
			var back_face_z := (panel_z - back_thick * 0.5) - tray_depth * 0.5
			_add_box_st(st, Vector3(0.0, y_pos + tray_t * 0.5, back_face_z), Vector3(shelf_tray_w, tray_t, tray_depth), uv_tray_min, uv_tray_max)

			# Portaprecios posterior (-Z)
			if price_strips:
				var lip_back_z := back_face_z - tray_depth * 0.5 - 0.005
				_add_box_st(st, Vector3(0.0, y_pos + lip_h * 0.5, lip_back_z), Vector3(shelf_tray_w, lip_h, 0.01), uv_price_min, uv_price_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# =========================================================================
# UTILIDADES DE GEOMETRÍA SURFACE TOOL
# =========================================================================

static func _add_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
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

	# +Z Frente
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_min, uv_max)
	# -Z Dorso
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_min, uv_max)
	# +X Derecha
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_min, uv_max)
	# -X Izquierda
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_min, uv_max)
	# +Y Arriba
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_min, uv_max)
	# -Y Abajo
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_min, uv_max)


static func _add_quad_st(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
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


# =========================================================================
# COLISIONES CONSOLIDADAS
# =========================================================================

## Retorna las cajas de colisión para física del estante modular completo
static func get_collision_boxes(
	modules: int = 1,
	style: int = 0,
	preset: int = 0,
	w: float = 1.0,
	h: float = 1.75,
	d: float = 0.88
) -> Array[Dictionary]:
	var total_w := float(modules) * w
	var is_island := (style == int(ShelfStyle.DOUBLE_SIDED_ISLAND))
	var z_center := 0.0 if is_island else (d * 0.5)

	return [
		{
			"position": Vector3(0.0, h * 0.5, z_center),
			"size": Vector3(total_w, h, d)
		}
	]


# =========================================================================
# SISTEMA DE PLANOGRAMA Y CARRILES DE PRODUCTOS
# =========================================================================

## Retorna la información de todas las repisas disponibles para acomodar productos
func get_shelf_levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var is_island := (shelf_style == ShelfStyle.DOUBLE_SIDED_ISLAND)
	var half_d := shelf_depth * 0.5 if is_island else shelf_depth
	var back_thick := 0.03
	var usable_depth := (half_d - back_thick * 0.5) - 0.03
	var total_w := float(modules_count) * unit_width
	var usable_w := total_w - 0.08
	var kick_h := 0.16
	var tray_t := 0.03

	for lvl in range(shelf_levels_count):
		var y_bottom: float
		if lvl == 0:
			y_bottom = kick_h + tray_t
		else:
			var remaining_h := shelf_height - kick_h - 0.12
			y_bottom = kick_h + (float(lvl) / float(shelf_levels_count - 1)) * remaining_h + tray_t

		# Altura libre hasta la siguiente repisa (o hasta el tope del mueble)
		var clearance_h: float
		if lvl < shelf_levels_count - 1:
			var next_y: float = kick_h + (float(lvl + 1) / float(shelf_levels_count - 1)) * (shelf_height - kick_h - 0.12)
			clearance_h = next_y - y_bottom
		else:
			clearance_h = shelf_height - y_bottom + 0.30 # Nivel superior despejado hacia arriba

		# Cara frontal (+Z)
		var front_z := (back_thick * 0.5) + usable_depth * 0.5
		result.append({
			"level": lvl,
			"face": 0, # Frente
			"y": y_bottom,
			"z": front_z,
			"usable_width": usable_w,
			"usable_depth": usable_depth,
			"clearance_height": clearance_h
		})

		# Cara posterior (-Z) si es isla
		if is_island:
			var back_z := -(back_thick * 0.5) - usable_depth * 0.5
			result.append({
				"level": lvl,
				"face": 1, # Dorso
				"y": y_bottom,
				"z": back_z,
				"usable_width": usable_w,
				"usable_depth": usable_depth,
				"clearance_height": clearance_h
			})

	return result


## Llena proceduralmente las repisas con productos de un catálogo según la regla de carriles:
## - Recorre X de izquierda a derecha.
## - Llena filas hacia atrás en Z con el mismo producto.
## - Si cabe en altura, apila en Y.
## - Avanza X con la anchura del producto + holgura milimétrica.
func stock_shelves_procedural(item_catalog: Array[Dictionary], rng_seed: int = 0) -> Array[Dictionary]:
	var stocked_items: Array[Dictionary] = []
	if item_catalog.is_empty():
		return stocked_items

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else randi()

	var shelves := get_shelf_levels()
	var margin := 0.012 # 1.2cm entre columnas de productos

	for shelf in shelves:
		var usable_w: float = shelf["usable_width"]
		var usable_d: float = shelf["usable_depth"]
		var clear_h: float = shelf["clearance_height"]
		var base_y: float = shelf["y"]
		var center_z: float = shelf["z"]
		var face: int = shelf["face"]

		var start_x := -usable_w * 0.5
		var current_x := start_x

		while current_x < (usable_w * 0.5 - 0.04):
			# Elegir un producto al azar del catálogo
			var item: Dictionary = item_catalog[rng.randi() % item_catalog.size()]
			var p_size: Vector3 = item.get("size", Vector3(0.08, 0.12, 0.08))

			# Verificar si cabe al menos 1 producto en el espacio restante de X
			if (current_x + p_size.x) > (usable_w * 0.5):
				break

			# Verificar si cabe en la altura de esta repisa
			if p_size.y > clear_h:
				# Si no cabe de alto, intentar saltar o buscar uno más bajo
				current_x += 0.05
				continue

			# Cuántos caben en profundidad (Eje Z hacia atrás)
			var count_z := maxi(1, int(usable_d / p_size.z))
			# Cuántos caben apilados verticalmente (Eje Y)
			var count_y := 1
			if item.get("can_stack", false) and (p_size.y * 2.0 <= clear_h):
				count_y = mini(3, int(clear_h / p_size.y))

			var item_center_x := current_x + p_size.x * 0.5
			var z_sign := 1.0 if face == 0 else -1.0

			# Generar la fila de items hacia atrás
			for zi in range(count_z):
				# Frontal al borde, filas posteriores hacia el panel
				var local_z: float
				if face == 0:
					var front_edge := center_z + usable_d * 0.5
					local_z = front_edge - (float(zi) * p_size.z + p_size.z * 0.5)
				else:
					var back_edge := center_z - usable_d * 0.5
					local_z = back_edge + (float(zi) * p_size.z + p_size.z * 0.5)

				for yi in range(count_y):
					var local_y := base_y + float(yi) * p_size.y + p_size.y * 0.5
					var pos := Vector3(item_center_x, local_y, local_z)
					var rot := Basis.IDENTITY
					if face == 1:
						rot = Basis(Vector3.UP, PI)

					stocked_items.append({
						"transform": Transform3D(rot, pos),
						"item": item,
						"shelf_level": shelf["level"],
						"face": face,
						"size": p_size
					})

			# Avanzar el cursor lateral en X
			current_x += p_size.x + margin

	return stocked_items
