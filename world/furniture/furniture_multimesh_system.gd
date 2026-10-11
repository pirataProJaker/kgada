class_name FurnitureMultiMeshSystem
extends Node3D

## Sistema Centralizado de Mobiliario y Electrodomésticos por GPU Instancing (Play Sector X)
## Agrupa cientos de muebles y electrodomésticos en solo 1 Draw Call por tipo mediante:
## - Texture2DArray indexado mediante identificadores semánticos ("refrigerador", "estufa", "madera_roble", etc.)
## - MultiMeshInstance3D con Hardware Instancing para cada categoría de mueble y pieza primitiva
## - Biblioteca de Primitivas Paramétricas Reutilizables (Cubos, Cilindros, Prismas) para componer muebles a 0 draw calls
## - Colisiones físicas 3D compuestas y consolidadas en un solo StaticBody3D

const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const WoodenTableScript = preload("res://world/furniture/wooden_table.gd")
const WoodenChairScript = preload("res://world/furniture/wooden_chair.gd")
const ApplianceRefrigeratorScript = preload("res://world/furniture/appliance_refrigerator.gd")
const ApplianceStoveScript = preload("res://world/furniture/appliance_stove.gd")
const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")
const ApplianceToasterScript = preload("res://world/furniture/appliance_toaster.gd")
const CoffeeTableScript = preload("res://world/furniture/coffee_table.gd")
const ApplianceWasherScript = preload("res://world/furniture/appliance_washer.gd")
const ApplianceDryerScript = preload("res://world/furniture/appliance_dryer.gd")
const ArmchairLeatherScript = preload("res://world/furniture/armchair_leather.gd")
const BookcaseTallScript = preload("res://world/furniture/bookcase_tall.gd")
const NightstandOakScript = preload("res://world/furniture/nightstand_oak.gd")
const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")
const WardrobeOakScript = preload("res://world/furniture/wardrobe_oak.gd")
const SinkUnitWhiteScript = preload("res://world/furniture/sink_unit_white.gd")
const CommercialShelfModularScript = preload("res://world/furniture/commercial_shelf_modular.gd")
const CommercialRefrigeratorModularScript = preload("res://world/furniture/commercial_refrigerator_modular.gd")
const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const PlanarPropsManagerScript = preload("res://world/furniture/planar_props_manager.gd")

# Registros de mobiliario completo
var _tables: Array[Dictionary] = []
var _chairs: Array[Dictionary] = []
var _refrigerators: Array[Dictionary] = []
var _stoves: Array[Dictionary] = []
var _microwaves: Array[Dictionary] = []
var _cabinets_base: Array[Dictionary] = []
var _cabinets_wall: Array[Dictionary] = []
var _toasters: Array[Dictionary] = []
var _coffee_tables: Array[Dictionary] = []
var _washers: Array[Dictionary] = []
var _dryers: Array[Dictionary] = []
var _armchairs: Array[Dictionary] = []
var _bookcases: Array[Dictionary] = []
var _nightstands: Array[Dictionary] = []
var _beds: Array[Dictionary] = []
var _wardrobes: Array[Dictionary] = []
var _sink_units: Array[Dictionary] = []
var _commercial_shelves: Array[Dictionary] = []
var _commercial_coolers: Array[Dictionary] = []
var _rugs: Array[Dictionary] = []
var _planar_wall_props: Array[Dictionary] = []
var _pictures: Array[Dictionary] = []

# Registros de accesorios y consumibles
var _cereals: Array[Dictionary] = []
var _milks: Array[Dictionary] = []
var _soups: Array[Dictionary] = []
var _beers: Array[Dictionary] = []
var _mugs: Array[Dictionary] = []
var _plates: Array[Dictionary] = []
var _newspapers: Array[Dictionary] = []
var _book_stacks: Array[Dictionary] = []
var _books: Dictionary = {} # book_type -> Array[Dictionary]

# Registros de piezas primitivas reutilizables
var _primitive_cubes: Array[Dictionary] = []
var _primitive_cylinders: Array[Dictionary] = []
var _primitive_prisms: Array[Dictionary] = []

# Nodos MultiMesh instanciados
var _multimesh_nodes: Dictionary = {}
var _collision_body: StaticBody3D = null

# Caché de primitivas estáticas
static var _cached_unit_cube_mesh: ArrayMesh = null
static var _cached_unit_cylinder_mesh: ArrayMesh = null
static var _cached_unit_prism_mesh: ArrayMesh = null


# =========================================================================
# REGISTRO DE MOBILIARIO Y ELECTRODOMÉSTICOS
# =========================================================================

## Limpia todos los registros y nodos hijos generados
func clear() -> void:
	_tables.clear()
	_chairs.clear()
	_refrigerators.clear()
	_stoves.clear()
	_microwaves.clear()
	_cabinets_base.clear()
	_cabinets_wall.clear()
	_toasters.clear()
	_coffee_tables.clear()
	_washers.clear()
	_dryers.clear()
	_armchairs.clear()
	_bookcases.clear()
	_nightstands.clear()
	_beds.clear()
	_wardrobes.clear()
	_sink_units.clear()
	_commercial_shelves.clear()
	_commercial_coolers.clear()
	_rugs.clear()
	_planar_wall_props.clear()
	_pictures.clear()
	_cereals.clear()
	_milks.clear()
	_soups.clear()
	_beers.clear()
	_mugs.clear()
	_plates.clear()
	_newspapers.clear()
	_book_stacks.clear()
	_books.clear()
	_primitive_cubes.clear()
	_primitive_cylinders.clear()
	_primitive_prisms.clear()

	for child in get_children():
		child.queue_free()
	_multimesh_nodes.clear()
	_collision_body = null


## Registra una mesa en el sistema de GPU Instancing
func add_table(t: Transform3D, finish: int = 0) -> void:
	_tables.append({"transform": t, "finish": finish})


## Registra una silla en el sistema de GPU Instancing
func add_chair(t: Transform3D, finish: int = 0) -> void:
	_chairs.append({"transform": t, "finish": finish})


## Registra un comedor completo (mesa + sillas)
func add_dining_set(center_t: Transform3D, finish: int = 0, chairs_count: int = 4, chair_tucked_dist: float = 0.48) -> void:
	add_table(center_t, finish)
	var x_offsets := [-0.35, 0.35]

	for xo in x_offsets:
		var local_pos := Vector3(xo, 0.0, chair_tucked_dist)
		var local_rot := Basis(Vector3.UP, PI)
		add_chair(center_t * Transform3D(local_rot, local_pos), finish)

	for xo in x_offsets:
		var local_pos := Vector3(xo, 0.0, -chair_tucked_dist)
		var local_rot := Basis.IDENTITY
		add_chair(center_t * Transform3D(local_rot, local_pos), finish)

	if chairs_count >= 6:
		var head_dist := 1.40 * 0.5 + 0.22
		var east_pos := Vector3(head_dist, 0.0, 0.0)
		var east_rot := Basis(Vector3.UP, -PI * 0.5)
		add_chair(center_t * Transform3D(east_rot, east_pos), finish)

		var west_pos := Vector3(-head_dist, 0.0, 0.0)
		var west_rot := Basis(Vector3.UP, PI * 0.5)
		add_chair(center_t * Transform3D(west_rot, west_pos), finish)


## Registra un refrigerador
func add_refrigerator(t: Transform3D) -> void:
	_refrigerators.append({"transform": t})


## Registra una estufa
func add_stove(t: Transform3D) -> void:
	_stoves.append({"transform": t})


## Registra un microondas
func add_microwave(t: Transform3D) -> void:
	_microwaves.append({"transform": t})


## Registra un gabinete bajo mesada
func add_cabinet_base(t: Transform3D) -> void:
	_cabinets_base.append({"transform": t})


## Registra un gabinete aéreo de pared
func add_cabinet_wall(t: Transform3D) -> void:
	_cabinets_wall.append({"transform": t})


## Registra un gabinete especificando su tipo (0: BASE, 1: WALL)
func add_cabinet(t: Transform3D, type: int = 0) -> void:
	if type == 0:
		add_cabinet_base(t)
	else:
		add_cabinet_wall(t)


## Registra una tostadora
func add_toaster(t: Transform3D) -> void:
	_toasters.append({"transform": t})


## Registra una mesa de centro
func add_coffee_table(t: Transform3D) -> void:
	_coffee_tables.append({"transform": t})


## Registra una lavadora
func add_washer(t: Transform3D) -> void:
	_washers.append({"transform": t})


## Registra una secadora
func add_dryer(t: Transform3D) -> void:
	_dryers.append({"transform": t})


## Registra un sillón de cuero orejero
func add_armchair(t: Transform3D) -> void:
	_armchairs.append({"transform": t})


## Registra un librero alto vacío
func add_bookcase(t: Transform3D) -> void:
	_bookcases.append({"transform": t})


## Registra una mesa de noche de roble con cajón
func add_nightstand(t: Transform3D) -> void:
	_nightstands.append({"transform": t})


## Registra una cama individual de roble con variantes de ropa de cama y estado
func add_bed_single(t: Transform3D, state: int = 0, sheet_id: int = 0, blanket_id: int = 12, has_pillow: bool = true, dirt_pct: float = 0.0) -> void:
	_beds.append({
		"transform": t,
		"state": state,
		"sheet_id": sheet_id,
		"blanket_id": blanket_id,
		"has_pillow": has_pillow,
		"dirt_pct": dirt_pct
	})


## Registra un ropero alto con puertas persianas
func add_wardrobe(t: Transform3D) -> void:
	_wardrobes.append({"transform": t})


## Registra un mueble lavaplatos blanco con grifo
func add_sink_unit(t: Transform3D) -> void:
	_sink_units.append({"transform": t})


## Registra una estantería comercial modular (góndola) en el sistema de GPU Instancing
func add_commercial_shelf(t: Transform3D, modules: int = 1, style: int = 0, preset: int = 0) -> void:
	_commercial_shelves.append({
		"transform": t,
		"modules": maxi(1, modules),
		"style": style,
		"preset": preset
	})


## Registra una vitrina refrigerada comercial (1 puerta o 2 puertas) en GPU Instancing
func add_commercial_refrigerator(t: Transform3D, type: int = 1, color: int = 0) -> void:
	_commercial_coolers.append({
		"transform": t,
		"type": type,
		"color": color
	})


## Registra un plano de piso (alfombra, tapete, felpudo) en el sistema universal de planos 2D
func add_planar_floor_prop(t: Transform3D, prop_id: Variant = "rug_00") -> void:
	var p_id := ""
	if prop_id is int:
		p_id = "rug_%02d" % clampi(prop_id, 0, 99)
	else:
		p_id = str(prop_id)

	_rugs.append({
		"transform": t,
		"prop_id": p_id
	})


## Registra una alfombra rectangular con estampado del atlas inteligente (compatibilidad)
func add_rug_rectangular(t: Transform3D, rug_id: Variant = 0) -> void:
	add_planar_floor_prop(t, rug_id)


## Registra un tapete (retrocompatibilidad)
func add_rug_braided(t: Transform3D) -> void:
	add_planar_floor_prop(t, "rug_00")


## Registra un plano de pared (póster, cuadro, letrero) en el sistema universal de planos 2D
func add_planar_wall_prop(t: Transform3D, prop_id: String) -> void:
	_planar_wall_props.append({
		"transform": t,
		"prop_id": prop_id
	})


## Registra un cuadro de pared con paisaje
func add_picture_landscape(t: Transform3D) -> void:
	_pictures.append({"transform": t})


# =========================================================================
# REGISTRO DE ACCESORIOS Y CONSUMIBLES (GPU INSTANCING)
# =========================================================================

func add_cereal(t: Transform3D) -> void:
	_cereals.append({"transform": t})

func add_milk(t: Transform3D) -> void:
	_milks.append({"transform": t})

func add_soup(t: Transform3D) -> void:
	_soups.append({"transform": t})

func add_beer(t: Transform3D) -> void:
	_beers.append({"transform": t})

func add_mug(t: Transform3D) -> void:
	_mugs.append({"transform": t})

func add_plate(t: Transform3D) -> void:
	_plates.append({"transform": t})

func add_newspaper(t: Transform3D) -> void:
	_newspapers.append({"transform": t})

func add_book_stack(t: Transform3D) -> void:
	_book_stacks.append({"transform": t})

func add_book(t: Transform3D, book_type: String = "bible") -> void:
	if not _books.has(book_type):
		_books[book_type] = []
	_books[book_type].append({"transform": t})


# =========================================================================
# REGISTRO DE PRIMITIVAS BÁSICAS (CUBOS, CILINDROS, PRISMAS)
# =========================================================================

## Registra un cubo unitario con textura lógica en el atlas
func add_primitive_cube(t: Transform3D, texture_key: String = "roble_claro", roughness: float = 0.55, metallic: float = 0.02, add_collision: bool = true) -> void:
	_primitive_cubes.append({
		"transform": t,
		"texture_key": texture_key,
		"roughness": roughness,
		"metallic": metallic,
		"collision": add_collision
	})


## Registra un cilindro unitario con textura lógica en el atlas
func add_primitive_cylinder(t: Transform3D, texture_key: String = "refrigerador", roughness: float = 0.35, metallic: float = 0.60, add_collision: bool = true) -> void:
	_primitive_cylinders.append({
		"transform": t,
		"texture_key": texture_key,
		"roughness": roughness,
		"metallic": metallic,
		"collision": add_collision
	})


## Registra un prisma / cuña unitaria con textura lógica en el atlas
func add_primitive_prism(t: Transform3D, texture_key: String = "sofa_leather", roughness: float = 0.65, metallic: float = 0.05, add_collision: bool = true) -> void:
	_primitive_prisms.append({
		"transform": t,
		"texture_key": texture_key,
		"roughness": roughness,
		"metallic": metallic,
		"collision": add_collision
	})


## Helper genérico para registrar mobiliario según su script de origen o clave de prop
func add_furniture_by_script(scr: Variant, t: Transform3D, extra_params: Dictionary = {}) -> void:
	if scr is String:
		var s_key: String = scr
		if s_key == "mug":
			add_mug(t)
		elif s_key == "book":
			add_book(t, extra_params.get("book_type", "bible"))
		elif s_key == "book_stack":
			add_book_stack(t)
		elif s_key == "newspaper":
			add_newspaper(t)
		elif s_key == "rug_braided" or s_key == "rug_rectangular" or s_key == "rug" or s_key == "planar_floor":
			var p_id: Variant = extra_params.get("prop_id", extra_params.get("rug_id", "rug_00"))
			add_planar_floor_prop(t, p_id)
		elif s_key == "planar_wall" or s_key == "poster":
			var p_id: String = str(extra_params.get("prop_id", "poster_00"))
			add_planar_wall_prop(t, p_id)
		elif s_key == "picture_landscape":
			add_picture_landscape(t)
		return

	if extra_params.has("prop_type"):
		var p_key: String = str(extra_params["prop_type"])
		if p_key == "mug":
			add_mug(t)
			return
		elif p_key == "book":
			add_book(t, extra_params.get("book_type", "bible"))
			return
		elif p_key == "book_stack":
			add_book_stack(t)
			return
		elif p_key == "newspaper":
			add_newspaper(t)
			return
		elif p_key == "rug_braided" or p_key == "rug_rectangular" or p_key == "rug" or p_key == "planar_floor":
			var p_id: Variant = extra_params.get("prop_id", extra_params.get("rug_id", "rug_00"))
			add_planar_floor_prop(t, p_id)
			return
		elif p_key == "planar_wall" or p_key == "poster":
			var p_id: String = str(extra_params.get("prop_id", "poster_00"))
			add_planar_wall_prop(t, p_id)
			return
		elif p_key == "picture_landscape":
			add_picture_landscape(t)
			return

	if scr == WoodenTableScript:
		add_table(t, extra_params.get("finish", 0))
	elif scr == WoodenChairScript:
		add_chair(t, extra_params.get("finish", 0))
	elif scr == ApplianceRefrigeratorScript:
		add_refrigerator(t)
	elif scr == ApplianceStoveScript:
		add_stove(t)
	elif scr == ApplianceMicrowaveScript:
		add_microwave(t)
	elif scr == KitchenCabinetScript:
		var c_type: int = extra_params.get("cabinet_type", 0)
		add_cabinet(t, c_type)
	elif scr == ApplianceToasterScript:
		add_toaster(t)
	elif scr == CoffeeTableScript:
		add_coffee_table(t)
	elif scr == ApplianceWasherScript:
		add_washer(t)
	elif scr == ApplianceDryerScript:
		add_dryer(t)
	elif scr == ArmchairLeatherScript:
		add_armchair(t)
	elif scr == BookcaseTallScript:
		add_bookcase(t)
	elif scr == NightstandOakScript:
		add_nightstand(t)
	elif scr == BedSingleOakScript:
		var state: int = extra_params.get("bed_state", BedSingleOakScript.BedState.MADE)
		var sheet_id: int = extra_params.get("sheet_pattern_id", 0)
		var blanket_id: int = extra_params.get("blanket_pattern_id", 12)
		var has_pillow: bool = extra_params.get("has_pillow", true)
		var dirt_pct: float = extra_params.get("dirt_pct", 0.0)
		add_bed_single(t, state, sheet_id, blanket_id, has_pillow, dirt_pct)
	elif scr == WardrobeOakScript:
		add_wardrobe(t)
	elif scr == SinkUnitWhiteScript:
		add_sink_unit(t)
	elif scr == CommercialShelfModularScript:
		var mods: int = extra_params.get("modules", 1)
		var st: int = extra_params.get("style", 0)
		var pre: int = extra_params.get("preset", 0)
		add_commercial_shelf(t, mods, st, pre)
	elif scr == CommercialRefrigeratorModularScript:
		var c_type: int = extra_params.get("refrigerator_type", 1)
		var c_col: int = extra_params.get("finish_color", 0)
		add_commercial_refrigerator(t, c_type, c_col)


# =========================================================================
# COMPILACIÓN Y CONSTRUCCIÓN DE MULTIMESH
# =========================================================================

## Compila los MultiMeshes para GPU y genera la colisión física unificada
func build(include_collisions: bool = true) -> void:
	for child in get_children():
		child.queue_free()
	_multimesh_nodes.clear()
	_collision_body = null

	var total_count := get_total_furniture_count()
	if total_count == 0:
		return

	FurnitureTextureManagerScript.ensure_initialized()
	var shared_mat := FurnitureTextureManagerScript.get_shared_material()

	# 1. Mobiliario estándar
	_build_category("tables", WoodenTableScript.get_shared_mesh(), _tables, "roble_claro", 0.55, 0.02, shared_mat)
	_build_category("chairs", WoodenChairScript.get_shared_mesh(), _chairs, "roble_claro", 0.55, 0.02, shared_mat)
	_build_category("refrigerators", ApplianceRefrigeratorScript.get_shared_mesh(), _refrigerators, "refrigerador", 0.28, 0.15, shared_mat)
	_build_category("stoves", ApplianceStoveScript.get_shared_mesh(), _stoves, "estufa", 0.30, 0.20, shared_mat)
	_build_category("microwaves", ApplianceMicrowaveScript.get_shared_mesh(), _microwaves, "microondas", 0.32, 0.18, shared_mat)
	_build_category("cabinets_base", KitchenCabinetScript.get_shared_mesh(0), _cabinets_base, "cabinets", 0.45, 0.05, shared_mat)
	_build_category("cabinets_wall", KitchenCabinetScript.get_shared_mesh(1), _cabinets_wall, "cabinets", 0.45, 0.05, shared_mat)
	_build_category("toasters", ApplianceToasterScript.get_shared_mesh(), _toasters, "toaster", 0.25, 0.55, shared_mat)
	_build_category("coffee_tables", CoffeeTableScript.get_shared_mesh(), _coffee_tables, "coffee_table", 0.50, 0.02, shared_mat)
	_build_category("washers", ApplianceWasherScript.get_shared_mesh(), _washers, "washer", 0.28, 0.12, shared_mat)
	_build_category("dryers", ApplianceDryerScript.get_shared_mesh(), _dryers, "dryer", 0.28, 0.12, shared_mat)
	_build_category("armchairs", ArmchairLeatherScript.get_shared_mesh(), _armchairs, "sofa_leather", 0.65, 0.05, shared_mat)

	# Mobiliario nuevo del atlas
	_build_category("bookcases", BookcaseTallScript.get_shared_mesh(), _bookcases, "props_atlas", 0.65, 0.02, shared_mat)
	_build_category("nightstands", NightstandOakScript.get_shared_mesh(), _nightstands, "props_atlas", 0.60, 0.02, shared_mat)
	_build_beds()
	_build_category("wardrobes", WardrobeOakScript.get_shared_mesh(), _wardrobes, "props_atlas", 0.65, 0.02, shared_mat)
	_build_category("sink_units", SinkUnitWhiteScript.get_shared_mesh(), _sink_units, "props_atlas", 0.35, 0.15, shared_mat)
	_build_commercial_shelves(shared_mat)
	_build_commercial_coolers(shared_mat)
	_build_rugs()
	_build_planar_wall_props()
	_build_category("pictures", FurniturePropsBuilderScript.get_picture_landscape_mesh(), _pictures, "props_atlas", 0.50, 0.05, shared_mat)

	# Accesorios y consumibles
	_build_category("cereals", FurniturePropsBuilderScript.get_cereal_mesh(), _cereals, "props_atlas", 0.60, 0.01, shared_mat)
	_build_category("milks", FurniturePropsBuilderScript.get_milk_mesh(), _milks, "props_atlas", 0.50, 0.01, shared_mat)
	_build_category("soups", FurniturePropsBuilderScript.get_soup_can_mesh(), _soups, "props_atlas", 0.30, 0.60, shared_mat)
	_build_category("beers", FurniturePropsBuilderScript.get_beer_can_mesh(), _beers, "props_atlas", 0.25, 0.70, shared_mat)
	_build_category("mugs", FurniturePropsBuilderScript.get_mug_mesh(), _mugs, "props_atlas", 0.35, 0.10, shared_mat)
	_build_category("plates", FurniturePropsBuilderScript.get_plate_mesh(), _plates, "props_atlas", 0.30, 0.15, shared_mat)
	_build_category("newspapers", FurniturePropsBuilderScript.get_newspaper_mesh(), _newspapers, "props_atlas", 0.85, 0.00, shared_mat)
	_build_category("book_stacks", FurniturePropsBuilderScript.get_book_stack_mesh(), _book_stacks, "props_atlas", 0.70, 0.01, shared_mat)
	for btype in _books:
		_build_category("books_" + btype, FurniturePropsBuilderScript.get_book_mesh(btype), _books[btype], "props_atlas", 0.70, 0.01, shared_mat)

	# 2. Primitivas reutilizables
	_build_category("primitive_cubes", get_unit_cube_mesh(), _primitive_cubes, "roble_claro", 0.55, 0.02, shared_mat)
	_build_category("primitive_cylinders", get_unit_cylinder_mesh(), _primitive_cylinders, "refrigerador", 0.35, 0.60, shared_mat)
	_build_category("primitive_prisms", get_unit_prism_mesh(), _primitive_prisms, "sofa_leather", 0.65, 0.05, shared_mat)

	# 3. Colisiones físicas agrupadas
	if include_collisions:
		_collision_body = StaticBody3D.new()
		_collision_body.name = "FurnitureCollision"

		_append_boxes_collision(_tables, WoodenTableScript.get_collision_boxes())
		_append_boxes_collision(_chairs, WoodenChairScript.get_collision_boxes())
		_append_boxes_collision(_refrigerators, ApplianceRefrigeratorScript.get_collision_boxes())
		_append_boxes_collision(_stoves, ApplianceStoveScript.get_collision_boxes())
		_append_boxes_collision(_microwaves, ApplianceMicrowaveScript.get_collision_boxes())
		_append_boxes_collision(_cabinets_base, KitchenCabinetScript.get_collision_boxes(0))
		_append_boxes_collision(_cabinets_wall, KitchenCabinetScript.get_collision_boxes(1))
		_append_boxes_collision(_toasters, ApplianceToasterScript.get_collision_boxes())
		_append_boxes_collision(_coffee_tables, CoffeeTableScript.get_collision_boxes())
		_append_boxes_collision(_washers, ApplianceWasherScript.get_collision_boxes())
		_append_boxes_collision(_dryers, ApplianceDryerScript.get_collision_boxes())
		_append_boxes_collision(_armchairs, ArmchairLeatherScript.get_collision_boxes())
		_append_boxes_collision(_bookcases, BookcaseTallScript.get_collision_boxes())
		_append_boxes_collision(_nightstands, NightstandOakScript.get_collision_boxes())
		_append_boxes_collision(_beds, BedSingleOakScript.get_collision_boxes())
		_append_boxes_collision(_wardrobes, WardrobeOakScript.get_collision_boxes())
		_append_boxes_collision(_sink_units, SinkUnitWhiteScript.get_collision_boxes())

		# Colisiones de estanterías comerciales
		for entry in _commercial_shelves:
			var mods: int = entry.get("modules", 1)
			var st: int = entry.get("style", 0)
			var pre: int = entry.get("preset", 0)
			var boxes := CommercialShelfModularScript.get_collision_boxes(mods, st, pre)
			var t: Transform3D = entry["transform"]
			for b in boxes:
				var c_shape := CollisionShape3D.new()
				var b_shape := BoxShape3D.new()
				b_shape.size = b["size"]
				c_shape.shape = b_shape
				c_shape.transform = t * Transform3D(Basis.IDENTITY, b.get("position", Vector3.ZERO))
				_collision_body.add_child(c_shape)

		# Colisiones de vitrinas refrigeradas comerciales
		for entry in _commercial_coolers:
			var c_type: int = entry.get("type", 1)
			var w: float = 1.00 if c_type == 0 else 1.80
			var boxes := CommercialRefrigeratorModularScript.get_collision_boxes(c_type, w, 0.90, 2.05)
			var t: Transform3D = entry["transform"]
			for b in boxes:
				var c_shape := CollisionShape3D.new()
				var b_shape := BoxShape3D.new()
				b_shape.size = b["size"]
				c_shape.shape = b_shape
				c_shape.transform = t * Transform3D(Basis.IDENTITY, b.get("position", Vector3.ZERO))
				_collision_body.add_child(c_shape)

		# Colisiones de primitivas
		for entry in _primitive_cubes:
			if entry.get("collision", true):
				var c_shape := CollisionShape3D.new()
				var b_shape := BoxShape3D.new()
				b_shape.size = Vector3.ONE
				c_shape.shape = b_shape
				c_shape.transform = entry["transform"]
				_collision_body.add_child(c_shape)

		for entry in _primitive_cylinders:
			if entry.get("collision", true):
				var c_shape := CollisionShape3D.new()
				var cyl_shape := CylinderShape3D.new()
				cyl_shape.height = 1.0
				cyl_shape.radius = 0.5
				c_shape.shape = cyl_shape
				c_shape.transform = entry["transform"]
				_collision_body.add_child(c_shape)

		for entry in _primitive_prisms:
			if entry.get("collision", true):
				var c_shape := CollisionShape3D.new()
				var b_shape := BoxShape3D.new()
				b_shape.size = Vector3.ONE
				c_shape.shape = b_shape
				c_shape.transform = entry["transform"]
				_collision_body.add_child(c_shape)

		add_child(_collision_body)


func _build_category(cat_name: String, mesh: Mesh, items: Array, default_layer_key: String, default_r: float, default_m: float, shared_mat: ShaderMaterial) -> void:
	if items.is_empty() or mesh == null:
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()

	var default_layer := FurnitureTextureManagerScript.get_texture_layer(default_layer_key)

	for i in range(items.size()):
		var entry: Dictionary = items[i]
		var t: Transform3D = entry["transform"]
		var layer_idx: int = default_layer

		if entry.has("layer"):
			layer_idx = entry["layer"]
		elif entry.has("finish"):
			layer_idx = FurnitureTextureManagerScript.get_wood_layer_by_finish(entry["finish"])
		elif entry.has("texture_key"):
			layer_idx = FurnitureTextureManagerScript.get_texture_layer(entry["texture_key"])

		var r: float = entry.get("roughness", default_r)
		var m: float = entry.get("metallic", default_m)

		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, Color(float(layer_idx) / 255.0, r, m, 1.0))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = cat_name.capitalize().replace(" ", "") + "MultiMesh"
	mmi.multimesh = mm
	mmi.material_override = shared_mat
	add_child(mmi)
	_multimesh_nodes[cat_name] = mmi


## Construye las estanterías comerciales modulares agrupando tramos de 1m en MultiMesh
func _build_commercial_shelves(shared_mat: ShaderMaterial) -> void:
	if _commercial_shelves.is_empty():
		return

	var modules_by_type: Dictionary = {}
	for entry in _commercial_shelves:
		var t: Transform3D = entry["transform"]
		var mods: int = entry.get("modules", 1)
		var st: int = entry.get("style", 0)
		var pre: int = entry.get("preset", 0)
		var type_key := "%d_%d" % [st, pre]
		if not modules_by_type.has(type_key):
			modules_by_type[type_key] = []

		var total_w := float(mods) * 1.0
		var start_x := -total_w * 0.5 + 0.5
		for m in range(mods):
			var mod_offset := Vector3(start_x + float(m) * 1.0, 0.0, 0.0)
			var mod_t := t * Transform3D(Basis.IDENTITY, mod_offset)
			modules_by_type[type_key].append(mod_t)

	var layer_idx := FurnitureTextureManagerScript.get_texture_layer("commercial_shelf")

	for type_key in modules_by_type:
		var transforms: Array = modules_by_type[type_key]
		if transforms.is_empty():
			continue
		var type_key_str: String = str(type_key)
		var parts: PackedStringArray = type_key_str.split("_")
		var st: int = int(parts[0])
		var pre: int = int(parts[1])
		var unit_mesh := CommercialShelfModularScript.get_shared_unit_mesh(st, pre)

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = unit_mesh
		mm.instance_count = transforms.size()

		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
			mm.set_instance_color(i, Color(float(layer_idx) / 255.0, 0.45, 0.15, 1.0))

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "CommercialShelves_" + type_key + "_MultiMesh"
		mmi.multimesh = mm
		mmi.material_override = shared_mat
		add_child(mmi)
		_multimesh_nodes["commercial_shelves_" + type_key] = mmi


## Construye las vitrinas refrigeradas comerciales en GPU Instancing
func _build_commercial_coolers(shared_mat: ShaderMaterial) -> void:
	if _commercial_coolers.is_empty():
		return

	var coolers_by_type: Dictionary = {}
	for entry in _commercial_coolers:
		var c_type: int = entry.get("type", 1)
		var c_color: int = entry.get("color", 0)
		var key := "%d_%d" % [c_type, c_color]
		if not coolers_by_type.has(key):
			coolers_by_type[key] = []
		coolers_by_type[key].append(entry["transform"])

	var layer_idx := FurnitureTextureManagerScript.get_texture_layer("commercial_cooler")

	for key in coolers_by_type:
		var transforms: Array = coolers_by_type[key]
		if transforms.is_empty():
			continue
		var key_str: String = str(key)
		var parts: PackedStringArray = key_str.split("_")
		var c_type: int = int(parts[0])
		var c_color: int = int(parts[1])
		var w: float = 1.00 if c_type == 0 else 1.80
		var cooler_mesh := CommercialRefrigeratorModularScript.get_shared_body_mesh(c_type, c_color, w, 0.90, 2.05)

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = cooler_mesh
		mm.instance_count = transforms.size()

		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
			mm.set_instance_color(i, Color(float(layer_idx) / 255.0, 0.35, 0.15, 1.0))

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "CommercialCoolers_" + key + "_MultiMesh"
		mmi.multimesh = mm
		mmi.material_override = shared_mat
		add_child(mmi)
		_multimesh_nodes["commercial_coolers_" + key] = mmi


## Construye las camas con sus variantes de ropa de cama (40 patrones), estados y suciedad
func _build_beds() -> void:
	if _beds.is_empty():
		return

	var beds_group := Node3D.new()
	beds_group.name = "BedsMultiGroup"
	add_child(beds_group)
	_multimesh_nodes["beds"] = beds_group

	for entry in _beds:
		var bed := BedSingleOakScript.new()
		bed.enable_collision = false # La colisión física se centraliza en _collision_body
		bed.transform = entry["transform"]
		bed.bed_state = entry.get("state", BedSingleOakScript.BedState.MADE)
		bed.sheet_pattern_id = entry.get("sheet_id", 0)
		bed.blanket_pattern_id = entry.get("blanket_id", 12)
		bed.has_pillow = entry.get("has_pillow", true)
		bed.dirt_pct = entry.get("dirt_pct", 0.0)
		beds_group.add_child(bed)


## Construye el MultiMesh de Planos 2D de Suelo (Alfombras) usando el Atlas Inteligente
func _build_rugs() -> void:
	if _rugs.is_empty():
		return

	PlanarPropsManagerScript.ensure_initialized()
	var planar_mat := PlanarPropsManagerScript.get_material()
	var unit_mesh := FurniturePropsBuilderScript.get_unit_floor_quad_mesh()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = unit_mesh
	mm.instance_count = _rugs.size()

	for i in range(_rugs.size()):
		var entry: Dictionary = _rugs[i]
		var t: Transform3D = entry["transform"]
		var prop_id: String = str(entry.get("prop_id", "rug_00"))
		if not prop_id.begins_with("rug_") and entry.has("rug_id"):
			prop_id = "rug_%02d" % clampi(int(entry["rug_id"]), 0, 99)

		var prop: Dictionary = PlanarPropsManagerScript.get_prop(prop_id)
		var size_v: Vector2 = prop.get("size", Vector2(1.75, 1.20))
		var roughness: float = prop.get("roughness", 0.90)
		var metallic: float = prop.get("metallic", 0.0)
		var layer_idx: int = PlanarPropsManagerScript.get_layer_index(prop_id)

		# Escalar el plano unitario (1x1) a sus dimensiones reales (width en X, length en Z)
		var inst_basis := t.basis.scaled(Vector3(size_v.x, 1.0, size_v.y))
		var inst_pos := t.origin + Vector3(0.0, prop.get("surface_offset", 0.005), 0.0)
		mm.set_instance_transform(i, Transform3D(inst_basis, inst_pos))

		# Codificar en COLOR:
		# COLOR.r: layer_index en Texture2DArray / 255.0
		# COLOR.g: roughness
		# COLOR.b: metallic
		mm.set_instance_color(i, Color(float(layer_idx) / 255.0, roughness, metallic, 1.0))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "RugsMultiMesh"
	mmi.multimesh = mm
	mmi.material_override = planar_mat
	add_child(mmi)
	_multimesh_nodes["rugs"] = mmi


## Construye el MultiMesh de Planos 2D de Pared (Pósters, Cuadros) usando el Atlas Inteligente
func _build_planar_wall_props() -> void:
	if _planar_wall_props.is_empty():
		return

	PlanarPropsManagerScript.ensure_initialized()
	var planar_mat := PlanarPropsManagerScript.get_material()
	var unit_mesh := FurniturePropsBuilderScript.get_unit_wall_quad_mesh()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = unit_mesh
	mm.instance_count = _planar_wall_props.size()

	for i in range(_planar_wall_props.size()):
		var entry: Dictionary = _planar_wall_props[i]
		var t: Transform3D = entry["transform"]
		var prop_id: String = str(entry.get("prop_id", ""))

		var prop: Dictionary = PlanarPropsManagerScript.get_prop(prop_id)
		var size_v: Vector2 = prop.get("size", Vector2(0.60, 0.90))
		var roughness: float = prop.get("roughness", 0.40)
		var metallic: float = prop.get("metallic", 0.0)
		var layer_idx: int = PlanarPropsManagerScript.get_layer_index(prop_id)

		var inst_basis := t.basis.scaled(Vector3(size_v.x, size_v.y, 1.0))
		mm.set_instance_transform(i, Transform3D(inst_basis, t.origin))
		mm.set_instance_color(i, Color(float(layer_idx) / 255.0, roughness, metallic, 1.0))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WallPlanarMultiMesh"
	mmi.multimesh = mm
	mmi.material_override = planar_mat
	add_child(mmi)
	_multimesh_nodes["planar_wall"] = mmi


func _append_boxes_collision(items: Array[Dictionary], boxes: Array[Dictionary]) -> void:
	if _collision_body == null or items.is_empty() or boxes.is_empty():
		return

	for entry in items:
		var t: Transform3D = entry["transform"]
		for b in boxes:
			var c_shape := CollisionShape3D.new()
			var b_shape := BoxShape3D.new()
			b_shape.size = b["size"]
			c_shape.shape = b_shape
			c_shape.transform = t * Transform3D(Basis.IDENTITY, b.get("position", Vector3.ZERO))
			_collision_body.add_child(c_shape)


# =========================================================================
# CONSULTAS Y MÉTRICAS
# =========================================================================

func get_table_count() -> int:
	return _tables.size()

func get_chair_count() -> int:
	return _chairs.size()

func get_refrigerator_count() -> int:
	return _refrigerators.size()

func get_stove_count() -> int:
	return _stoves.size()

func get_microwave_count() -> int:
	return _microwaves.size()

func get_total_furniture_count() -> int:
	var books_count := 0
	for btype in _books:
		books_count += _books[btype].size()

	return (
		_tables.size() + _chairs.size() + _refrigerators.size() + _stoves.size()
		+ _microwaves.size() + _cabinets_base.size() + _cabinets_wall.size()
		+ _toasters.size() + _coffee_tables.size() + _washers.size() + _dryers.size()
		+ _armchairs.size() + _bookcases.size() + _nightstands.size() + _beds.size()
		+ _wardrobes.size() + _sink_units.size() + _rugs.size() + _pictures.size()
		+ _cereals.size() + _milks.size() + _soups.size() + _beers.size()
		+ _mugs.size() + _plates.size() + _newspapers.size() + _book_stacks.size()
		+ books_count + _primitive_cubes.size() + _primitive_cylinders.size()
		+ _primitive_prisms.size()
	)

func get_active_multimesh_count() -> int:
	return _multimesh_nodes.size()


# =========================================================================
# GENERADORES DE GEOMETRÍA PRIMITIVA COMPARTIDA
# =========================================================================

## Retorna la malla de un cubo unitario 1x1x1 centrado en (0,0,0) con mapeo UV [0..1]
static func get_unit_cube_mesh() -> ArrayMesh:
	if _cached_unit_cube_mesh != null:
		return _cached_unit_cube_mesh

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := 0.5
	var hy := 0.5
	var hz := 0.5

	var v0 := Vector3(-hx, -hy, -hz)
	var v1 := Vector3( hx, -hy, -hz)
	var v2 := Vector3( hx,  hy, -hz)
	var v3 := Vector3(-hx,  hy, -hz)
	var v4 := Vector3(-hx, -hy,  hz)
	var v5 := Vector3( hx, -hy,  hz)
	var v6 := Vector3( hx,  hy,  hz)
	var v7 := Vector3(-hx,  hy,  hz)

	var u_min := Vector2(0.0, 0.0)
	var u_max := Vector2(1.0, 1.0)

	_add_quad_to_st(st, v4, v5, v6, v7, Vector3.FORWARD, u_min, u_max)
	_add_quad_to_st(st, v1, v0, v3, v2, Vector3.BACK, u_min, u_max)
	_add_quad_to_st(st, v5, v1, v2, v6, Vector3.RIGHT, u_min, u_max)
	_add_quad_to_st(st, v0, v4, v7, v3, Vector3.LEFT, u_min, u_max)
	_add_quad_to_st(st, v3, v7, v6, v2, Vector3.UP, u_min, u_max)
	_add_quad_to_st(st, v0, v1, v5, v4, Vector3.DOWN, u_min, u_max)

	st.generate_normals()
	st.generate_tangents()
	_cached_unit_cube_mesh = st.commit()
	return _cached_unit_cube_mesh


## Retorna la malla de un cilindro unitario (altura 1.0, radio 0.5) centrado en (0,0,0)
static func get_unit_cylinder_mesh(segments: int = 16) -> ArrayMesh:
	if _cached_unit_cylinder_mesh != null:
		return _cached_unit_cylinder_mesh

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var r := 0.5
	var h := 1.0
	var y_top := h * 0.5
	var y_bot := -h * 0.5

	for i in range(segments):
		var a0 := float(i) / float(segments) * TAU
		var a1 := float(i + 1) / float(segments) * TAU

		var x0 := cos(a0) * r
		var z0 := sin(a0) * r
		var x1 := cos(a1) * r
		var z1 := sin(a1) * r

		var u0 := float(i) / float(segments)
		var u1 := float(i + 1) / float(segments)

		# Pared lateral
		var n0 := Vector3(cos(a0), 0, sin(a0))
		var n1 := Vector3(cos(a1), 0, sin(a1))

		st.set_normal(n0); st.set_uv(Vector2(u0, 1.0)); st.add_vertex(Vector3(x0, y_bot, z0))
		st.set_normal(n1); st.set_uv(Vector2(u1, 1.0)); st.add_vertex(Vector3(x1, y_bot, z1))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.0)); st.add_vertex(Vector3(x1, y_top, z1))

		st.set_normal(n0); st.set_uv(Vector2(u0, 1.0)); st.add_vertex(Vector3(x0, y_bot, z0))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.0)); st.add_vertex(Vector3(x1, y_top, z1))
		st.set_normal(n0); st.set_uv(Vector2(u0, 0.0)); st.add_vertex(Vector3(x0, y_top, z0))

		# Tapa superior
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3(0, y_top, 0))
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)); st.add_vertex(Vector3(x0, y_top, z0))
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)); st.add_vertex(Vector3(x1, y_top, z1))

		# Tapa inferior
		st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3(0, y_bot, 0))
		st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)); st.add_vertex(Vector3(x1, y_bot, z1))
		st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)); st.add_vertex(Vector3(x0, y_bot, z0))

	st.generate_normals()
	st.generate_tangents()
	_cached_unit_cylinder_mesh = st.commit()
	return _cached_unit_cylinder_mesh


## Retorna la malla de un prisma triangular / cuña unitaria 1x1x1
static func get_unit_prism_mesh() -> ArrayMesh:
	if _cached_unit_prism_mesh != null:
		return _cached_unit_prism_mesh

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := 0.5
	var hy := 0.5
	var hz := 0.5

	# Vértices de la cuña (base rectangular en Y inferior, bisel que sube hacia -Z)
	var v_bfl := Vector3(-hx, -hy,  hz)
	var v_bfr := Vector3( hx, -hy,  hz)
	var v_bbl := Vector3(-hx, -hy, -hz)
	var v_bbr := Vector3( hx, -hy, -hz)
	var v_tbl := Vector3(-hx,  hy, -hz)
	var v_tbr := Vector3( hx,  hy, -hz)

	var u_min := Vector2(0.0, 0.0)
	var u_max := Vector2(1.0, 1.0)

	# 1. Base inferior (-Y)
	_add_quad_to_st(st, v_bbl, v_bbr, v_bfr, v_bfl, Vector3.DOWN, u_min, u_max)
	# 2. Respaldo vertical trasero (-Z)
	_add_quad_to_st(st, v_bbr, v_bbl, v_tbl, v_tbr, Vector3.BACK, u_min, u_max)
	# 3. Rampa inclinada frontal (+Z / +Y)
	var r_norm := Vector3(0, hz, hy).normalized()
	_add_quad_to_st(st, v_bfl, v_bfr, v_tbr, v_tbl, r_norm, u_min, u_max)

	# 4. Triángulo lateral izquierdo (-X)
	st.set_normal(Vector3.LEFT); st.set_uv(Vector2(0, 1)); st.add_vertex(v_bfl)
	st.set_normal(Vector3.LEFT); st.set_uv(Vector2(0, 0)); st.add_vertex(v_tbl)
	st.set_normal(Vector3.LEFT); st.set_uv(Vector2(1, 1)); st.add_vertex(v_bbl)

	# 5. Triángulo lateral derecho (+X)
	st.set_normal(Vector3.RIGHT); st.set_uv(Vector2(0, 1)); st.add_vertex(v_bfr)
	st.set_normal(Vector3.RIGHT); st.set_uv(Vector2(1, 1)); st.add_vertex(v_bbr)
	st.set_normal(Vector3.RIGHT); st.set_uv(Vector2(0, 0)); st.add_vertex(v_tbr)

	st.generate_normals()
	st.generate_tangents()
	_cached_unit_prism_mesh = st.commit()
	return _cached_unit_prism_mesh


static func _add_quad_to_st(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
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
