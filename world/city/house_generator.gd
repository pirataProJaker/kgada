extends Node3D
class_name HouseGenerator

const WALL_HEIGHT: float = 3.0
const WALL_MODULE_LENGTH: float = 3.0
const HOUSE_TEXTURE_ROOT: String = "res://assets/textures/menu/casas"
const TEXTURE_TILE_METERS: float = 1.0
const EXTERIOR_LOWER_HEIGHT: float = 1.5
const EXTERIOR_LOWER_PRIMARY_CHANCE: float = 0.85
const EXTERIOR_SURFACE_OFFSET: float = 0.01
const FENCE_ROOT: String = "res://assets/URBAN/URBAN/Fences/white_picket_fence"
const FENCE_CLOSED_LEFT_PATH: String = FENCE_ROOT + "/white_picket_fence_closed_left.fbx"
const FENCE_CLOSED_RIGHT_PATH: String = FENCE_ROOT + "/white_picket_fence_closed_right.fbx"
const FENCE_OPEN_LEFT_PATH: String = FENCE_ROOT + "/white_picket_fence_open_left.fbx"
const FENCE_OPEN_RIGHT_PATH: String = FENCE_ROOT + "/white_picket_fence_open_right.fbx"
const FENCE_BASE_Y: float = 0.0
const DOOR_PACK_SCENE_PATH: String = "res://assets/psx-15-doors-pack/source/psx doors embed.fbx"
## Cargado via preload (en vez de usar el class_name global InteractiveDoor
## directo) para no depender de que el cache de clases globales del
## proyecto ya este reconstruido (por ejemplo en una corrida headless justo
## despues de crear el script, sin haber abierto antes el editor).
const InteractiveDoorScript: GDScript = preload("res://world/city/interactive_door.gd")
## Reenvia interact()/take_damage() desde la hoja (el StaticBody3D que el
## rayo de la tecla E/machete realmente golpea) hacia el pivote/bisagra
## (InteractiveDoor) que tiene la logica real - ver comentario del archivo.
const DoorSlabScript: GDScript = preload("res://world/city/door_slab.gd")
## Las 15 mallas de puerta reales dentro del FBX compartido (se excluye el
## grupo "pCube6", que son herrajes/manijas diminutos, no puertas).
const DOOR_NODE_NAMES: Array[String] = [
	"polySurface32", "pCube21", "polySurface35", "pCube22", "pCube23", "pCube24",
	"polySurface38", "polySurface39", "polySurface40", "pSphere6", "pCube25",
	"pSphere7", "polySurface41", "polySurface42", "polySurface43",
]
## Alto objetivo (metros) al que se escala cada puerta manteniendo su
## proporcion original - deja margen de dintel bajo WALL_HEIGHT (3.0m).
const DOOR_HEIGHT_TARGET: float = 2.2
## Colchon (metros de mundo) que se recorta de cada lado de la caja de
## colision de la hoja de puerta, para que no quede tocando jambas/dintel/
## piso apenas se genera (ver _place_door).
const DOOR_COLLISION_MARGIN_WORLD: float = 0.05
## Ademas del margen general de arriba, cuanto se corre (metros de mundo)
## el centro de la caja de colision hacia el borde LIBRE de la hoja, lejos
## de la bisagra - una bisagra real esta metida respecto al canto de la
## puerta para poder girar sin rozar contra la jamba; sin este colchon
## extra la esquina pegada al gozne queda tocando la jamba en el angulo de
## reposo y la puerta se reporta "obstruida" para siempre.
const DOOR_HINGE_CLEARANCE_WORLD: float = 0.15
## Analogo a DOOR_HINGE_CLEARANCE_WORLD pero para el borde inferior de la
## hoja, que queda pegado al piso (Y=0 en el espacio de la hoja) - sin este
## colchon, el piso (una caja plana bajo todo el vano) queda tocando la
## caja de colision de la puerta y la reporta obstruida en reposo.
const DOOR_FLOOR_CLEARANCE_WORLD: float = 0.06
const STYLE_DEFINITIONS := [
	{
		"name": "brick",
		"wall": "res://assets/URBAN/URBAN/Building Parts/brick_wall.fbx",
	},
	{
		"name": "fancy_brick",
		"wall": "res://assets/URBAN/URBAN/Building Parts/fancy_brick_wall.fbx",
	},
	{
		"name": "stuco",
		"wall": "res://assets/URBAN/URBAN/Building Parts/stuco_wall.fbx",
	},
]

const HOUSE_PROFILES := [
	{"name": "compact", "width_min": 3, "width_max": 4, "depth_min": 3, "depth_max": 4, "stories_min": 1, "stories_max": 1},
	{"name": "family", "width_min": 4, "width_max": 5, "depth_min": 4, "depth_max": 4, "stories_min": 1, "stories_max": 1},
	{"name": "wide", "width_min": 5, "width_max": 5, "depth_min": 3, "depth_max": 4, "stories_min": 1, "stories_max": 1},
	{"name": "tall", "width_min": 3, "width_max": 4, "depth_min": 4, "depth_max": 5, "stories_min": 1, "stories_max": 1},
]

@export_range(4, 512, 1) var house_count: int = 4
@export var rng_seed: int = 0
@export var randomize_seed_on_run: bool = true
@export var show_debug_labels: bool = true
@export var use_white_placeholder_material: bool = false
## La escena de prueba puede ocultar los techos para inspeccionar la
## distribucion real de salas, cocina y cuarto. La ciudad final los deja
## activos para renderizar la silueta exterior completa.
@export var show_roofs: bool = true
@export var show_fences: bool = true
@export_range(0.0, 1.0, 0.05) var fence_probability: float = 0.72
@export_range(0.0, 1.0, 0.05) var small_fence_probability: float = 0.35
## La ciudad puede desactivar la generacion automatica y dispararla despues
## de construir sus parcelas.
@export var auto_generate: bool = true
@export_group("Parcelas")
## Nodo opcional que expone `block_rects` en coordenadas X/Z. Cuando se
## asigna, esas parcelas mandan sobre la cuadrícula de demostración local.
@export var parcel_source_path: NodePath
@export_range(0.0, 1.0, 0.05) var vacant_lot_probability: float = 0.15
## Margen hacia dentro desde el límite que entrega la calle, para no ocupar
## la franja de banqueta o el borde compartido con otra parcela.
@export_range(0.0, 5.0, 0.1) var parcel_boundary_inset: float = 0.5
## Retiro entre la fachada y el límite frontal de la parcela.
@export_range(0.0, 20.0, 0.1) var front_yard_depth: float = 7.0
## Retiro lateral a cada lado de la casa.
@export_range(0.0, 12.0, 0.1) var side_yard_width: float = 3.0
## Retiro entre la parte trasera de la casa y el límite posterior.
@export_range(0.0, 20.0, 0.1) var rear_yard_depth: float = 4.0
@export var narrow_lots_enabled: bool = true
@export_range(0.0, 60.0, 0.5) var narrow_lot_max_frontage: float = 18.0
@export_range(0.0, 2.0, 0.1) var narrow_lot_side_clearance: float = 1.0
@export_range(0.05, 0.5, 0.01) var wall_thickness: float = 0.14
@export_range(1.0, 8.0, 0.1) var fence_entry_gap: float = 4.0
@export var layout_mode: String = "random"
@export_range(1, 2, 1) var hall_living_opening_modules: int = 1
@export var display_spacing_x: float = 28.0
@export var display_spacing_z: float = 24.0

var generated_houses: Array[Dictionary] = []
## Lotes que existen (con su rect/front_side ya calculados) pero NO
## recibieron una casa (sorteados como vacios via vacant_lot_probability) -
## el mismo contrato rico que block_parcels (rect en coordenadas locales
## de este nodo, que coinciden con las de CityBlockGenerator porque este
## nodo no tiene rotacion/offset propio). Lo usa CityDecoration para
## esparcir basura/escombros solo donde en verdad no hay casa.
var vacant_parcels: Array[Dictionary] = []

var _rng: RandomNumberGenerator
var _generated_root: Node3D
var _fence_asset_cache: Dictionary = {}
var _door_pack_root: Node3D
var _door_pack_load_failed: bool = false
var _wall_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _walkway_material: StandardMaterial3D
var _floor_textures: Array[Texture2D] = []
var _interior_wall_textures: Array[Texture2D] = []
var _exterior_kits: Array[Dictionary] = []
var _active_box_batch: Dictionary = {}
var _active_fence_batches: Dictionary = {}
var _built_fence_boundaries: Dictionary = {}
var _shared_fence_boundary_counts: Dictionary = {}
var _active_house: Node3D


func _ready() -> void:
	_create_materials()
	_load_house_textures()
	_setup_rng()
	if auto_generate:
		call_deferred("generate_houses")


func generate_houses() -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.free()

	_generated_root = Node3D.new()
	_generated_root.name = "GeneratedHouses"
	add_child(_generated_root)
	generated_houses.clear()
	vacant_parcels.clear()
	_built_fence_boundaries.clear()
	_shared_fence_boundary_counts.clear()

	var external_parcels := _resolve_external_parcels()
	var using_external_parcels := not external_parcels.is_empty()
	var requested_house_count := maxi(house_count, 4)
	var all_parcels: Array[Dictionary] = external_parcels
	if not using_external_parcels:
		var demo_specs := _create_house_specs(_demo_parcel_count(requested_house_count))
		all_parcels = _build_demo_parcels(demo_specs)
	var occupied_parcels := _select_occupied_parcels(all_parcels, requested_house_count)
	vacant_parcels = _find_vacant_parcels(all_parcels, occupied_parcels)
	var count := mini(requested_house_count, occupied_parcels.size())
	var specs := _create_house_specs(count, occupied_parcels)
	if using_external_parcels and specs.is_empty():
		push_warning("[HouseGenerator] No hay parcelas externas suficientemente grandes para las casas configuradas.")
		return

	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var parcel_index := int(spec.get("parcel_index", index))
		if parcel_index < 0 or parcel_index >= occupied_parcels.size():
			continue
		var parcel: Dictionary = occupied_parcels[parcel_index]
		var parcel_size: Vector2 = parcel["size"]
		var parcel_rect: Rect2 = parcel["rect"]
		var source_rect: Rect2 = parcel.get("source_rect", parcel_rect)
		spec["parcel_width"] = parcel_size.x
		spec["parcel_depth"] = parcel_size.y
		spec["parcel_center"] = parcel["center"]
		spec["front_side"] = int(parcel.get("front_side", spec["front_side"]))
		spec["block_index"] = int(parcel.get("block_index", -1))
		spec["lot_index"] = int(parcel.get("lot_index", -1))
		var house_center := _house_center_in_parcel(parcel_rect, spec)
		spec["parcel_rect"] = parcel_rect
		spec["house_center"] = house_center
		spec["parcel_rect_local"] = Rect2(parcel_rect.position - house_center, parcel_rect.size)
		spec["parcel_source_rect_local"] = Rect2(source_rect.position - house_center, source_rect.size)
		generated_houses.append(spec)

	for spec in generated_houses:
		var house_center: Vector2 = spec["house_center"]
		_build_house(spec, Vector3(house_center.x, 0.0, house_center.y))
	_prepare_shared_fence_boundaries()
	if show_fences:
		for spec in generated_houses:
			if not bool(spec.get("has_fence", true)):
				continue
			var house := _generated_root.get_node(spec["name"]) as Node3D
			_build_fence_perimeter(house, spec, spec["parcel_rect_local"])

	print("[HouseGenerator] %d casas generadas (seed=%d)" % [generated_houses.size(), rng_seed])
	for spec in generated_houses:
		print("[HouseGenerator] %s profile=%s style=%s footprint=%dm x %dm lot=%.1fm x %.1fm stories=%d layout=%s front=%s" % [
			spec["name"], spec["profile"], spec["style_name"], spec["width"], spec["depth"],
			spec["parcel_width"], spec["parcel_depth"], spec["stories"], spec["layout_type"], _side_name(spec["front_side"])])


func _prepare_shared_fence_boundaries() -> void:
	_shared_fence_boundary_counts.clear()
	for spec in generated_houses:
		var house := _generated_root.get_node(spec["name"]) as Node3D
		var source_rect: Rect2 = spec.get("parcel_source_rect_local", spec["parcel_rect_local"])
		for side in range(4):
			var boundary_key := _fence_boundary_key(house, source_rect, side)
			_shared_fence_boundary_counts[boundary_key] = int(_shared_fence_boundary_counts.get(boundary_key, 0)) + 1


func _resolve_external_parcels() -> Array[Dictionary]:
	if parcel_source_path.is_empty():
		return []
	var source := get_node_or_null(parcel_source_path) as Node3D
	if source == null:
		push_warning("[HouseGenerator] parcel_source_path no apunta a un Node3D valido: %s" % parcel_source_path)
		return []
	var raw_rects: Variant = source.get("block_parcels")
	if not raw_rects is Array or raw_rects.is_empty():
		raw_rects = source.get("block_rects")
	if not raw_rects is Array:
		push_warning("[HouseGenerator] La fuente de parcelas no expone un Array block_parcels/block_rects.")
		return []

	var parcels: Array[Dictionary] = []
	for raw_value in raw_rects:
		var rect := Rect2()
		var front_side := -1
		var source_index := parcels.size()
		var block_index := -1
		var lot_index := -1
		if raw_value is Rect2:
			rect = raw_value
		elif raw_value is Dictionary and raw_value.get("rect") is Rect2:
			rect = raw_value["rect"]
			front_side = int(raw_value.get("front_side", -1))
			source_index = int(raw_value.get("source_index", source_index))
			block_index = int(raw_value.get("block_index", -1))
			lot_index = int(raw_value.get("lot_index", -1))
		else:
			continue
		var source_rect := _source_rect_to_local(source, rect)
		var local_rect := source_rect
		var inset := minf(parcel_boundary_inset, minf(local_rect.size.x, local_rect.size.y) * 0.5 - 0.01)
		if inset < 0.0:
			continue
		local_rect = Rect2(local_rect.position + Vector2.ONE * inset, local_rect.size - Vector2.ONE * inset * 2.0)
		if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
			continue
		var parcel := {
			"center": local_rect.position + local_rect.size * 0.5,
			"size": local_rect.size,
			"rect": local_rect,
			"source_rect": source_rect,
			"source_index": source_index,
		}
		if front_side >= 0:
			parcel["front_side"] = front_side
		if block_index >= 0:
			parcel["block_index"] = block_index
		if lot_index >= 0:
			parcel["lot_index"] = lot_index
		parcels.append(parcel)
	return parcels


func _source_rect_to_local(source: Node3D, rect: Rect2) -> Rect2:
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var first := to_local(source.to_global(Vector3(corners[0].x, 0.0, corners[0].y)))
	var minimum := Vector2(first.x, first.z)
	var maximum := minimum
	for corner in corners.slice(1):
		var local_corner := to_local(source.to_global(Vector3(corner.x, 0.0, corner.y)))
		minimum.x = minf(minimum.x, local_corner.x)
		minimum.y = minf(minimum.y, local_corner.z)
		maximum.x = maxf(maximum.x, local_corner.x)
		maximum.y = maxf(maximum.y, local_corner.z)
	return Rect2(minimum, maximum - minimum)


func _build_demo_parcels(specs: Array[Dictionary]) -> Array[Dictionary]:
	var parcel_width := display_spacing_x
	var parcel_depth := display_spacing_z
	for spec in specs:
		parcel_width = maxf(parcel_width, float(spec["width"]) + side_yard_width * 2.0)
		parcel_depth = maxf(parcel_depth, float(spec["depth"]) + front_yard_depth + rear_yard_depth)
	var columns := 2
	while columns * columns < specs.size():
		columns += 1
	var rows := maxi(1, int(ceil(float(specs.size()) / float(columns))))
	var parcels: Array[Dictionary] = []
	for index in range(specs.size()):
		var column := index % columns
		var row := int(index / columns)
		var rect := Rect2(
			Vector2(
				(float(column) - float(columns - 1) * 0.5) * parcel_width - parcel_width * 0.5,
				(float(row) - float(rows - 1) * 0.5) * parcel_depth - parcel_depth * 0.5
			),
			Vector2(parcel_width, parcel_depth)
		)
		parcels.append({
			"center": Vector2(
				(float(column) - float(columns - 1) * 0.5) * parcel_width,
				(float(row) - float(rows - 1) * 0.5) * parcel_depth
			),
			"size": Vector2(parcel_width, parcel_depth),
			"rect": rect,
			"source_rect": rect,
			"source_index": index,
		})
	return parcels


func _demo_parcel_count(requested_house_count: int) -> int:
	var minimum_count := maxi(requested_house_count, 4)
	var vacancy := clampf(vacant_lot_probability, 0.0, 1.0)
	if vacancy <= 0.0:
		return minimum_count
	var expected_occupancy := maxf(1.0 - vacancy, 0.05)
	return mini(64, maxi(minimum_count, int(ceil(float(minimum_count) / expected_occupancy))))


func _select_occupied_parcels(parcels: Array[Dictionary], maximum_houses: int) -> Array[Dictionary]:
	if parcels.is_empty():
		return []

	var selected_indices: Array[int] = []
	var vacancy := clampf(vacant_lot_probability, 0.0, 1.0)
	for index in range(parcels.size()):
		if _rng.randf() >= vacancy:
			selected_indices.append(index)

	if selected_indices.is_empty():
		selected_indices.append(_rng.randi_range(0, parcels.size() - 1))
	if maximum_houses > 0 and selected_indices.size() > maximum_houses:
		_shuffle_array(selected_indices)
		selected_indices.resize(maximum_houses)
		selected_indices.sort()

	var selected: Array[Dictionary] = []
	for index in selected_indices:
		selected.append(parcels[index])
	return selected


## Complemento de _select_occupied_parcels: todo parcel de `all_parcels`
## cuyo "source_index" no aparece en `occupied` - se comparan por
## source_index (no por identidad de Dictionary) porque _select_occupied_parcels
## puede haber recortado la lista (maximum_houses) o completado con un
## indice al azar, asi que no alcanza con restar por posicion.
func _find_vacant_parcels(all_parcels: Array[Dictionary], occupied: Array[Dictionary]) -> Array[Dictionary]:
	var occupied_source_indices: Dictionary = {}
	for parcel in occupied:
		occupied_source_indices[int(parcel.get("source_index", -1))] = true

	var vacant: Array[Dictionary] = []
	for parcel in all_parcels:
		if not occupied_source_indices.has(int(parcel.get("source_index", -1))):
			vacant.append(parcel)
	return vacant


func _setup_rng() -> void:
	_rng = RandomNumberGenerator.new()
	if randomize_seed_on_run:
		_rng.randomize()
		rng_seed = _rng.seed
	else:
		_rng.seed = rng_seed


func _create_materials() -> void:
	_wall_material = _make_material(Color(0.82, 0.62, 0.38, 1.0))
	_floor_material = _make_material(Color(0.33, 0.53, 0.58, 1.0))
	_roof_material = _make_material(Color(0.45, 0.19, 0.16, 1.0))
	_walkway_material = _make_material(Color(0.72, 0.72, 0.72, 1.0))


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _load_house_textures() -> void:
	_floor_textures = _load_texture_folder(HOUSE_TEXTURE_ROOT.path_join("piso"))
	_interior_wall_textures = _load_texture_folder(HOUSE_TEXTURE_ROOT.path_join("paredes_inte"))
	_exterior_kits = _load_exterior_kits()


func _load_exterior_kits() -> Array[Dictionary]:
	var folder_path := HOUSE_TEXTURE_ROOT.path_join("paredes_ext")
	var directory := DirAccess.open(folder_path)
	if directory == null:
		push_warning("[HouseGenerator] No se pudo abrir la carpeta de texturas exteriores: %s" % folder_path)
		return []
	var texture_paths: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir():
			var extension := file_name.get_extension().to_lower()
			if extension == "png" or extension == "jpg" or extension == "jpeg" or extension == "webp":
				texture_paths.append(folder_path.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	texture_paths.sort()

	var kits_by_name: Dictionary = {}
	for texture_path in texture_paths:
		var file_stem := texture_path.get_file().get_basename()
		var separator_index := file_stem.find(" ")
		if separator_index <= 0:
			continue
		var kit_name := file_stem.substr(0, separator_index)
		var texture := load(texture_path) as Texture2D
		if texture == null:
			continue
		var kit: Dictionary = kits_by_name.get(kit_name, {"name": kit_name, "lower": [], "upper": []})
		if file_stem.contains(" part_infe_"):
			var lower_textures: Array = kit["lower"]
			lower_textures.append(texture)
			kit["lower"] = lower_textures
		elif file_stem.contains(" part_sup_"):
			var upper_textures: Array = kit["upper"]
			upper_textures.append(texture)
			kit["upper"] = upper_textures
		else:
			continue
		kits_by_name[kit_name] = kit

	var kits: Array[Dictionary] = []
	for kit_name in kits_by_name.keys():
		var kit: Dictionary = kits_by_name[kit_name]
		if not (kit["lower"] as Array).is_empty() and not (kit["upper"] as Array).is_empty():
			kits.append(kit)
	return kits


func _load_texture_folder(folder_path: String) -> Array[Texture2D]:
	var texture_paths: Array[String] = []
	var directory := DirAccess.open(folder_path)
	if directory == null:
		push_warning("[HouseGenerator] No se pudo abrir la carpeta de texturas: %s" % folder_path)
		return []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir():
			var extension := file_name.get_extension().to_lower()
			if extension == "png" or extension == "jpg" or extension == "jpeg" or extension == "webp":
				texture_paths.append(folder_path.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	texture_paths.sort()

	var textures: Array[Texture2D] = []
	for texture_path in texture_paths:
		var texture := load(texture_path) as Texture2D
		if texture != null:
			textures.append(texture)
	return textures


func _pick_texture(textures: Array[Texture2D]) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[_rng.randi_range(0, textures.size() - 1)]


func _pick_exterior_kit() -> Dictionary:
	if _exterior_kits.is_empty():
		return {}
	return _exterior_kits[_rng.randi_range(0, _exterior_kits.size() - 1)]


func _first_texture(values: Array) -> Texture2D:
	for value in values:
		if value is Texture2D:
			return value as Texture2D
	return null


func _pick_exterior_lower_texture(kit: Dictionary) -> Texture2D:
	var lower_values: Array = kit.get("lower", [])
	var lower_textures: Array[Texture2D] = []
	for value in lower_values:
		if value is Texture2D:
			lower_textures.append(value as Texture2D)
	if lower_textures.is_empty():
		return null

	var primary_texture: Texture2D
	var alternate_textures: Array[Texture2D] = []
	for texture in lower_textures:
		if texture.resource_path.get_file().get_basename().contains("part_infe_2"):
			primary_texture = texture
		else:
			alternate_textures.append(texture)
	if primary_texture != null and _rng.randf() < EXTERIOR_LOWER_PRIMARY_CHANCE:
		return primary_texture
	if not alternate_textures.is_empty():
		return alternate_textures[_rng.randi_range(0, alternate_textures.size() - 1)]
	return primary_texture if primary_texture != null else lower_textures[0]


func _create_house_materials(spec: Dictionary) -> Dictionary:
	var exterior_kit: Dictionary = spec.get("exterior_kit", {})
	var exterior_lower_texture := _first_texture(exterior_kit.get("lower", []))
	var exterior_upper_texture := _first_texture(exterior_kit.get("upper", []))
	return {
		"floor": _make_texture_material(spec.get("floor_texture") as Texture2D, Color(0.33, 0.53, 0.58, 1.0)),
		"interior": _make_texture_material(spec.get("interior_wall_texture") as Texture2D, Color(0.82, 0.62, 0.38, 1.0)),
		"exterior_lower": _make_texture_material(exterior_lower_texture, Color(0.82, 0.62, 0.38, 1.0)),
		"exterior_upper": _make_texture_material(exterior_upper_texture, Color(0.82, 0.62, 0.38, 1.0)),
	}


func _make_texture_material(texture: Texture2D, fallback_color: Color) -> StandardMaterial3D:
	var material := _make_material(fallback_color)
	if texture == null:
		return material
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


func _get_house_materials(node: Node) -> Dictionary:
	var current: Node = node
	while current != null:
		if current.has_meta("house_materials"):
			var materials: Variant = current.get_meta("house_materials")
			if materials is Dictionary:
				return materials
		current = current.get_parent()
	return {}


func _get_exterior_kit(node: Node) -> Dictionary:
	var current: Node = node
	while current != null:
		if current.has_meta("exterior_kit"):
			var kit: Variant = current.get_meta("exterior_kit")
			if kit is Dictionary:
				return kit as Dictionary
		current = current.get_parent()
	return {}


func _material_for(node: Node, category: String) -> Material:
	if use_white_placeholder_material:
		return _floor_material if category == "floor" else _wall_material
	if category == "exterior_lower":
		var current: Node = node
		while current != null:
			if current.has_meta("exterior_lower_material"):
				var lower_material: Variant = current.get_meta("exterior_lower_material")
				if lower_material is Material:
					return lower_material as Material
			current = current.get_parent()
	var materials := _get_house_materials(node)
	var selected: Variant = materials.get(category)
	if selected is Material:
		return selected as Material
	return _floor_material if category == "floor" else _wall_material


func _create_house_specs(count: int, available_parcels: Array[Dictionary] = []) -> Array[Dictionary]:
	var profile_order: Array[int] = [0, 1, 2, 3]
	_shuffle_array(profile_order)
	var specs: Array[Dictionary] = []
	var layout_order: Array[String] = ["direct_living", "central_hall", "open_plan"]
	if layout_mode == "random":
		_shuffle_array(layout_order)

	var parcel_index := 0
	while specs.size() < count and (available_parcels.is_empty() or parcel_index < available_parcels.size()):
		var index := specs.size()
		var profile_index := profile_order[index % profile_order.size()]
		var profile: Dictionary = HOUSE_PROFILES[profile_index]
		var width_modules := _rng.randi_range(int(profile["width_min"]), int(profile["width_max"]))
		var depth_modules := _rng.randi_range(int(profile["depth_min"]), int(profile["depth_max"]))
		var stories := 1
		var style: Dictionary = STYLE_DEFINITIONS[_rng.randi_range(0, STYLE_DEFINITIONS.size() - 1)]
		var front_side := _rng.randi_range(0, 3)
		var rotation_degrees := 0.0
		var parcel_index_for_spec := -1
		var narrow_lot := false
		if not available_parcels.is_empty():
			var parcel: Dictionary = available_parcels[parcel_index]
			front_side = clampi(int(parcel.get("front_side", 0)), 0, 3)
			narrow_lot = _is_narrow_lot(parcel["size"], front_side)
			var module_limits := _parcel_module_limits(parcel["size"], front_side, narrow_lot)
			parcel_index_for_spec = parcel_index
			parcel_index += 1
			if module_limits.x < 3 or module_limits.y < 3:
				continue
			if narrow_lot and (front_side == 0 or front_side == 2):
				width_modules = module_limits.x
				depth_modules = mini(depth_modules, module_limits.y)
			elif narrow_lot:
				width_modules = mini(width_modules, module_limits.y)
				depth_modules = module_limits.x
			elif front_side == 0 or front_side == 2:
				width_modules = mini(width_modules, module_limits.x)
				depth_modules = mini(depth_modules, module_limits.y)
			else:
				width_modules = mini(width_modules, module_limits.y)
				depth_modules = mini(depth_modules, module_limits.x)
		var fence_style := "none"
		if _rng.randf() < clampf(fence_probability, 0.0, 1.0):
			fence_style = "small" if _rng.randf() < clampf(small_fence_probability, 0.0, 1.0) else "large"
		var layout_type: String = layout_order[index % layout_order.size()]
		if layout_mode != "random":
			layout_type = layout_mode if layout_mode == "direct_living" or layout_mode == "central_hall" or layout_mode == "open_plan" else "central_hall"
		var spec := {
			"name": "House_%02d" % (index + 1),
			"profile": str(profile["name"]),
			"style": style,
			"style_name": str(style["name"]),
			"width_modules": width_modules,
			"depth_modules": depth_modules,
			"width": width_modules * int(WALL_MODULE_LENGTH),
			"depth": depth_modules * int(WALL_MODULE_LENGTH),
			"stories": stories,
			"layout_type": layout_type,
			"front_side": front_side,
			"rotation_degrees": rotation_degrees,
			"narrow_lot": narrow_lot,
			"floor_texture": _pick_texture(_floor_textures),
			"interior_wall_texture": _pick_texture(_interior_wall_textures),
			"exterior_kit": _pick_exterior_kit(),
			"has_roof_trim": _rng.randf() < 0.65,
			"has_fence": fence_style != "none",
			"fence_style": fence_style,
			"roof_overhang": _rng.randf_range(0.2, 0.55),
			"foundation_height": _rng.randf_range(0.3, 0.5),
		}
		if parcel_index_for_spec >= 0:
			spec["parcel_index"] = parcel_index_for_spec
		specs.append(spec)
	return specs


func _is_narrow_lot(parcel_size: Vector2, front_side: int) -> bool:
	if not narrow_lots_enabled:
		return false
	var lateral_size := parcel_size.x if front_side == 0 or front_side == 2 else parcel_size.y
	return lateral_size <= narrow_lot_max_frontage


func _parcel_module_limits(parcel_size: Vector2, front_side: int, narrow_lot: bool = false) -> Vector2i:
	var lateral_size := parcel_size.x if front_side == 0 or front_side == 2 else parcel_size.y
	var inward_size := parcel_size.y if front_side == 0 or front_side == 2 else parcel_size.x
	var lateral_clearance := narrow_lot_side_clearance if narrow_lot else side_yard_width
	var lateral_buildable := lateral_size - lateral_clearance * 2.0
	var inward_buildable := inward_size - front_yard_depth - rear_yard_depth
	return Vector2i(
		int(floor(lateral_buildable / WALL_MODULE_LENGTH)),
		int(floor(inward_buildable / WALL_MODULE_LENGTH))
	)


func _house_center_in_parcel(parcel_rect: Rect2, spec: Dictionary) -> Vector2:
	var width: float = spec["width"]
	var depth: float = spec["depth"]
	var front_side := int(spec["front_side"])
	var parcel_center := parcel_rect.position + parcel_rect.size * 0.5
	if front_side == 0:
		return Vector2(parcel_center.x, parcel_rect.position.y + front_yard_depth + depth * 0.5)
	if front_side == 1:
		return Vector2(parcel_rect.end.x - front_yard_depth - width * 0.5, parcel_center.y)
	if front_side == 2:
		return Vector2(parcel_center.x, parcel_rect.end.y - front_yard_depth - depth * 0.5)
	return Vector2(parcel_rect.position.x + front_yard_depth + width * 0.5, parcel_center.y)


func _shuffle_array(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _build_house(spec: Dictionary, world_position: Vector3) -> void:
	var house := Node3D.new()
	house.name = spec["name"]
	house.position = world_position
	house.rotation_degrees.y = spec["rotation_degrees"]
	_generated_root.add_child(house)
	_active_box_batch.clear()
	_active_fence_batches.clear()
	_active_house = house

	var width: float = spec["width"]
	var depth: float = spec["depth"]
	var stories: int = spec["stories"]
	var foundation_height: float = spec["foundation_height"]
	house.set_meta("house_materials", _create_house_materials(spec))
	house.set_meta("exterior_kit", spec.get("exterior_kit", {}))
	_add_box(house, Vector3(0.0, foundation_height * 0.5, 0.0), Vector3(width + 0.3, foundation_height, depth + 0.3), _material_for(house, "floor"), "Foundation")
	var walls := Node3D.new()
	walls.name = "Walls"
	house.add_child(walls)
	_build_shell(walls, spec, width, depth, stories, foundation_height)
	_build_room_plan(house, walls, spec, width, depth, foundation_height)
	if show_roofs:
		_add_roof(house, spec, width, depth, stories, foundation_height)
	if show_debug_labels:
		_add_debug_label(house, spec, stories, foundation_height)
	_flush_box_batch(house)
	_active_house = null


func _build_fence_perimeter(house: Node3D, spec: Dictionary, parcel_rect: Rect2) -> void:
	_active_fence_batches.clear()
	var fences := Node3D.new()
	fences.name = "NaturalFences"
	house.add_child(fences)

	var front_side := int(spec["front_side"])
	var source_rect: Rect2 = spec.get("parcel_source_rect_local", parcel_rect)
	var fence_style := str(spec.get("fence_style", "large"))

	for side in range(4):
		if fence_style == "small" and side != front_side:
			continue
		var boundary_key := _fence_boundary_key(house, source_rect, side)
		if _built_fence_boundaries.has(boundary_key):
			continue
		_built_fence_boundaries[boundary_key] = true
		var fence_rect := parcel_rect
		if int(_shared_fence_boundary_counts.get(boundary_key, 1)) > 1:
			fence_rect = source_rect
		var relative_side := (side - front_side + 4) % 4
		var rotation_degrees := _fence_rotation(side)
		for side_range in _fence_side_ranges(fence_rect, side, spec):
			var side_start: float = side_range.x
			var side_end: float = side_range.y

			if side != front_side:
				var open_path := FENCE_OPEN_LEFT_PATH if relative_side == 2 or relative_side == 3 else FENCE_OPEN_RIGHT_PATH
				_place_fence_run(fences, side, side_start, side_end, fence_rect, open_path, rotation_degrees, "FenceSide_%d" % side)
				continue

			var closed_left := _get_fence_asset(FENCE_CLOSED_LEFT_PATH)
			var closed_right := _get_fence_asset(FENCE_CLOSED_RIGHT_PATH)
			if closed_left.is_empty() or closed_right.is_empty():
				_place_fence_run(fences, side, side_start, side_end, fence_rect, FENCE_OPEN_LEFT_PATH, rotation_degrees, "FenceFrontFallback")
				continue

			var closed_left_length := _fence_asset_length(closed_left)
			var closed_right_length := _fence_asset_length(closed_right)
			var entry_center := (side_start + side_end) * 0.5
			var frontage_length := side_end - side_start
			var available_gap := frontage_length - closed_left_length - closed_right_length - 0.05
			if available_gap <= 0.0:
				_place_fence_run(fences, side, side_start, side_end, parcel_rect, FENCE_OPEN_LEFT_PATH, rotation_degrees, "FenceFrontFallback")
				continue
			var entry_gap := minf(fence_entry_gap, available_gap)
			var closed_left_center := entry_center - entry_gap * 0.5 - closed_left_length * 0.5
			var closed_right_center := entry_center + entry_gap * 0.5 + closed_right_length * 0.5
			_add_fence_piece(
				fences,
				closed_left,
				_fence_position(side, closed_left_center, fence_rect),
				rotation_degrees,
				closed_left_length,
				"EntranceClosedLeft"
			)
			_add_fence_piece(
				fences,
				closed_right,
				_fence_position(side, closed_right_center, fence_rect),
				rotation_degrees,
				closed_right_length,
				"EntranceClosedRight"
			)

			var left_gate_outer_edge := closed_left_center - closed_left_length * 0.5
			var right_gate_outer_edge := closed_right_center + closed_right_length * 0.5
			_place_fence_run(fences, side, side_start, left_gate_outer_edge, fence_rect, FENCE_OPEN_LEFT_PATH, rotation_degrees, "FenceFrontLeft")
			_place_fence_run(fences, side, right_gate_outer_edge, side_end, fence_rect, FENCE_OPEN_RIGHT_PATH, rotation_degrees, "FenceFrontRight")
	_flush_fence_batches()


func _place_fence_run(parent: Node3D, side: int, start_coordinate: float, end_coordinate: float, parcel_rect: Rect2, path: String, rotation_degrees: float, node_prefix: String) -> void:
	var run_length := end_coordinate - start_coordinate
	if run_length <= 0.05:
		return
	var asset := _get_fence_asset(path)
	if asset.is_empty():
		return
	var source_length := _fence_asset_length(asset)
	var segment_count := maxi(1, int(round(run_length / source_length)))
	var fitted_length := run_length / float(segment_count)
	for segment_index in range(segment_count):
		var coordinate := start_coordinate + fitted_length * (float(segment_index) + 0.5)
		var position := _fence_position(side, coordinate, parcel_rect)
		_add_fence_piece(parent, asset, position, rotation_degrees, fitted_length, "%s_%d" % [node_prefix, segment_index])


func _fence_side_range(parcel_rect: Rect2, side: int) -> Vector2:
	if side == 0:
		return Vector2(parcel_rect.position.x, parcel_rect.end.x)
	if side == 1:
		return Vector2(parcel_rect.position.y, parcel_rect.end.y)
	if side == 2:
		return Vector2(-parcel_rect.end.x, -parcel_rect.position.x)
	return Vector2(-parcel_rect.end.y, -parcel_rect.position.y)


func _fence_boundary_key(house: Node3D, parcel_rect: Rect2, side: int) -> String:
	var side_range := _fence_side_range(parcel_rect, side)
	var first_point := house.to_global(_fence_position(side, side_range.x, parcel_rect))
	var second_point := house.to_global(_fence_position(side, side_range.y, parcel_rect))
	var first := Vector2(minf(first_point.x, second_point.x), minf(first_point.z, second_point.z))
	var second := Vector2(maxf(first_point.x, second_point.x), maxf(first_point.z, second_point.z))
	return "%.2f,%.2f|%.2f,%.2f" % [first.x, first.y, second.x, second.y]


func _fence_side_ranges(parcel_rect: Rect2, side: int, spec: Dictionary) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	var full_range := _fence_side_range(parcel_rect, side)
	var front_side := int(spec["front_side"])
	var rear_side := (front_side + 2) % 4
	if not bool(spec.get("narrow_lot", false)) or side == front_side or side == rear_side:
		ranges.append(full_range)
		return ranges

	var occupied_start := -float(spec["width"]) * 0.5 if side == 0 or side == 2 else -float(spec["depth"]) * 0.5
	var occupied_end := float(spec["width"]) * 0.5 if side == 0 or side == 2 else float(spec["depth"]) * 0.5
	var before_end := minf(full_range.y, occupied_start)
	if before_end - full_range.x > 0.05:
		ranges.append(Vector2(full_range.x, before_end))
	var after_start := maxf(full_range.x, occupied_end)
	if full_range.y - after_start > 0.05:
		ranges.append(Vector2(after_start, full_range.y))
	return ranges


func _fence_position(side: int, tangent_coordinate: float, parcel_rect: Rect2) -> Vector3:
	var normal_distance := 0.0
	if side == 0:
		normal_distance = -parcel_rect.position.y
	elif side == 1:
		normal_distance = parcel_rect.end.x
	elif side == 2:
		normal_distance = parcel_rect.end.y
	else:
		normal_distance = -parcel_rect.position.x
	return _side_tangent(side) * tangent_coordinate + _side_normal(side) * normal_distance + Vector3(0.0, FENCE_BASE_Y, 0.0)


func _side_tangent(side: int) -> Vector3:
	if side == 0:
		return Vector3(1.0, 0.0, 0.0)
	if side == 1:
		return Vector3(0.0, 0.0, 1.0)
	if side == 2:
		return Vector3(-1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, -1.0)


func _fence_rotation(side: int) -> float:
	if side == 0:
		return 0.0
	if side == 1:
		return -90.0
	if side == 2:
		return 180.0
	return 90.0


func _get_fence_asset(path: String) -> Dictionary:
	if _fence_asset_cache.has(path):
		return _fence_asset_cache[path]
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("[HouseGenerator] No se pudo cargar valla: %s" % path)
		_fence_asset_cache[path] = {}
		return {}
	var probe := packed.instantiate() as Node3D
	if probe == null:
		push_warning("[HouseGenerator] La valla no tiene raiz Node3D: %s" % path)
		_fence_asset_cache[path] = {}
		return {}
	var local_aabb := _compute_local_aabb(probe)
	var mesh_templates: Array[Dictionary] = []
	_collect_fence_mesh_templates(probe, Transform3D.IDENTITY, mesh_templates)
	probe.free()
	if local_aabb.size.x <= 0.001:
		push_warning("[HouseGenerator] La valla no tiene longitud valida: %s" % path)
		_fence_asset_cache[path] = {}
		return {}
	var asset := {"packed": packed, "aabb": local_aabb, "mesh_templates": mesh_templates}
	_fence_asset_cache[path] = asset
	return asset


func _fence_asset_length(asset: Dictionary) -> float:
	var local_aabb: AABB = asset["aabb"]
	return maxf(local_aabb.size.x, 0.001)


func _collect_fence_mesh_templates(node: Node, relative_transform: Transform3D, output: Array[Dictionary]) -> void:
	var node_transform := relative_transform
	if node is Node3D:
		node_transform = relative_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			output.append({
				"mesh": mesh,
				"transform": node_transform,
				"material_override": (node as MeshInstance3D).material_override,
			})
	for child in node.get_children():
		_collect_fence_mesh_templates(child, node_transform, output)


func _add_fence_piece(parent: Node3D, asset: Dictionary, center: Vector3, rotation_degrees: float, target_length: float, node_name: String) -> void:
	var local_aabb: AABB = asset["aabb"]
	var source_length := maxf(local_aabb.size.x, 0.001)
	var scale_x := target_length / source_length
	var aabb_center := local_aabb.position + local_aabb.size * 0.5
	var scale := Vector3(scale_x, 1.0, 1.0)
	var centered_origin := Vector3(-aabb_center.x * scale_x, -local_aabb.position.y, -aabb_center.z)
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(rotation_degrees))
	var placement := Transform3D(rotation_basis, center) * Transform3D(Basis().scaled(scale), centered_origin)
	var asset_key := str((asset["packed"] as PackedScene).resource_path)
	var batches: Array = _active_fence_batches.get(asset_key, [])
	if batches.is_empty():
		for template_index in range((asset["mesh_templates"] as Array).size()):
			var template: Dictionary = asset["mesh_templates"][template_index]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = template["mesh"] as Mesh
			multimesh.custom_aabb = AABB(Vector3(-100.0, -10.0, -100.0), Vector3(200.0, 20.0, 200.0))
			var mesh_instance := MultiMeshInstance3D.new()
			mesh_instance.name = "%s_%d" % [asset_key.get_file().get_basename(), template_index]
			mesh_instance.multimesh = multimesh
			var material_override: Material = template.get("material_override")
			if material_override != null:
				mesh_instance.material_override = material_override
			parent.add_child(mesh_instance)
			batches.append({"multimesh": multimesh, "transform": template["transform"], "transforms": []})
		_active_fence_batches[asset_key] = batches

	for batch_value in batches:
		var batch: Dictionary = batch_value
		var transforms: Array = batch["transforms"]
		transforms.append(placement * (batch["transform"] as Transform3D))
		batch["transforms"] = transforms

	_add_fence_collision(parent, local_aabb, center, rotation_basis, target_length, node_name)


## Las vallas se renderizan con MultiMeshInstance3D (sin metodo trimesh
## automatico como MeshInstance3D.create_trimesh_collision), asi que cada
## segmento se aproxima con una caja solida - suficiente para bloquear al
## jugador, no hace falta la geometria exacta de tablones/postes. `center`
## ya es el punto de nivel de piso (Y=FENCE_BASE_Y) y horizontalmente
## centrado (ver _add_fence_piece/_fence_position), asi que el volumen real
## va de center.y a center.y + local_aabb.size.y hacia arriba.
func _add_fence_collision(parent: Node3D, local_aabb: AABB, center: Vector3, rotation_basis: Basis, target_length: float, node_name: String) -> void:
	if target_length <= 0.05:
		return
	var height := maxf(local_aabb.size.y, 0.1)
	var depth := maxf(local_aabb.size.z, 0.1)
	var body := StaticBody3D.new()
	body.name = "%s_Collision" % node_name
	body.transform = Transform3D(rotation_basis, center)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(target_length, height, depth)
	shape.shape = box
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(shape)
	parent.add_child(body)


func _flush_fence_batches() -> void:
	for batches_value in _active_fence_batches.values():
		var batches: Array = batches_value
		for batch_value in batches:
			var batch: Dictionary = batch_value
			var transforms: Array = batch["transforms"]
			var multimesh: MultiMesh = batch["multimesh"]
			multimesh.instance_count = transforms.size()
			for index in range(transforms.size()):
				multimesh.set_instance_transform(index, transforms[index] as Transform3D)


func _build_shell(house: Node3D, spec: Dictionary, width: float, depth: float, stories: int, base_y: float) -> void:
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var style: Dictionary = spec["style"]
	var front_side := int(spec["front_side"])

	for level in range(stories):
		var level_y := base_y + float(level) * WALL_HEIGHT

		for side in range(4):
			var segment_count := int(spec["width_modules"]) if side == 0 or side == 2 else int(spec["depth_modules"])
			var entrance_segment_index := _center_segment_index(segment_count) if (level == 0 and side == front_side) else -1
			for segment_index in range(segment_count):
				var segment_position := _segment_position(side, segment_index, segment_count, half_width, half_depth, level_y)
				var outward_direction := Vector3(float(_side_outward_axis(side)), 0.0, 0.0)
				if segment_index == entrance_segment_index:
					# Puerta de entrada: siempre debe abrir hacia ADENTRO de
					# la casa, nunca hacia la calle - se le pasa la normal
					# de adentro (opuesta a la normal de este lado) para que
					# _place_door calcule el signo de giro correcto.
					_add_wall_segment_with_door(house, segment_position, _side_rotation(side), "exterior", outward_direction, "EntranceDoor", WALL_MODULE_LENGTH, -_side_normal(side))
					continue
				_add_part(house, str(style["wall"]), segment_position, _side_rotation(side), "wall", "exterior", outward_direction)


func _segment_position(side: int, segment_index: int, segment_count: int, half_width: float, half_depth: float, level_y: float) -> Vector3:
	var distance := -half_width + WALL_MODULE_LENGTH * 0.5 + float(segment_index) * WALL_MODULE_LENGTH
	if side == 0:
		return Vector3(distance, level_y, -half_depth)
	if side == 1:
		return Vector3(half_width, level_y, -half_depth + WALL_MODULE_LENGTH * 0.5 + float(segment_index) * WALL_MODULE_LENGTH)
	if side == 2:
		return Vector3(distance, level_y, half_depth)
	return Vector3(-half_width, level_y, -half_depth + WALL_MODULE_LENGTH * 0.5 + float(segment_index) * WALL_MODULE_LENGTH)


## Indice del modulo mas cercano al centro (distancia 0) de una tira de N
## modulos - el mismo centro que usa la valla para su hueco de entrada, asi
## que colocar la puerta ahi garantiza que ambos coincidan.
func _center_segment_index(segment_count: int) -> int:
	var best_index := 0
	var best_offset := INF
	for segment_index in range(segment_count):
		var offset := absf(2.0 * float(segment_index) - float(segment_count) + 1.0)
		if offset < best_offset:
			best_offset = offset
			best_index = segment_index
	return best_index


func _side_normal(side: int) -> Vector3:
	if side == 0:
		return Vector3(0.0, 0.0, -1.0)
	if side == 1:
		return Vector3(1.0, 0.0, 0.0)
	if side == 2:
		return Vector3(0.0, 0.0, 1.0)
	return Vector3(-1.0, 0.0, 0.0)


func _side_rotation(side: int) -> float:
	return 90.0 if side == 0 or side == 2 else 0.0


func _side_outward_axis(side: int) -> int:
	return 1 if side == 0 or side == 1 else -1


func _side_name(side: int) -> String:
	return ["N", "E", "S", "W"][int(side)]


func _build_room_plan(house: Node3D, walls: Node3D, spec: Dictionary, width: float, depth: float, base_y: float) -> void:
	if str(spec["layout_type"]) == "open_plan":
		_build_open_plan(house, walls, spec, width, depth, base_y)
		return
	if str(spec["layout_type"]) == "direct_living":
		_build_direct_living_plan(house, walls, spec, width, depth, base_y)
		return
	_build_central_hall_plan(house, walls, spec, width, depth, base_y)


func _build_open_plan(house: Node3D, walls: Node3D, spec: Dictionary, width: float, depth: float, base_y: float) -> void:
	var front_side := int(spec["front_side"])
	var lateral_modules := int(spec["width_modules"]) if front_side == 0 or front_side == 2 else int(spec["depth_modules"])
	var inward_modules := int(spec["depth_modules"]) if front_side == 0 or front_side == 2 else int(spec["width_modules"])
	var lateral_size := float(lateral_modules) * WALL_MODULE_LENGTH
	var inward_size := float(inward_modules) * WALL_MODULE_LENGTH
	var lateral_min := -lateral_size * 0.5
	var inward_min := -inward_size * 0.5
	var lateral_max := lateral_size * 0.5
	var inward_max := inward_size * 0.5
	var outer_inward_min := inward_min
	var outer_inward_max := inward_max
	var split_modules := maxi(1, int(inward_modules / 2))
	var kitchen_start := inward_min + float(split_modules) * WALL_MODULE_LENGTH
	var side_width := lateral_size * 0.5

	_add_plan_room_floor(house, "Sala", front_side, lateral_min, outer_inward_min, side_width, kitchen_start - outer_inward_min, base_y)
	_add_plan_room_floor(house, "Cocina", front_side, lateral_min, kitchen_start, side_width, outer_inward_max - kitchen_start, base_y)
	_add_plan_room_floor(house, "Cuarto", front_side, 0.0, outer_inward_min, side_width, outer_inward_max - outer_inward_min, base_y)

	var style: Dictionary = spec["style"]
	var divider_segments := maxi(1, int(round((inward_max - outer_inward_min) / WALL_MODULE_LENGTH)))
	# El primer modulo del divisor (segment_index 0) cae justo pegado a la
	# pared frontal, exactamente donde la entrada abre (ver _build_shell /
	# _center_segment_index) - si se construyera solido, bloquearia el paso
	# desde la puerta principal (bug reportado: "la entrada cae en una
	# pared"). Se deja ese primer modulo abierto (opening_indices=[0]) para
	# formar un pequeño vestibulo entre Sala y Cuarto justo detras de la
	# entrada, y la puerta interior (si el centro calculado coincidia con
	# ese mismo modulo 0) se recorre un modulo hacia adentro.
	var open_plan_door_index := _center_segment_index(divider_segments)
	if open_plan_door_index == 0:
		open_plan_door_index = 1 if divider_segments > 1 else 0
	_add_plan_divider(walls, style, front_side, 0.0, outer_inward_min, inward_max, base_y, false, [0], open_plan_door_index)


func _build_direct_living_plan(house: Node3D, walls: Node3D, spec: Dictionary, width: float, depth: float, base_y: float) -> void:
	var front_side := int(spec["front_side"])
	var lateral_modules := int(spec["width_modules"]) if front_side == 0 or front_side == 2 else int(spec["depth_modules"])
	var inward_modules := int(spec["depth_modules"]) if front_side == 0 or front_side == 2 else int(spec["width_modules"])
	var lateral_size := float(lateral_modules) * WALL_MODULE_LENGTH
	var inward_size := float(inward_modules) * WALL_MODULE_LENGTH
	var lateral_min := -lateral_size * 0.5
	var inward_min := -inward_size * 0.5
	var lateral_max := lateral_size * 0.5
	var inward_max := inward_size * 0.5
	var outer_lateral_min := lateral_min
	var outer_lateral_max := lateral_max
	var outer_inward_min := inward_min
	var outer_inward_max := inward_max
	var split_modules := maxi(1, int(inward_modules / 2))
	var room_split := inward_min + float(split_modules) * WALL_MODULE_LENGTH
	var room_half_width := lateral_size * 0.5

	_add_plan_room_floor(house, "Sala", front_side, lateral_min, outer_inward_min, lateral_size, room_split - outer_inward_min, base_y)
	_add_plan_room_floor(house, "Cocina", front_side, lateral_min, room_split, room_half_width, inward_max - room_split, base_y)
	_add_plan_room_floor(house, "Cuarto", front_side, 0.0, room_split, room_half_width, inward_max - room_split, base_y)

	var style: Dictionary = spec["style"]
	var living_divider_segments := maxi(1, int(round((lateral_max - lateral_min) / WALL_MODULE_LENGTH)))
	_add_plan_divider(walls, style, front_side, room_split, lateral_min, lateral_max, base_y, true, [], _center_segment_index(living_divider_segments))
	_add_plan_solid_wall(walls, front_side, outer_lateral_min, lateral_min, room_split, base_y, "DirectLivingWall_L")
	_add_plan_solid_wall(walls, front_side, lateral_max, outer_lateral_max, room_split, base_y, "DirectLivingWall_R")
	_add_plan_inward_connector(walls, front_side, 0.0, room_split, outer_inward_max, base_y, "KitchenBedroomWall", true)


func _build_central_hall_plan(house: Node3D, walls: Node3D, spec: Dictionary, width: float, depth: float, base_y: float) -> void:
	var front_side := int(spec["front_side"])
	var lateral_modules := int(spec["width_modules"]) if front_side == 0 or front_side == 2 else int(spec["depth_modules"])
	var inward_modules := int(spec["depth_modules"]) if front_side == 0 or front_side == 2 else int(spec["width_modules"])
	var lateral_size := float(lateral_modules) * WALL_MODULE_LENGTH
	var inward_size := float(inward_modules) * WALL_MODULE_LENGTH
	var lateral_min := -lateral_size * 0.5
	var inward_min := -inward_size * 0.5
	var lateral_max := lateral_size * 0.5
	var inward_max := inward_size * 0.5
	var corridor_width := WALL_MODULE_LENGTH
	var corridor_half_width := corridor_width * 0.5
	var side_room_width := (lateral_size - corridor_width) * 0.5
	var split_modules := maxi(1, int(inward_modules / 2))
	var room_split := inward_min + float(split_modules) * WALL_MODULE_LENGTH
	var corridor_outer_min := inward_min
	var corridor_outer_size := inward_size
	var outer_lateral_max := lateral_max

	_add_plan_room_floor(house, "Sala", front_side, lateral_min, inward_min, side_room_width, inward_size, base_y)
	_add_plan_room_floor(house, "Pasillo", front_side, -corridor_half_width, corridor_outer_min, corridor_width, corridor_outer_size, base_y)
	_add_plan_room_floor(house, "Cocina", front_side, corridor_half_width, inward_min, side_room_width, room_split - inward_min, base_y)
	_add_plan_room_floor(house, "Cuarto", front_side, corridor_half_width, room_split, side_room_width, inward_max - room_split, base_y)

	var style: Dictionary = spec["style"]
	var opening_modules := clampi(hall_living_opening_modules, 1, maxi(1, inward_modules - 1))
	var opening_start := maxi(0, int((inward_modules - opening_modules) / 2))
	var opening_indices: Array[int] = []
	for opening_index in range(opening_modules):
		opening_indices.append(opening_start + opening_index)
	_add_plan_divider(walls, style, front_side, -corridor_half_width, inward_min, inward_max, base_y, false, opening_indices)
	var cocina_divider_segments := maxi(1, int(round((room_split - inward_min) / WALL_MODULE_LENGTH)))
	_add_plan_divider(walls, style, front_side, corridor_half_width, inward_min, room_split, base_y, false, [], _center_segment_index(cocina_divider_segments))
	var cuarto_divider_segments := maxi(1, int(round((inward_max - room_split) / WALL_MODULE_LENGTH)))
	_add_plan_divider(walls, style, front_side, corridor_half_width, room_split, inward_max, base_y, false, [], _center_segment_index(cuarto_divider_segments))
	_add_plan_solid_wall(walls, front_side, corridor_half_width, outer_lateral_max, room_split, base_y)


func _add_plan_room_floor(house: Node3D, room_name: String, front_side: int, lateral_start: float, inward_start: float, lateral_size: float, inward_size: float, base_y: float) -> void:
	var center := _plan_to_local(front_side, lateral_start + lateral_size * 0.5, inward_start + inward_size * 0.5)
	center.y = base_y + 0.025
	var floor_size := Vector3(lateral_size, 0.05, inward_size) if front_side == 0 or front_side == 2 else Vector3(inward_size, 0.05, lateral_size)
	_add_box(house, center, Vector3(maxf(floor_size.x - 0.08, 0.1), floor_size.y, maxf(floor_size.z - 0.08, 0.1)), _material_for(house, "floor"), "%sFloor" % room_name)
	if not show_debug_labels:
		return
	var label := Label3D.new()
	label.name = "%sLabel" % room_name
	label.text = room_name
	label.position = center + Vector3.UP * 0.08
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 20
	label.outline_size = 5
	label.pixel_size = 0.01
	house.add_child(label)


func _plan_to_local(front_side: int, lateral: float, inward: float) -> Vector3:
	if front_side == 0:
		return Vector3(lateral, 0.0, inward)
	if front_side == 1:
		return Vector3(-inward, 0.0, lateral)
	if front_side == 2:
		return Vector3(lateral, 0.0, -inward)
	return Vector3(inward, 0.0, lateral)


func _add_plan_divider(parent: Node3D, style: Dictionary, front_side: int, fixed_lateral: float, range_start: float, range_end: float, base_y: float, along_lateral: bool = false, opening_indices: Array[int] = [], door_segment_index: int = -1) -> void:
	var length := range_end - range_start
	var segment_count := maxi(1, int(round(length / WALL_MODULE_LENGTH)))
	for segment_index in range(segment_count):
		if opening_indices.has(segment_index):
			continue
		var along := range_start + WALL_MODULE_LENGTH * (float(segment_index) + 0.5)
		var lateral := along if along_lateral else fixed_lateral
		var inward := fixed_lateral if along_lateral else along
		var position := _plan_to_local(front_side, lateral, inward)
		position.y = base_y
		var rotation := 90.0 if front_side == 0 or front_side == 2 else 0.0
		if not along_lateral:
			rotation = 0.0 if front_side == 0 or front_side == 2 else 90.0
		if segment_index == door_segment_index:
			_add_wall_segment_with_door(parent, position, rotation, "interior", Vector3.ZERO, "InteriorDoor_%d" % segment_index)
			continue
		_add_part(parent, str(style["wall"]), position, rotation, "interior_wall")


func _add_plan_solid_wall(parent: Node3D, front_side: int, lateral_start: float, lateral_end: float, fixed_inward: float, base_y: float, node_name: String = "KitchenBedroomWall") -> void:
	var length := lateral_end - lateral_start
	var center := _plan_to_local(front_side, (lateral_start + lateral_end) * 0.5, fixed_inward)
	center.y = base_y + WALL_HEIGHT * 0.5
	var size := Vector3(length, WALL_HEIGHT, wall_thickness) if front_side == 0 or front_side == 2 else Vector3(wall_thickness, WALL_HEIGHT, length)
	_add_box(parent, center, size, _material_for(parent, "interior"), node_name)


func _add_plan_inward_connector(parent: Node3D, front_side: int, fixed_lateral: float, inward_start: float, inward_end: float, base_y: float, node_name: String, with_door: bool = false) -> void:
	var length := inward_end - inward_start
	var center := _plan_to_local(front_side, fixed_lateral, (inward_start + inward_end) * 0.5)
	center.y = base_y + WALL_HEIGHT * 0.5
	if with_door and length > 1.2:
		var door_position := Vector3(center.x, base_y, center.z)
		var rotation := 0.0 if front_side == 0 or front_side == 2 else 90.0
		_add_wall_segment_with_door(parent, door_position, rotation, "interior", Vector3.ZERO, node_name, length)
		return
	var size := Vector3(wall_thickness, WALL_HEIGHT, length) if front_side == 0 or front_side == 2 else Vector3(length, WALL_HEIGHT, wall_thickness)
	_add_box(parent, center, size, _material_for(parent, "interior"), node_name)


func _add_roof(house: Node3D, spec: Dictionary, width: float, depth: float, stories: int, base_y: float) -> void:
	var overhang: float = spec["roof_overhang"]
	var roof_y := base_y + float(stories) * WALL_HEIGHT + 0.1
	_add_box(house, Vector3(0.0, roof_y, 0.0), Vector3(width + overhang * 2.0, 0.2, depth + overhang * 2.0), _roof_material, "Roof")
	if not spec["has_roof_trim"]:
		return
	var trim_y := roof_y + 0.18
	_add_box(house, Vector3(0.0, trim_y, -depth * 0.5 - overhang * 0.5), Vector3(width + overhang, 0.18, 0.18), _material_for(house, "exterior_upper"), "RoofTrim_N")
	_add_box(house, Vector3(0.0, trim_y, depth * 0.5 + overhang * 0.5), Vector3(width + overhang, 0.18, 0.18), _material_for(house, "exterior_upper"), "RoofTrim_S")
	_add_box(house, Vector3(-width * 0.5 - overhang * 0.5, trim_y, 0.0), Vector3(0.18, 0.18, depth + overhang), _material_for(house, "exterior_upper"), "RoofTrim_W")
	_add_box(house, Vector3(width * 0.5 + overhang * 0.5, trim_y, 0.0), Vector3(0.18, 0.18, depth + overhang), _material_for(house, "exterior_upper"), "RoofTrim_E")


func _add_debug_label(house: Node3D, spec: Dictionary, stories: int, base_y: float) -> void:
	var label := Label3D.new()
	label.name = "DebugLabel"
	label.text = "%s\n%s %dm x %dm\n%dF / %s" % [
		spec["name"], spec["profile"], spec["width"], spec["depth"], stories, spec["style_name"]]
	label.position = Vector3(0.0, base_y + float(stories) * WALL_HEIGHT + 1.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 28
	label.outline_size = 7
	label.pixel_size = 0.01
	house.add_child(label)


func _add_part(parent: Node3D, path: String, position: Vector3, rotation_degrees: float, kind: String, material_category: String = "", outward_direction: Vector3 = Vector3.ZERO) -> void:
	var resolved_category := material_category
	if resolved_category.is_empty():
		resolved_category = "interior" if kind.begins_with("interior_") else "exterior"
	var part_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(rotation_degrees)), position)
	_add_wall_volume(parent, kind, resolved_category, outward_direction, part_transform)


func _create_part_socket(parent: Node3D, position: Vector3, rotation_degrees: float, kind: String) -> Node3D:
	var socket := Node3D.new()
	socket.name = "%s_%s" % [kind, parent.get_child_count()]
	socket.position = position
	socket.rotation_degrees.y = rotation_degrees
	parent.add_child(socket)
	return socket


func _wall_face_materials(parent: Node3D, material_category: String, outward_direction: Vector3, layer: String = "upper") -> Array:
	var interior_material := _material_for(parent, "interior")
	var exterior_category := "exterior_lower" if layer == "lower" else "exterior_upper"
	var exterior_material := _material_for(parent, exterior_category)
	var face_normals: Array[Vector3] = [
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, -1.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
	]
	var face_materials: Array = []
	for face_normal in face_normals:
		if material_category == "interior":
			face_materials.append(interior_material)
			continue
		if absf(face_normal.y) > 0.5:
			face_materials.append(_material_for(parent, "exterior_upper"))
			continue
		var outward_dot := face_normal.x * outward_direction.x + face_normal.z * outward_direction.z
		if outward_dot < -0.5:
			face_materials.append(interior_material)
		else:
			face_materials.append(exterior_material)
	return face_materials


func _add_layered_box(parent: Node3D, center: Vector3, size: Vector3, material_category: String, outward_direction: Vector3, node_name: String, texture_reference_size: Vector3 = Vector3.ZERO, local_transform: Transform3D = Transform3D.IDENTITY) -> void:
	if material_category != "exterior":
		_add_box(parent, center, size, _material_for(parent, material_category), node_name, [], false, texture_reference_size, Vector2(-1.0, -1.0), local_transform)
		return
	var surface_offset := outward_direction.normalized() * EXTERIOR_SURFACE_OFFSET
	var bottom := center.y - size.y * 0.5
	var top := center.y + size.y * 0.5
	if bottom < EXTERIOR_LOWER_HEIGHT:
		var lower_top := minf(top, EXTERIOR_LOWER_HEIGHT)
		var lower_height := lower_top - bottom
		if lower_height > 0.001:
			var lower_center := center + surface_offset
			lower_center.y = (bottom + lower_top) * 0.5
			var lower_face_materials := _wall_face_materials(parent, material_category, outward_direction, "lower")
			var lower_uv_range := _vertical_uv_range(bottom, lower_top, 0.0, EXTERIOR_LOWER_HEIGHT)
			_add_box(parent, lower_center, Vector3(size.x, lower_height, size.z), lower_face_materials[0] as Material, "%s_Lower" % node_name, lower_face_materials, true, texture_reference_size, lower_uv_range, local_transform)
	if top > EXTERIOR_LOWER_HEIGHT:
		var upper_bottom := maxf(bottom, EXTERIOR_LOWER_HEIGHT)
		var upper_height := top - upper_bottom
		if upper_height > 0.001:
			var upper_center := center + surface_offset
			upper_center.y = (upper_bottom + top) * 0.5
			var upper_face_materials := _wall_face_materials(parent, material_category, outward_direction, "upper")
			var upper_uv_range := _vertical_uv_range(upper_bottom, top, EXTERIOR_LOWER_HEIGHT, WALL_HEIGHT)
			_add_box(parent, upper_center, Vector3(size.x, upper_height, size.z), upper_face_materials[0] as Material, "%s_Upper" % node_name, upper_face_materials, true, texture_reference_size, upper_uv_range, local_transform)


func _vertical_uv_range(bottom: float, top: float, layer_bottom: float, layer_top: float) -> Vector2:
	var layer_height := maxf(layer_top - layer_bottom, 0.001)
	var uv_bottom := 1.0 - (bottom - layer_bottom) / layer_height
	var uv_top := 1.0 - (top - layer_bottom) / layer_height
	return Vector2(clampf(uv_bottom, 0.0, 1.0), clampf(uv_top, 0.0, 1.0))


func _add_wall_volume(parent: Node3D, kind: String, material_category: String, outward_direction: Vector3, local_transform: Transform3D = Transform3D.IDENTITY) -> void:
	var texture_reference_size := Vector3(wall_thickness, WALL_HEIGHT, WALL_MODULE_LENGTH)
	if kind == "wall" or kind == "interior_wall":
		_add_layered_box(parent, Vector3(0.0, WALL_HEIGHT * 0.5, 0.0), Vector3(wall_thickness, WALL_HEIGHT, WALL_MODULE_LENGTH), material_category, outward_direction, "WallVolume", texture_reference_size, local_transform)


## Construye un tramo de pared con un hueco de puerta: un dintel arriba y,
## si la puerta no llena todo el ancho del tramo, dos jambas laterales -
## luego coloca ahi mismo una de las 15 puertas del pack, parada en el piso
## y escalada a DOOR_HEIGHT_TARGET. `segment_length` es el ancho total del
## tramo de pared (normalmente WALL_MODULE_LENGTH, pero los conectores no
## modulares pueden pasar su propio largo).
func _add_wall_segment_with_door(parent: Node3D, position: Vector3, rotation_degrees: float, material_category: String, outward_direction: Vector3, node_name: String, segment_length: float = WALL_MODULE_LENGTH, inward_direction: Vector3 = Vector3.ZERO) -> void:
	var local_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(rotation_degrees)), position)
	var texture_reference_size := Vector3(wall_thickness, WALL_HEIGHT, WALL_MODULE_LENGTH)
	var door_variant := _pick_door_variant()
	var template_size := _door_template_size(door_variant)
	if template_size == Vector3.ZERO:
		_add_layered_box(parent, Vector3(0.0, WALL_HEIGHT * 0.5, 0.0), Vector3(wall_thickness, WALL_HEIGHT, segment_length), material_category, outward_direction, node_name, texture_reference_size, local_transform)
		return

	var scale_factor := DOOR_HEIGHT_TARGET / maxf(template_size.y, 0.001)
	var door_height := DOOR_HEIGHT_TARGET
	var door_width := minf(template_size.x * scale_factor, segment_length - wall_thickness * 2.0)
	var header_height := maxf(WALL_HEIGHT - door_height, 0.05)

	_add_layered_box(parent, Vector3(0.0, door_height + header_height * 0.5, 0.0), Vector3(wall_thickness, header_height, segment_length), material_category, outward_direction, "%s_Header" % node_name, texture_reference_size, local_transform)

	var jamb_width := (segment_length - door_width) * 0.5
	if jamb_width > 0.05:
		_add_layered_box(parent, Vector3(0.0, door_height * 0.5, -(door_width * 0.5 + jamb_width * 0.5)), Vector3(wall_thickness, door_height, jamb_width), material_category, outward_direction, "%s_JambA" % node_name, texture_reference_size, local_transform)
		_add_layered_box(parent, Vector3(0.0, door_height * 0.5, door_width * 0.5 + jamb_width * 0.5), Vector3(wall_thickness, door_height, jamb_width), material_category, outward_direction, "%s_JambB" % node_name, texture_reference_size, local_transform)

	_place_door(parent, door_variant, position, rotation_degrees, scale_factor, node_name, door_width, inward_direction)


## Elige una de las 15 variantes de puerta del pack (deterministico via el
## RNG de la casa, para que la generacion siga siendo reproducible por seed).
func _pick_door_variant() -> String:
	return DOOR_NODE_NAMES[_rng.randi_range(0, DOOR_NODE_NAMES.size() - 1)]


## Carga (una sola vez, cacheado) el FBX compartido de las 15 puertas y
## devuelve la malla plantilla pedida por nombre de nodo - mismo patron que
## `_duplicate_sewer_prop` en city_decoration.gd: instancia oculta cacheada
## + `find_child` + `duplicate()` en el llamador.
func _get_door_mesh_template(node_name: String) -> MeshInstance3D:
	if _door_pack_load_failed:
		return null
	if _door_pack_root == null or not is_instance_valid(_door_pack_root):
		var scene: PackedScene = load(DOOR_PACK_SCENE_PATH)
		if scene == null:
			push_warning("HouseGenerator: no se pudo cargar el pack de puertas en %s" % DOOR_PACK_SCENE_PATH)
			_door_pack_load_failed = true
			return null
		_door_pack_root = scene.instantiate()
		add_child(_door_pack_root)
		_door_pack_root.visible = false
	return _door_pack_root.find_child(node_name, true, false) as MeshInstance3D


func _door_template_size(node_name: String) -> Vector3:
	var template := _get_door_mesh_template(node_name)
	if template == null or template.mesh == null:
		return Vector3.ZERO
	return template.mesh.get_aabb().size


## Duplica la malla de puerta elegida, la reinicia a su propio origen local
## (el mesh ya viene centrado en su propio espacio local), la levanta para
## que quede parada sobre el piso, y arma una puerta INTERACTIVA real: un
## pivote (bisagra) ubicado en el BORDE del hueco (no en el centro, como
## una puerta de verdad) con una hoja (StaticBody3D con colision) que
## InteractiveDoor puede girar dinamicamente y detener contra obstaculos.
## Ver world/city/interactive_door.gd.
func _place_door(parent: Node3D, node_name: String, position: Vector3, rotation_degrees: float, scale_factor: float, node_label: String, door_width: float, inward_direction: Vector3 = Vector3.ZERO) -> void:
	var template := _get_door_mesh_template(node_name)
	if template == null:
		return
	var instance := template.duplicate() as MeshInstance3D
	instance.transform = Transform3D.IDENTITY
	var local_aabb := instance.mesh.get_aabb() if instance.mesh != null else AABB()

	# La bisagra vive medio ancho de puerta ANTES del centro del tramo,
	# medida a lo largo del eje tangente de la pared (mismo eje Z local que
	# usan el dintel/jambas de _add_wall_segment_with_door, con la rotacion
	# ORIGINAL del tramo, sin el +90 de abajo).
	var hinge_offset := Basis(Vector3.UP, deg_to_rad(rotation_degrees)) * Vector3(0.0, 0.0, -door_width * 0.5)

	var pivot: Node3D = InteractiveDoorScript.new()
	pivot.name = "%s_Door" % node_label
	parent.add_child(pivot)
	pivot.position = position + hinge_offset
	# +90: la malla de puerta del pack trae su propio ancho a lo largo de un
	# eje local distinto al de la pared (bug reportado: la puerta quedaba
	# girada 90 grados y no encajaba en el hueco) - este offset alinea la
	# hoja cerrada al ras del hueco de la pared.
	pivot.rotation_degrees.y = rotation_degrees + 90.0

	var slab := StaticBody3D.new()
	slab.name = "DoorSlab"
	slab.set_script(DoorSlabScript)
	pivot.add_child(slab)
	# Recentra la hoja respecto a la bisagra: en el sistema local del propio
	# pivote (que ya trae el +90 de arriba), el punto que estaba en
	# "position" (centro original del tramo, donde vive el mesh visual
	# probado y validado antes de esta refactorizacion) queda en
	# Vector3(-door_width * 0.5, 0, 0) - verificado numericamente
	# (Basis(UP,90)*Z == +X, Basis(UP,-90)*Z == -X en Godot).
	slab.position = Vector3(-door_width * 0.5, 0.0, 0.0)
	slab.scale = Vector3.ONE * scale_factor

	instance.position = Vector3(0.0, -local_aabb.position.y, 0.0)
	slab.add_child(instance)

	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	# Margen de seguridad (en metros de MUNDO, convertido a unidades locales
	# de la malla dividiendo por scale_factor) para que la caja de colision
	# no quede tocando/incrustada en las jambas, el dintel o el piso apenas
	# se genera - un contacto EXACTO (distancia 0) se reporta como
	# "solapado" en intersect_shape, lo que dejaria la puerta reportandose
	# obstruida en reposo (cerrada) para siempre. Ademas el ancho real
	# construido en la pared (door_width) puede ser mas angosto que el
	# ancho nativo de la malla (segmentos justos, ver el minf/clamp en
	# _add_wall_segment_with_door), asi que tambien se recorta a eso.
	var margin_raw := DOOR_COLLISION_MARGIN_WORLD / maxf(scale_factor, 0.001)
	var raw_width_available := door_width / maxf(scale_factor, 0.001)
	var collision_size := local_aabb.size - Vector3.ONE * margin_raw * 2.0
	collision_size.x = minf(collision_size.x, raw_width_available - margin_raw * 2.0)
	collision_size = collision_size.max(Vector3.ONE * 0.0001)
	# La bisagra (origen del pivote) queda exactamente sobre el borde
	# interior de la jamba contigua (mismo punto matematico) - una puerta
	# real tiene la bisagra un poco METIDA respecto al canto para poder
	# girar sin rozar. Se recorta ese colchon SOLO del lado de la bisagra
	# (no de los dos lados por igual, que le robaria margen al borde libre)
	# dejando el borde libre donde estaba: se reduce el ancho y se corre el
	# centro la mitad de lo recortado hacia el borde libre.
	var hinge_clearance_raw := DOOR_HINGE_CLEARANCE_WORLD / maxf(scale_factor, 0.001)
	hinge_clearance_raw = minf(hinge_clearance_raw, collision_size.x * 0.5)
	collision_size.x -= hinge_clearance_raw
	collision_size = collision_size.max(Vector3.ONE * 0.0001)
	# No sabemos a priori si el contacto sobrante es contra el piso (borde
	# inferior) o el dintel (borde superior), asi que este colchon se
	# recorta de AMBOS lados del eje Y por igual (deja el centro donde
	# estaba).
	var floor_clearance_raw := DOOR_FLOOR_CLEARANCE_WORLD / maxf(scale_factor, 0.001)
	collision_size.y -= floor_clearance_raw * 2.0
	collision_size = collision_size.max(Vector3.ONE * 0.0001)
	box_shape.size = collision_size
	collision.shape = box_shape
	# La bisagra (pivote) cae en +door_width/2 dentro del espacio local de
	# la hoja (ver slab.position arriba) - se corre el centro de la caja en
	# X NEGATIVO (hacia el borde libre, lejos de la bisagra).
	collision.position = instance.position + Vector3(-hinge_clearance_raw * 0.5, 0.0, 0.0)
	slab.add_child(collision)

	# Signo de apertura: +1 gira hacia el lado "positivo" del pivote, -1
	# hacia el opuesto. Si nos pasaron una direccion de adentro real (solo
	# las puertas de entrada la tienen - las interiores pasan ZERO porque
	# ambos lados son "adentro"), se compara contra la direccion en la que
	# barre la hoja para un angulo positivo chico, y se seguiria: si mueve
	# hacia afuera, se invierte el signo para que la puerta siempre abra
	# hacia adentro de la casa (bug reportado: se abria hacia la calle).
	var open_sign := 1.0
	if inward_direction != Vector3.ZERO:
		var base_deg := rotation_degrees + 90.0
		var swing_direction := Basis(Vector3.UP, deg_to_rad(base_deg)) * Vector3(0.0, 0.0, 1.0)
		if swing_direction.dot(inward_direction) < 0.0:
			open_sign = -1.0

	pivot.setup(slab, collision, open_sign)


func _apply_material(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		var mesh := (root as MeshInstance3D).mesh
		if mesh != null:
			for surface_index in range(mesh.get_surface_count()):
				(root as MeshInstance3D).set_surface_override_material(surface_index, material)
	for child in root.get_children():
		_apply_material(child, material)


func _add_box(parent: Node3D, position: Vector3, size: Vector3, material: Material, node_name: String, face_materials: Array = [], vertical_stretch: bool = false, texture_reference_size: Vector3 = Vector3.ZERO, vertical_uv_range: Vector2 = Vector2(-1.0, -1.0), local_transform: Transform3D = Transform3D.IDENTITY) -> void:
	var resolved_materials: Array = face_materials
	if resolved_materials.size() != 6:
		resolved_materials = []
		for face_index in range(6):
			resolved_materials.append(material)
	_append_box_to_batch(parent, size, position, resolved_materials, vertical_stretch, texture_reference_size, vertical_uv_range, local_transform)


func _append_box_to_batch(parent: Node3D, size: Vector3, position: Vector3, resolved_materials: Array, vertical_stretch: bool, texture_reference_size: Vector3, vertical_uv_range: Vector2, local_transform: Transform3D = Transform3D.IDENTITY) -> void:
	var parent_to_house := _active_house.global_transform.affine_inverse() * parent.global_transform
	var half_size := size * 0.5
	var minimum := -half_size
	var maximum := half_size
	var face_vertices: Array = [
		PackedVector3Array([
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(minimum.x, minimum.y, minimum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
		]),
		PackedVector3Array([
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
		]),
	]
	var face_normals: Array[Vector3] = [
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, -1.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
	]
	var face_uv_sizes: Array[Vector2] = [
		Vector2(size.z, size.y),
		Vector2(size.z, size.y),
		Vector2(size.x, size.z),
		Vector2(size.x, size.z),
		Vector2(size.x, size.y),
		Vector2(size.x, size.y),
	]
	var has_texture_reference := texture_reference_size.x > 0.0 or texture_reference_size.z > 0.0
	var reference_min := -texture_reference_size * 0.5
	var reference_max := texture_reference_size * 0.5
	var box_min := position - half_size
	var box_max := position + half_size

	for face_index in range(face_vertices.size()):
		var uv_size: Vector2 = face_uv_sizes[face_index] / TEXTURE_TILE_METERS
		var is_side_face := face_index == 0 or face_index == 1 or face_index == 4 or face_index == 5
		var uv_u_offset := 0.0
		var uv_v_bottom := uv_size.y
		var uv_v_top := 0.0
		if has_texture_reference:
			match face_index:
				0:
					uv_u_offset = (box_min.z - reference_min.z) / TEXTURE_TILE_METERS
				1:
					uv_u_offset = (reference_max.z - box_max.z) / TEXTURE_TILE_METERS
				4:
					uv_u_offset = (box_min.x - reference_min.x) / TEXTURE_TILE_METERS
				5:
					uv_u_offset = (reference_max.x - box_max.x) / TEXTURE_TILE_METERS
		if vertical_stretch and is_side_face:
			uv_v_bottom = 1.0
			uv_v_top = 0.0
		if vertical_uv_range.x >= 0.0 and vertical_uv_range.y >= 0.0 and is_side_face:
			uv_v_bottom = vertical_uv_range.x
			uv_v_top = vertical_uv_range.y
		var face_uvs: Array = []
		if is_side_face:
			face_uvs = [
				Vector2(uv_u_offset, uv_v_bottom),
				Vector2(uv_u_offset, uv_v_top),
				Vector2(uv_u_offset + uv_size.x, uv_v_top),
				Vector2(uv_u_offset + uv_size.x, uv_v_bottom),
			]
		else:
			face_uvs = [
				Vector2(0.0, 0.0),
				Vector2(0.0, uv_size.y),
				Vector2(uv_size.x, uv_size.y),
				Vector2(uv_size.x, 0.0),
			]

		var material := resolved_materials[face_index] as Material
		if material == null:
			material = _floor_material
		var material_key := material.get_instance_id()
		var surface: Dictionary = _active_box_batch.get(material_key, {})
		if surface.is_empty():
			surface = {
				"material": material,
				"vertices": [],
				"normals": [],
				"uvs": [],
				"indices": [],
			}
		var vertices: Array = surface["vertices"]
		var normals: Array = surface["normals"]
		var uvs: Array = surface["uvs"]
		var indices: Array = surface["indices"]
		var vertex_offset := vertices.size()
		for vertex_index in range(4):
			vertices.append(parent_to_house * local_transform * (face_vertices[face_index][vertex_index] + position))
			normals.append((parent_to_house.basis * local_transform.basis * face_normals[face_index]).normalized())
			uvs.append(face_uvs[vertex_index])
		indices.append(vertex_offset)
		indices.append(vertex_offset + 1)
		indices.append(vertex_offset + 2)
		indices.append(vertex_offset)
		indices.append(vertex_offset + 2)
		indices.append(vertex_offset + 3)
		surface["vertices"] = vertices
		surface["normals"] = normals
		surface["uvs"] = uvs
		surface["indices"] = indices
		_active_box_batch[material_key] = surface


func _flush_box_batch(parent: Node3D) -> void:
	if _active_box_batch.is_empty():
		return
	var batch_root := Node3D.new()
	batch_root.name = "BatchedGeometry"
	parent.add_child(batch_root)
	var surface_index := 0
	for surface_value in _active_box_batch.values():
		var surface: Dictionary = surface_value
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(surface["vertices"])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(surface["normals"])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(surface["uvs"])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(surface["indices"])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "BoxBatch_%d" % surface_index
		mesh_instance.mesh = mesh
		mesh_instance.material_override = surface["material"] as Material
		batch_root.add_child(mesh_instance)
		# Colision solida para cimiento/paredes exteriores/paredes interiores/
		# techo, todo en un solo trimesh que calza exacto con la malla visible
		# (mismo patron que ChunkManager usa para el terreno) - respeta los
		# huecos de puertas/ventanas porque esos huecos ya no generan geometria
		# aqui, asi que el jugador puede seguir entrando por ellos.
		mesh_instance.create_trimesh_collision()
		surface_index += 1
	_active_box_batch.clear()


func _create_box_mesh(size: Vector3, vertical_stretch: bool = false, texture_reference_size: Vector3 = Vector3.ZERO, box_position: Vector3 = Vector3.ZERO, vertical_uv_range: Vector2 = Vector2(-1.0, -1.0)) -> ArrayMesh:
	var half_size := size * 0.5
	var minimum := -half_size
	var maximum := half_size
	var face_vertices: Array = [
		PackedVector3Array([
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(minimum.x, minimum.y, minimum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
		]),
		PackedVector3Array([
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
		]),
		PackedVector3Array([
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
		]),
	]
	var face_normals: Array[Vector3] = [
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, -1.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
	]
	var face_uv_sizes: Array[Vector2] = [
		Vector2(size.z, size.y),
		Vector2(size.z, size.y),
		Vector2(size.x, size.z),
		Vector2(size.x, size.z),
		Vector2(size.x, size.y),
		Vector2(size.x, size.y),
	]

	var mesh := ArrayMesh.new()
	var has_texture_reference := texture_reference_size.x > 0.0 or texture_reference_size.z > 0.0
	var reference_min := -texture_reference_size * 0.5
	var reference_max := texture_reference_size * 0.5
	var box_min := box_position - half_size
	var box_max := box_position + half_size
	for face_index in range(face_vertices.size()):
		var uv_size: Vector2 = face_uv_sizes[face_index] / TEXTURE_TILE_METERS
		var is_side_face := face_index == 0 or face_index == 1 or face_index == 4 or face_index == 5
		var uv_u_offset := 0.0
		var uv_v_bottom := uv_size.y
		var uv_v_top := 0.0
		if has_texture_reference:
			match face_index:
				0:
					uv_u_offset = (box_min.z - reference_min.z) / TEXTURE_TILE_METERS
				1:
					uv_u_offset = (reference_max.z - box_max.z) / TEXTURE_TILE_METERS
				4:
					uv_u_offset = (box_min.x - reference_min.x) / TEXTURE_TILE_METERS
				5:
					uv_u_offset = (reference_max.x - box_max.x) / TEXTURE_TILE_METERS
		if vertical_stretch and is_side_face:
			uv_v_bottom = 1.0
			uv_v_top = 0.0
		if vertical_uv_range.x >= 0.0 and vertical_uv_range.y >= 0.0 and is_side_face:
			uv_v_bottom = vertical_uv_range.x
			uv_v_top = vertical_uv_range.y
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = face_vertices[face_index]
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
			face_normals[face_index],
			face_normals[face_index],
			face_normals[face_index],
			face_normals[face_index],
		])
		if is_side_face:
			arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
				Vector2(uv_u_offset, uv_v_bottom),
				Vector2(uv_u_offset, uv_v_top),
				Vector2(uv_u_offset + uv_size.x, uv_v_top),
				Vector2(uv_u_offset + uv_size.x, uv_v_bottom),
			])
		else:
			arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
				Vector2(0.0, 0.0),
				Vector2(0.0, uv_size.y),
				Vector2(uv_size.x, uv_size.y),
				Vector2(uv_size.x, 0.0),
			])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _compute_local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var relative_transform: Transform3D = entry[1]
		if node is VisualInstance3D:
			var relative_aabb: AABB = relative_transform * (node as VisualInstance3D).get_aabb()
			if not initialized:
				result = relative_aabb
				initialized = true
			else:
				result = result.merge(relative_aabb)
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, relative_transform * (child as Node3D).transform])
			else:
				stack.append([child, relative_transform])
	return result
