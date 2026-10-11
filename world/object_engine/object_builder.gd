class_name ObjectBuilder
extends RefCounted

## Constructor Fluido y Desacoplado para el Motor de Objetos (Play Sector X)
## Permite a cualquier mueble o prop definir su anatomía geométrica ensamblando
## primitivas estándar vinculadas semánticamente al Atlas Inteligente (ObjectAtlas).
## Toda la geometría acumulada se dibuja con +0 Draw Calls adicionales.

const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")
const HouseFurnitureRecipesScript = preload("res://world/object_engine/recipes/house_furniture_recipes.gd")
const AppliancesRecipesScript = preload("res://world/object_engine/recipes/appliances_recipes.gd")
const CommercialRecipesScript = preload("res://world/object_engine/recipes/commercial_recipes.gd")
const ElectricMeterCFERecipeScript = preload("res://world/object_engine/recipes/electric_meter_cfe_recipe.gd")
const StreetlightPoleRecipeScript = preload("res://world/object_engine/recipes/streetlight_pole_recipe.gd")
const OfficeRecipesScript = preload("res://world/object_engine/recipes/office_recipes.gd")

const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")
const NightstandOakScript = preload("res://world/furniture/nightstand_oak.gd")
const WoodenTableScript = preload("res://world/furniture/wooden_table.gd")
const WoodenChairScript = preload("res://world/furniture/wooden_chair.gd")
const CoffeeTableScript = preload("res://world/furniture/coffee_table.gd")
const ArmchairLeatherScript = preload("res://world/furniture/armchair_leather.gd")
const BookcaseTallScript = preload("res://world/furniture/bookcase_tall.gd")
const WardrobeOakScript = preload("res://world/furniture/wardrobe_oak.gd")
const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")
const SinkUnitWhiteScript = preload("res://world/furniture/sink_unit_white.gd")
const ApplianceRefrigeratorScript = preload("res://world/furniture/appliance_refrigerator.gd")
const ApplianceStoveScript = preload("res://world/furniture/appliance_stove.gd")
const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const ApplianceToasterScript = preload("res://world/furniture/appliance_toaster.gd")
const ApplianceWasherScript = preload("res://world/furniture/appliance_washer.gd")
const ApplianceDryerScript = preload("res://world/furniture/appliance_dryer.gd")
const CommercialShelfModularScript = preload("res://world/furniture/commercial_shelf_modular.gd")
const CommercialRefrigeratorModularScript = preload("res://world/furniture/commercial_refrigerator_modular.gd")

var _instances: Dictionary = {} # primitive_name -> Array[Dictionary]
var _collisions: Array[Dictionary] = [] # Array de collision shapes descriptivas


func _init() -> void:
	clear()


## Limpia todos los registros del builder
func clear() -> void:
	_instances.clear()
	_collisions.clear()


## Retorna el conteo total de piezas geométricas registradas
func get_total_instances() -> int:
	var total := 0
	for prim in _instances:
		total += (_instances[prim] as Array).size()
	return total


## Retorna el diccionario de instancias por primitiva
func get_instances_map() -> Dictionary:
	return _instances


## Retorna la lista de datos de colisión registrados
func get_collisions() -> Array[Dictionary]:
	return _collisions


# =========================================================================
# MÉTODOS BASE DE ADICIÓN DE PRIMITIVAS
# =========================================================================

## Registra una primitiva genérica con transform ya escalado
func add_primitive(
	primitive_name: String,
	t: Transform3D,
	texture_key: String = "roble_claro",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = 0.55,
	metallic: float = 0.02,
	collision: bool = true,
	collision_data: Dictionary = {}
) -> void:
	var key := primitive_name.to_lower()
	if not _instances.has(key):
		_instances[key] = []

	var resolved := ObjectAtlasScript.resolve_semantic_texture(texture_key)
	var final_tex: String = resolved["texture_key"]
	var layer_idx: int = resolved["layer"]
	var final_uv: Rect2 = uv_rect
	var r: float = roughness
	var m: float = metallic
	if uv_rect == Rect2(0.0, 0.0, 1.0, 1.0) and resolved["region_name"] != "":
		final_uv = resolved["uv_rect"]
		if r == 0.55: r = resolved["roughness"]
		if m == 0.02: m = resolved["metallic"]

	_instances[key].append({
		"transform": t,
		"layer": layer_idx,
		"texture_key": final_tex,
		"uv_rect": final_uv,
		"roughness": r,
		"metallic": m
	})

	if collision and not collision_data.is_empty():
		_collisions.append(collision_data)


# =========================================================================
# MÉTODOS ESPECIALIZADOS DEL ATLAS INTELIGENTE (SMART BUILDERS)
# =========================================================================

## Agrega una caja consultando automáticamente el Atlas Inteligente por nombre de región
func add_smart_box(
	t: Transform3D,
	size: Vector3,
	texture_key: String,
	region_name: String = "",
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	var resolved := ObjectAtlasScript.resolve_semantic_texture(texture_key, region_name)
	var final_tex: String = resolved["texture_key"]
	var uv_rect: Rect2 = resolved["uv_rect"]
	var r: float = roughness if roughness >= 0.0 else resolved["roughness"]
	var m: float = metallic if metallic >= 0.0 else resolved["metallic"]
	add_box(t, size, final_tex, uv_rect, r, m, collision)


## Shorthand posicional para smart box
func add_smart_box_simple(
	pos: Vector3,
	size: Vector3,
	texture_key: String,
	region_name: String = "",
	rot_y_deg: float = 0.0,
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y_deg))
	var t := Transform3D(basis, pos)
	add_smart_box(t, size, texture_key, region_name, roughness, metallic, collision)


## Agrega una caja compuesta donde el frente (+Z) tiene una región de textura gráfica (puerta, cajón, panel)
## y las caras laterales/superior/inferior/trasera tienen la textura de cuerpo (esmalte, madera, etc.)
## Ambas partes son cubos en la misma MultiMeshInstance3D (+0 draw calls).
func add_panel_box(
	t: Transform3D,
	size: Vector3,
	texture_key: String,
	front_region: String,
	body_region: String = "",
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	# 1. Cuerpo principal (bloque con esmalte o madera para lados y dorso)
	var front_thickness := 0.003
	var body_depth := maxf(size.z - front_thickness, 0.002)
	var body_sz := Vector3(size.x, size.y, body_depth)
	var body_offset_z := -front_thickness * 0.5
	var body_t := t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, body_offset_z))
	var body_final_key: String = texture_key
	var body_final_region: String = body_region
	if not body_region.is_empty() and (body_region.contains("/") or not ObjectAtlasScript.has_region(texture_key, body_region)):
		body_final_key = body_region
		body_final_region = ""
	add_smart_box(body_t, body_sz, body_final_key, body_final_region, roughness, metallic, false)

	# 2. Panel frontal exterior (+Z) con la textura detallada (manijas, botones, biseles)
	var front_sz := Vector3(size.x, size.y, front_thickness)
	var front_offset_z := (size.z * 0.5) - (front_thickness * 0.5)
	var front_t := t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, front_offset_z))
	var front_final_key: String = texture_key
	var front_final_region: String = front_region
	if not front_region.is_empty() and (front_region.contains("/") or not ObjectAtlasScript.has_region(texture_key, front_region)):
		front_final_key = front_region
		front_final_region = ""
	add_smart_box(front_t, front_sz, front_final_key, front_final_region, roughness, metallic, false)

	# 3. Colisión física consolidada única
	if collision:
		_collisions.append({
			"type": "box",
			"transform": t,
			"size": size
		})


## Shorthand posicional para panel box
func add_panel_box_simple(
	pos: Vector3,
	size: Vector3,
	texture_key: String,
	front_region: String,
	body_region: String = "",
	rot_y_deg: float = 0.0,
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y_deg))
	var t := Transform3D(basis, pos)
	add_panel_box(t, size, texture_key, front_region, body_region, roughness, metallic, collision)


## Agrega una caja compuesta donde la tapa superior (+Y) tiene una región gráfica (quemadores, granito)
## y el contorno perimetral tiene textura lisa o lateral (+0 draw calls).
func add_top_panel_box(
	t: Transform3D,
	size: Vector3,
	texture_key: String,
	top_region: String,
	body_region: String = "",
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	var top_thickness := 0.003
	var body_height := maxf(size.y - top_thickness, 0.002)
	var body_sz := Vector3(size.x, body_height, size.z)
	var body_offset_y := -top_thickness * 0.5
	var body_t := t * Transform3D(Basis.IDENTITY, Vector3(0.0, body_offset_y, 0.0))
	var body_final_key: String = texture_key
	var body_final_region: String = body_region
	if not body_region.is_empty() and (body_region.contains("/") or not ObjectAtlasScript.has_region(texture_key, body_region)):
		body_final_key = body_region
		body_final_region = ""
	add_smart_box(body_t, body_sz, body_final_key, body_final_region, roughness, metallic, false)

	var top_sz := Vector3(size.x, top_thickness, size.z)
	var top_offset_y := (size.y * 0.5) - (top_thickness * 0.5)
	var top_t := t * Transform3D(Basis.IDENTITY, Vector3(0.0, top_offset_y, 0.0))
	var top_final_key: String = texture_key
	var top_final_region: String = top_region
	if not top_region.is_empty() and (top_region.contains("/") or not ObjectAtlasScript.has_region(texture_key, top_region)):
		top_final_key = top_region
		top_final_region = ""
	add_smart_box(top_t, top_sz, top_final_key, top_final_region, roughness, metallic, false)

	if collision:
		_collisions.append({
			"type": "box",
			"transform": t,
			"size": size
		})


## Agrega una superficie continua con un hueco central (ej. encimera con tarja, marco con apertura)
## descomponiéndola en 4 piezas donde la textura está perfectamente sincronizada:
## - Misma escala y dirección en toda la superficie.
## - Cero estiramiento (las piezas largas no deforman la textura).
## - Continuidad matemática exacta en las juntas.
## - Si uv_window define un tiling o desplazamiento, se propaga de forma continua.
func add_cutout_surface(
	surface_t: Transform3D,
	total_size: Vector3, # (ancho_total, espesor, profundidad_total)
	hole_size: Vector2,  # (ancho_hueco, prof_hueco)
	hole_offset: Vector2 = Vector2.ZERO, # (offset_x, offset_z) desde el centro de la superficie
	texture_key: String = "cabinets",
	region_name: String = "granite",
	uv_window: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	var total_w := total_size.x
	var thick := total_size.y
	var total_d := total_size.z

	var hole_w := clampf(hole_size.x, 0.001, total_w - 0.002)
	var hole_d := clampf(hole_size.y, 0.001, total_d - 0.002)

	# Límites del hueco en coordenadas locales centradas en (0, 0)
	var hole_min_x := hole_offset.x - hole_w * 0.5
	var hole_max_x := hole_offset.x + hole_w * 0.5
	var hole_min_z := hole_offset.y - hole_d * 0.5
	var hole_max_z := hole_offset.y + hole_d * 0.5

	# Límites exteriores
	var surf_min_x := -total_w * 0.5
	var surf_max_x := total_w * 0.5
	var surf_min_z := -total_d * 0.5
	var surf_max_z := total_d * 0.5

	# Resolver la textura base en el atlas
	var resolved := ObjectAtlasScript.resolve_semantic_texture(texture_key, region_name)
	var final_tex: String = resolved["texture_key"]
	var base_rect: Rect2 = resolved["uv_rect"]
	var r: float = roughness if roughness >= 0.0 else resolved["roughness"]
	var m: float = metallic if metallic >= 0.0 else resolved["metallic"]

	# Función auxiliar para calcular el sub-rectángulo continuo en el atlas
	var make_sub_rect := func(local_min_x: float, local_max_x: float, local_min_z: float, local_max_z: float) -> Rect2:
		var u0 := (local_min_x - surf_min_x) / total_w
		var u1 := (local_max_x - surf_min_x) / total_w
		var v0 := (local_min_z - surf_min_z) / total_d
		var v1 := (local_max_z - surf_min_z) / total_d

		# Remapear según uv_window (para soportar tiling o ventanas continuas modulares)
		var win_u0 := uv_window.position.x + u0 * uv_window.size.x
		var win_u1 := uv_window.position.x + u1 * uv_window.size.x
		var win_v0 := uv_window.position.y + v0 * uv_window.size.y
		var win_v1 := uv_window.position.y + v1 * uv_window.size.y

		var final_u := base_rect.position.x + win_u0 * base_rect.size.x
		var final_v := base_rect.position.y + win_v0 * base_rect.size.y
		var final_uw := (win_u1 - win_u0) * base_rect.size.x
		var final_vh := (win_v1 - win_v0) * base_rect.size.y
		return Rect2(final_u, final_v, final_uw, final_vh)

	# 1. Ala Izquierda (abarca todo Z, de surf_min_x a hole_min_x)
	var w_left := maxf(hole_min_x - surf_min_x, 0.0)
	if w_left > 0.001:
		var pos_left := Vector3(surf_min_x + w_left * 0.5, 0.0, 0.0)
		var t_left := surface_t * Transform3D(Basis.IDENTITY, pos_left)
		var sz_left := Vector3(w_left, thick, total_d)
		var rect_left: Rect2 = make_sub_rect.call(surf_min_x, hole_min_x, surf_min_z, surf_max_z)
		add_box(t_left, sz_left, final_tex, rect_left, r, m, false)

	# 2. Ala Derecha (abarca todo Z, de hole_max_x a surf_max_x)
	var w_right := maxf(surf_max_x - hole_max_x, 0.0)
	if w_right > 0.001:
		var pos_right := Vector3(hole_max_x + w_right * 0.5, 0.0, 0.0)
		var t_right := surface_t * Transform3D(Basis.IDENTITY, pos_right)
		var sz_right := Vector3(w_right, thick, total_d)
		var rect_right: Rect2 = make_sub_rect.call(hole_max_x, surf_max_x, surf_min_z, surf_max_z)
		add_box(t_right, sz_right, final_tex, rect_right, r, m, false)

	# 3. Franja Posterior (entre hole_min_x y hole_max_x, de surf_min_z a hole_min_z)
	var d_back := maxf(hole_min_z - surf_min_z, 0.0)
	if d_back > 0.001:
		var pos_back := Vector3(hole_offset.x, 0.0, surf_min_z + d_back * 0.5)
		var t_back := surface_t * Transform3D(Basis.IDENTITY, pos_back)
		var sz_back := Vector3(hole_w, thick, d_back)
		var rect_back: Rect2 = make_sub_rect.call(hole_min_x, hole_max_x, surf_min_z, hole_min_z)
		add_box(t_back, sz_back, final_tex, rect_back, r, m, false)

	# 4. Franja Frontal (entre hole_min_x y hole_max_x, de hole_max_z a surf_max_z)
	var d_front := maxf(surf_max_z - hole_max_z, 0.0)
	if d_front > 0.001:
		var pos_front := Vector3(hole_offset.x, 0.0, hole_max_z + d_front * 0.5)
		var t_front := surface_t * Transform3D(Basis.IDENTITY, pos_front)
		var sz_front := Vector3(hole_w, thick, d_front)
		var rect_front: Rect2 = make_sub_rect.call(hole_min_x, hole_max_x, hole_max_z, surf_max_z)
		add_box(t_front, sz_front, final_tex, rect_front, r, m, false)

	if collision:
		_collisions.append({
			"type": "box",
			"transform": surface_t,
			"size": total_size
		})


# =========================================================================
# MÉTODOS ESTÁNDAR DE CONSTRUCCIÓN GEOMÉTRICA
# =========================================================================

## 1. Agrega una Caja / Cubo escalado a 'size' centrado en el transform dado
func add_box(
	t: Transform3D,
	size: Vector3,
	texture_key: String = "roble_claro",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = 0.55,
	metallic: float = 0.02,
	collision: bool = true
) -> void:
	var scaled_t := t.scaled_local(size)
	var col_data := {}
	if collision:
		col_data = {
			"type": "box",
			"transform": t,
			"size": size
		}
	add_primitive("cube", scaled_t, texture_key, uv_rect, roughness, metallic, collision, col_data)


## Shorthand rápido para cajas posicionales
func add_box_simple(
	pos: Vector3,
	size: Vector3,
	texture_key: String = "roble_claro",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	rot_y_deg: float = 0.0,
	roughness: float = 0.55,
	metallic: float = 0.02,
	collision: bool = true
) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y_deg))
	var t := Transform3D(basis, pos)
	add_box(t, size, texture_key, uv_rect, roughness, metallic, collision)


## 2. Agrega un Cilindro (tubo, pata, botella) con radio y altura especificados
func add_cylinder(
	t: Transform3D,
	radius: float,
	height: float,
	texture_key: String = "commercial_cooler",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = 0.35,
	metallic: float = 0.60,
	collision: bool = true
) -> void:
	var scale_vec := Vector3(radius * 2.0, height, radius * 2.0)
	var scaled_t := t.scaled_local(scale_vec)
	var col_data := {}
	if collision:
		col_data = {
			"type": "cylinder",
			"transform": t,
			"radius": radius,
			"height": height
		}
	add_primitive("cylinder", scaled_t, texture_key, uv_rect, roughness, metallic, collision, col_data)


## Shorthand rápido para cilindros posicionales
func add_cylinder_simple(
	pos: Vector3,
	radius: float,
	height: float,
	texture_key: String = "commercial_cooler",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = 0.35,
	metallic: float = 0.60,
	collision: bool = true
) -> void:
	var t := Transform3D(Basis.IDENTITY, pos)
	add_cylinder(t, radius, height, texture_key, uv_rect, roughness, metallic, collision)


## Cilindro inteligente que consulta región de material en ObjectAtlas
func add_smart_cylinder(
	t: Transform3D,
	radius: float,
	height: float,
	texture_key: String,
	region_name: String = "",
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	var resolved := ObjectAtlasScript.resolve_semantic_texture(texture_key, region_name)
	var final_tex: String = resolved["texture_key"]
	var uv_rect: Rect2 = resolved["uv_rect"]
	var r: float = roughness if roughness >= 0.0 else resolved["roughness"]
	var m: float = metallic if metallic >= 0.0 else resolved["metallic"]
	add_cylinder(t, radius, height, final_tex, uv_rect, r, m, collision)


## 3. Agrega una Cuña / Rampa triangular (Wedge/Prism) escalada a 'size'
func add_wedge(
	t: Transform3D,
	size: Vector3,
	texture_key: String = "sofa_leather",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = 0.65,
	metallic: float = 0.05,
	collision: bool = true
) -> void:
	var scaled_t := t.scaled_local(size)
	var col_data := {}
	if collision:
		col_data = {
			"type": "box",
			"transform": t,
			"size": size
		}
	add_primitive("wedge", scaled_t, texture_key, uv_rect, roughness, metallic, collision, col_data)


## Cuña inteligente con región del Atlas
func add_smart_wedge(
	t: Transform3D,
	size: Vector3,
	texture_key: String,
	region_name: String = "",
	roughness: float = -1.0,
	metallic: float = -1.0,
	collision: bool = true
) -> void:
	var resolved := ObjectAtlasScript.resolve_semantic_texture(texture_key, region_name)
	var final_tex: String = resolved["texture_key"]
	var uv_rect: Rect2 = resolved["uv_rect"]
	var r: float = roughness if roughness >= 0.0 else resolved["roughness"]
	var m: float = metallic if metallic >= 0.0 else resolved["metallic"]
	add_wedge(t, size, final_tex, uv_rect, r, m, collision)


## 4. Agrega una Esfera (perilla, foco, bola) con radio especificado
func add_sphere(
	t: Transform3D,
	radius: float,
	texture_key: String = "commercial_cooler",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = 0.40,
	metallic: float = 0.10,
	collision: bool = true
) -> void:
	var scale_vec := Vector3(radius * 2.0, radius * 2.0, radius * 2.0)
	var scaled_t := t.scaled_local(scale_vec)
	var col_data := {}
	if collision:
		col_data = {
			"type": "sphere",
			"transform": t,
			"radius": radius
		}
	add_primitive("sphere", scaled_t, texture_key, uv_rect, roughness, metallic, collision, col_data)


## 5. Agrega una Cápsula (tanque, píldora, extintor)
func add_capsule(
	t: Transform3D,
	radius: float,
	height: float,
	texture_key: String = "refrigerador",
	uv_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0),
	roughness: float = 0.40,
	metallic: float = 0.20,
	collision: bool = true
) -> void:
	var scale_vec := Vector3(radius * 4.0, height, radius * 4.0)
	var scaled_t := t.scaled_local(scale_vec)
	var col_data := {}
	if collision:
		col_data = {
			"type": "capsule",
			"transform": t,
			"radius": radius,
			"height": height
		}
	add_primitive("capsule", scaled_t, texture_key, uv_rect, roughness, metallic, collision, col_data)


## 6. Agrega un Panel Plano (Quad) en el plano XY mirando hacia +Z
func add_smart_quad(
	t: Transform3D,
	size: Vector2,
	texture_key: String,
	region_name: String = "",
	roughness: float = -1.0,
	metallic: float = -1.0
) -> void:
	var uv_rect: Rect2 = ObjectAtlasScript.get_region(texture_key, region_name)
	var props: Dictionary = ObjectAtlasScript.get_material_properties(texture_key, region_name)
	var r: float = roughness if roughness >= 0.0 else props.get("roughness", 0.55)
	var m: float = metallic if metallic >= 0.0 else props.get("metallic", 0.02)
	var scale_vec := Vector3(size.x, size.y, 1.0)
	var scaled_t := t.scaled_local(scale_vec)
	add_primitive("quad", scaled_t, texture_key, uv_rect, r, m, false, {})


# =========================================================================
# FUSIÓN DE BUILDERS Y EJECUCIÓN DE RECETAS
# =========================================================================

## Fusiona otro builder aplicándole un offset de transformación
func merge_from(other: ObjectBuilder, offset: Transform3D = Transform3D.IDENTITY) -> void:
	if other == null:
		return

	var other_map := other.get_instances_map()
	for prim in other_map:
		if not _instances.has(prim):
			_instances[prim] = []
		var arr: Array = other_map[prim]
		for item in arr:
			var copied: Dictionary = item.duplicate()
			copied["transform"] = offset * copied["transform"]
			_instances[prim].append(copied)

	for col in other.get_collisions():
		var col_copied: Dictionary = col.duplicate()
		col_copied["transform"] = offset * col_copied["transform"]
		_collisions.append(col_copied)


## Añade cualquier mueble o prop a partir de su clase de script o clave semántica
## Compatible 100% con HouseFurniturePlanner y con FurnitureMultiMeshSystem.
func add_furniture_by_script(scr: Variant, t: Transform3D, extra_params: Dictionary = {}) -> void:
	if scr is String:
		var s_key: String = (scr as String).to_lower()
		if s_key == "mug":
			add_cylinder(t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.045, 0.0)), 0.04, 0.09, "props_atlas", Rect2(0.5, 0.5, 0.1, 0.1), 0.35, 0.02, false)
			return
		elif s_key == "book" or s_key == "bible":
			add_box(t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.018, 0.0)), Vector3(0.16, 0.035, 0.22), "props_atlas", Rect2(0.28, 0.12, 0.1, 0.05), 0.70, 0.01, false)
			return
		elif s_key == "book_stack":
			add_box(t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)), Vector3(0.18, 0.10, 0.24), "props_atlas", Rect2(0.28, 0.12, 0.1, 0.05), 0.70, 0.01, false)
			return
		elif s_key == "newspaper":
			add_box(t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.008, 0.0)), Vector3(0.25, 0.016, 0.32), "props_atlas", Rect2(0.0, 0.0, 0.1, 0.1), 0.85, 0.0, false)
			return
		elif s_key.begins_with("rug") or s_key == "planar_floor":
			add_box(t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.004, 0.0)), Vector3(1.75, 0.008, 1.20), "props_atlas", Rect2(0.0, 0.0, 1.0, 1.0), 0.90, 0.0, false)
			return
		elif s_key == "bed" or s_key == "cama" or s_key == "bedroombed":
			HouseFurnitureRecipesScript.BedRecipe.build(self, t, extra_params)
			return
		elif s_key == "nightstand" or s_key == "bedroomnightstand":
			HouseFurnitureRecipesScript.NightstandRecipe.build(self, t, extra_params)
			return
		elif s_key == "table" or s_key == "dining_table":
			HouseFurnitureRecipesScript.TableRecipe.build(self, t, extra_params)
			return
		elif s_key == "chair":
			HouseFurnitureRecipesScript.ChairRecipe.build(self, t, extra_params)
			return
		elif s_key == "coffee_table" or s_key == "livingcoffeetable":
			HouseFurnitureRecipesScript.CoffeeTableRecipe.build(self, t, extra_params)
			return
		elif s_key == "armchair" or s_key == "livingarmchair":
			HouseFurnitureRecipesScript.ArmchairRecipe.build(self, t, extra_params)
			return
		elif s_key == "bookcase" or s_key == "livingbookcase":
			HouseFurnitureRecipesScript.BookcaseRecipe.build(self, t, extra_params)
			return
		elif s_key == "wardrobe" or s_key == "bedroomwardrobe":
			HouseFurnitureRecipesScript.WardrobeRecipe.build(self, t, extra_params)
			return
		elif s_key == "refrigerator" or s_key == "kitchenrefrigerator":
			AppliancesRecipesScript.RefrigeratorRecipe.build(self, t, extra_params)
			return
		elif s_key == "stove" or s_key == "kitchenstove":
			AppliancesRecipesScript.StoveRecipe.build(self, t, extra_params)
			return
		elif s_key == "microwave" or s_key == "kitchenmicrowave":
			AppliancesRecipesScript.MicrowaveRecipe.build(self, t, extra_params)
			return
		elif s_key == "toaster" or s_key == "kitchentoaster":
			AppliancesRecipesScript.ToasterRecipe.build(self, t, extra_params)
			return
		elif s_key == "washer" or s_key == "laundrywasher":
			AppliancesRecipesScript.WasherRecipe.build(self, t, extra_params)
			return
		elif s_key == "dryer" or s_key == "laundrydryer":
			AppliancesRecipesScript.DryerRecipe.build(self, t, extra_params)
			return
		elif s_key.begins_with("kitchen") and s_key.ends_with("cabinet"):
			var is_wall: bool = (s_key == "kitchenwallcabinet")
			var p := extra_params.duplicate()
			p["is_wall"] = is_wall
			AppliancesRecipesScript.CabinetRecipe.build(self, t, p)
			return
		elif s_key == "sink":
			AppliancesRecipesScript.SinkRecipe.build(self, t, extra_params)
			return
		elif s_key == "commercial_shelf":
			CommercialRecipesScript.CommercialShelfRecipe.build(self, t, extra_params)
			return
		elif s_key == "commercial_cooler":
			CommercialRecipesScript.CommercialCoolerRecipe.build(self, t, extra_params)
			return
		elif s_key == "medidor_cfe":
			ElectricMeterCFERecipeScript.build(self, t, extra_params)
			return
		elif s_key == "streetlight":
			StreetlightPoleRecipeScript.build(self, t, extra_params)
			return
		elif s_key == "office_desk_double" or s_key == "office_desk01" or s_key == "desk01":
			OfficeRecipesScript.OfficeDeskDoublePedestalRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_desk_metal" or s_key == "office_desk02" or s_key == "desk02":
			OfficeRecipesScript.OfficeDeskMetalTankerRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_desk_l_shaped" or s_key == "office_desk03" or s_key == "desk03":
			OfficeRecipesScript.OfficeDeskLShapedRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_desk_single" or s_key == "office_desk04" or s_key == "desk04":
			OfficeRecipesScript.OfficeDeskSinglePedestalRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_chair_green" or s_key == "office_chair01" or s_key == "chair01":
			OfficeRecipesScript.OfficeChairGreenRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_chair_red" or s_key == "office_chair02" or s_key == "chair02":
			OfficeRecipesScript.OfficeChairRedRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_file_cabinet_closed" or s_key == "file_cabinet":
			OfficeRecipesScript.OfficeFileCabinetClosedRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_file_cabinet_open":
			OfficeRecipesScript.OfficeFileCabinetOpenRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_cabinet_tall" or s_key == "cupboard02_tall":
			OfficeRecipesScript.OfficeCabinetTallRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_cabinet_low" or s_key == "cupboard02_low":
			OfficeRecipesScript.OfficeCabinetLowRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_bookcase_tall" or s_key == "cupboard01_tall":
			OfficeRecipesScript.OfficeBookcaseTallRecipe.build(self, t, extra_params)
			return
		elif s_key == "office_bookcase_low" or s_key == "cupboard01_low":
			OfficeRecipesScript.OfficeBookcaseLowRecipe.build(self, t, extra_params)
			return

	if scr == BedSingleOakScript:
		HouseFurnitureRecipesScript.BedRecipe.build(self, t, extra_params)
	elif scr == NightstandOakScript:
		HouseFurnitureRecipesScript.NightstandRecipe.build(self, t, extra_params)
	elif scr == WoodenTableScript:
		HouseFurnitureRecipesScript.TableRecipe.build(self, t, extra_params)
	elif scr == WoodenChairScript:
		HouseFurnitureRecipesScript.ChairRecipe.build(self, t, extra_params)
	elif scr == CoffeeTableScript:
		HouseFurnitureRecipesScript.CoffeeTableRecipe.build(self, t, extra_params)
	elif scr == ArmchairLeatherScript:
		HouseFurnitureRecipesScript.ArmchairRecipe.build(self, t, extra_params)
	elif scr == BookcaseTallScript:
		HouseFurnitureRecipesScript.BookcaseRecipe.build(self, t, extra_params)
	elif scr == WardrobeOakScript:
		HouseFurnitureRecipesScript.WardrobeRecipe.build(self, t, extra_params)
	elif scr == KitchenCabinetScript:
		var c_type: int = extra_params.get("cabinet_type", 0)
		var p := extra_params.duplicate()
		p["is_wall"] = (c_type == 1)
		AppliancesRecipesScript.CabinetRecipe.build(self, t, p)
	elif scr == SinkUnitWhiteScript:
		AppliancesRecipesScript.SinkRecipe.build(self, t, extra_params)
	elif scr == ApplianceRefrigeratorScript:
		AppliancesRecipesScript.RefrigeratorRecipe.build(self, t, extra_params)
	elif scr == ApplianceStoveScript:
		AppliancesRecipesScript.StoveRecipe.build(self, t, extra_params)
	elif scr == ApplianceMicrowaveScript:
		AppliancesRecipesScript.MicrowaveRecipe.build(self, t, extra_params)
	elif scr == ApplianceToasterScript:
		AppliancesRecipesScript.ToasterRecipe.build(self, t, extra_params)
	elif scr == ApplianceWasherScript:
		AppliancesRecipesScript.WasherRecipe.build(self, t, extra_params)
	elif scr == ApplianceDryerScript:
		AppliancesRecipesScript.DryerRecipe.build(self, t, extra_params)
	elif scr == CommercialShelfModularScript:
		CommercialRecipesScript.CommercialShelfRecipe.build(self, t, extra_params)
	elif scr == CommercialRefrigeratorModularScript:
		CommercialRecipesScript.CommercialCoolerRecipe.build(self, t, extra_params)
