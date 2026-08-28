extends Node3D
class_name CityDecoration
## Reparte basura y detalles sueltos por la ciudad para que se sienta
## "viva" (pero claramente abandonada): en lotes baldios (parcelas que
## HouseGenerator dejo sin casa via vacant_lot_probability, ver
## HouseGenerator.vacant_parcels) tira montones/bolsas de basura variados
## -no en TODOS, ver vacant_lot_trash_chance, el pedido explicito fue "no
## siempre tiene que ser asi"- y ocasionalmente un dumpster grande en los
## lotes mas amplios; afuera de algunas casas (house_trash_can_chance)
## deja un bote/tacho de basura cerca de la banqueta, a veces con 1-2
## bolsas sueltas al lado que "no cupieron".
##
## Reusa 3 fuentes de props ya presentes en el proyecto (sin agregar
## ningun asset nuevo):
##  - assets/URBAN/URBAN/Litter/Trash/ - bolsas y montones sueltos.
##  - assets/URBAN/URBAN/Litter/TrashCan/ + "Metal trashcan"/ - botes,
##    variantes cerradas/abiertas/desbordadas.
##  - assets/URBAN/URBAN/Litter/Dumpsters/ - contenedores grandes, solo
##    para lotes baldios con area suficiente.
##  - assets/drenaje/Models/Sewers.fbx - 52 nodos sueltos SIN el prefijo
##    "Serwers" (Trash_*/debris_*/Garbage_bag/Box_T/Bricks/Tire/etc), la
##    MISMA lista ya validada y usada como props en
##    DrainageDungeonGenerator.PROP_NAMES - se duplican esos nodos en vez
##    de instanciar una escena propia (ver _duplicate_sewer_prop).
##
## Se crea como hijo de CityBlockGenerator (mismo patron que
## HouseGenerator) y generate_decorations(house_generator) se llama UNA
## sola vez, despues de que HouseGenerator ya termino de generar (ver
## CityBlockGenerator._run_decoration_pass, encadenado via call_deferred
## para garantizar el orden) - lee generated_houses y vacant_parcels
## directo de esa instancia, en el mismo espacio local (este nodo tampoco
## tiene rotacion/offset propio respecto a CityBlockGenerator).

const SEWERS_SCENE_PATH := "res://assets/drenaje/Models/Sewers.fbx"

## Mismo pack de arboles/arbustos que ya usa ChunkManager para el bosque
## silvestre (world/chunk_manager.gd: TREE_MODELS_DIR/TREE_TEXTURES_DIR) -
## se reusan tal cual, sin agregar ningun asset nuevo, para poblar patios y
## lotes baldios de la ciudad.
const TREE_MODELS_DIR := "res://assets/tree_pack_1.1/tree_pack_1.1/models/"
const TREE_TEXTURES_DIR := "res://assets/tree_pack_1.1/tree_pack_1.1/textures/"
const TREE_MODEL_COUNT := 36

## Props sueltos para lotes baldios: montones y bolsas de basura (varios
## colores/tamaños, pack URBAN) - deliberadamente NO se usan los dumpsters
## grandes aqui (ver VACANT_LOT_LARGE_SCENES, se ven raros tirados sueltos
## en medio de un lote sin pared/muro contra la que apoyarse).
const VACANT_LOT_SCENES: Array[PackedScene] = [
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashpile_1.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashpile_2.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashbag_1.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashbag_1_blue.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashbag_2.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashbag_2_white.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashbag_3.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Trash/trashbag_3_red.fbx"),
]

## Contenedores grandes - solo para lotes baldios con area suficiente (ver
## vacant_lot_min_area_for_dumpster), apoyados cerca de una esquina del
## lote en vez de al centro (como se veria un dumpster real de callejon).
const VACANT_LOT_LARGE_SCENES: Array[PackedScene] = [
	preload("res://assets/URBAN/URBAN/Litter/Dumpsters/dumpster_full_no_lid.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Dumpsters/dumpster_lid_closed.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Dumpsters/dumpster_diagonal_full_open.fbx"),
]

## Botes/tachos de basura para dejar afuera de algunas casas, cerca de la
## banqueta - variedad de estado (cerrado/abierto/desbordado) y de modelo
## (plastico clasico, alt1/alt2, metalico golpeado) para que no se vean
## todos iguales.
const HOUSE_TRASH_CAN_SCENES: Array[PackedScene] = [
	preload("res://assets/URBAN/URBAN/Litter/TrashCan/trash_can.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/TrashCan/trash_can_open.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/TrashCan/trash_can_overflowing.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/TrashCan/trash_can_alt1.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/TrashCan/trash_can_alt2_overflowing.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Metal trashcan/metaltrashcan_open.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Metal trashcan/metaltrashcan_beaten.fbx"),
	preload("res://assets/URBAN/URBAN/Litter/Metal trashcan/metaltrashcan_beaten_overflowing.fbx"),
]

## Los mismos 52 nodos sueltos (sin el prefijo "Serwers") que
## DrainageDungeonGenerator.PROP_NAMES ya usa como props de basura/
## escombros - se duplican del template Sewers.fbx (ver
## _duplicate_sewer_prop), no son escenas propias.
const SEWER_PROP_NAMES: Array[String] = [
	"Trash", "Trash_001", "Trash_002", "Trash_003", "Trash_004", "Trash_005",
	"Trash_006", "Trash_007", "Trash_008", "Trash_009", "Trash_010",
	"Trash_011", "Trash_012", "Trash_013", "Trash_M", "Trash_M_01",
	"debris", "debris_01", "debris_02", "debris_03", "debris_04", "debris_05",
	"Garbage_bag", "Garbage_bag_001", "Box_T", "Box_T_01", "Box_T_02",
	"Box_T_03", "Bricks", "Brick", "Tire", "Cylinder", "TB",
]

@export var rng_seed: int = 0

@export_group("Lotes baldios (basura suelta)")
@export var scatter_vacant_lots: bool = true
## Probabilidad de que un lote baldio dado TENGA basura - pedido explicito
## del diseño: "no siempre tiene que ser asi", algunos lotes vacios se
## quedan simplemente vacios/con pasto.
@export_range(0.0, 1.0, 0.05) var vacant_lot_trash_chance: float = 0.6
@export_range(0, 12, 1) var vacant_lot_props_min: int = 2
@export_range(0, 12, 1) var vacant_lot_props_max: int = 6
## Que fraccion de los props sueltos de un lote sale del pack de drenaje
## (escombros/ladrillos/llantas, ver SEWER_PROP_NAMES) en vez de bolsas/
## montones URBAN - 0 = solo URBAN, 1 = solo drenaje. Mezclar ambos da mas
## variedad que usar un solo pack.
@export_range(0.0, 1.0, 0.05) var vacant_lot_sewer_prop_ratio: float = 0.35
## A partir de este tamaño (m², sobre el rect ya con el mismo inset que
## usan las casas) un lote baldio puede ademas recibir UN dumpster grande
## cerca de una esquina - lotes chicos no tienen espacio para que se vea
## bien.
@export var vacant_lot_min_area_for_dumpster: float = 40.0
@export_range(0.0, 1.0, 0.05) var vacant_lot_dumpster_chance: float = 0.25
@export_range(0.5, 5.0, 0.1) var vacant_lot_dumpster_edge_inset: float = 1.5

@export_group("Botes de basura afuera de casas")
@export var scatter_house_trash_cans: bool = true
@export_range(0.0, 1.0, 0.05) var house_trash_can_chance: float = 0.4
## Cuanto se acerca el bote al borde del lote (la banqueta) - metros desde
## el borde del parcel_rect (el mismo rect que usa HouseGenerator, ya con
## su inset), no desde el centro del lote.
@export_range(0.2, 4.0, 0.1) var house_trash_can_edge_inset: float = 1.0
## Probabilidad de que, ademas del bote, se tire 1-2 bolsas sueltas al
## lado (basura que "no cupo" en el bote) - pequeño detalle extra pedido
## explicitamente ("pequeños detalles asi, para dar vida al mundo").
@export_range(0.0, 1.0, 0.05) var house_loose_bag_chance: float = 0.35

@export_group("Arboles en patios y lotes")
@export var scatter_yard_trees: bool = true
## Probabilidad de que un patio (el area libre del lote de una casa, fuera
## de la huella de la casa) tenga algun arbol.
@export_range(0.0, 1.0, 0.05) var house_yard_tree_chance: float = 0.5
@export_range(0, 4, 1) var house_yard_tree_min: int = 1
@export_range(0, 4, 1) var house_yard_tree_max: int = 2
## Probabilidad de que un lote baldio tenga arboles (independiente de si ya
## le toco basura - un lote puede tener ambos, solo basura, solo arboles, o
## ninguno).
@export_range(0.0, 1.0, 0.05) var vacant_lot_tree_chance: float = 0.45
@export_range(0, 5, 1) var vacant_lot_tree_min: int = 1
@export_range(0, 5, 1) var vacant_lot_tree_max: int = 3
## Cuanto se mantienen alejados los arboles del borde del lote/parcela -
## ahi es justo donde va la reja (ver HouseGenerator._build_fence_perimeter,
## usa el mismo parcel_rect) - asi ningun arbol termina "en medio de una
## valla".
@export_range(0.5, 5.0, 0.1) var yard_tree_edge_clearance: float = 1.5
## Margen extra alrededor de la huella de la casa (mas alla de sus propias
## paredes) para que ningun arbol quede pegado o encima de la construccion.
@export_range(0.0, 3.0, 0.1) var yard_tree_house_clearance: float = 1.0
@export_range(0.3, 2.0, 0.05) var yard_tree_scale_min: float = 0.7
@export_range(0.3, 2.0, 0.05) var yard_tree_scale_max: float = 1.1
## Intentos de reubicacion al azar por arbol antes de rendirse (lotes chicos
## o con la casa ocupando casi todo el patio pueden no tener espacio libre).
@export_range(1, 20, 1) var yard_tree_placement_attempts: int = 10

var _rng: RandomNumberGenerator
var _generated_root: Node3D
var _sewer_template: Node3D
var _tree_scenes: Array[PackedScene] = []
var _tree_textures: Array[Texture2D] = []


## Punto de entrada unico - lo llama CityBlockGenerator._run_decoration_pass
## despues de que house_generator.generate_houses() ya termino (ver
## comentario de clase). No se auto-genera en _ready(): siempre hace falta
## la referencia real al HouseGenerator ya generado.
func generate_decorations(house_generator: HouseGenerator) -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.free()
	_generated_root = Node3D.new()
	_generated_root.name = "GeneratedDecorations"
	add_child(_generated_root)

	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed

	if house_generator == null:
		return

	var vacant_lots_decorated := 0
	var vacant_props_placed := 0
	var house_trash_cans_placed := 0

	if scatter_vacant_lots:
		for parcel in house_generator.vacant_parcels:
			var placed := _scatter_vacant_lot(parcel)
			if placed > 0:
				vacant_lots_decorated += 1
				vacant_props_placed += placed

	if scatter_house_trash_cans:
		for spec in house_generator.generated_houses:
			if _scatter_house_trash_can(spec):
				house_trash_cans_placed += 1

	var trees_placed := 0
	if scatter_yard_trees:
		_load_tree_scenes()
		for spec in house_generator.generated_houses:
			trees_placed += _scatter_house_yard_trees(spec)
		for parcel in house_generator.vacant_parcels:
			trees_placed += _scatter_vacant_lot_trees(parcel)

	_free_sewer_template()

	print("[CityDecoration] %d/%d lotes baldios con basura (%d props), %d casas con bote de basura, %d arboles en patios/lotes (seed=%d)" % [
		vacant_lots_decorated, house_generator.vacant_parcels.size(), vacant_props_placed,
		house_trash_cans_placed, trees_placed, rng_seed])


## Tira props sueltos dentro del rect del lote (con un margen para no
## quedar pegados a la reja/vereda) y, si el lote es grande, quiza suma un
## dumpster cerca de una esquina. Devuelve cuantos props en total se
## colocaron (0 si el sorteo de vacant_lot_trash_chance no toco este lote).
func _scatter_vacant_lot(parcel: Dictionary) -> int:
	if _rng.randf() >= vacant_lot_trash_chance:
		return 0

	var rect: Rect2 = parcel.get("rect", Rect2())
	if rect.size.x <= 0.6 or rect.size.y <= 0.6:
		return 0

	var placed := 0
	var margin_x := rect.size.x * 0.15
	var margin_z := rect.size.y * 0.15
	var count := _rng.randi_range(vacant_lot_props_min, vacant_lot_props_max)
	for i in range(count):
		var local_x := _rng.randf_range(rect.position.x + margin_x, rect.position.x + rect.size.x - margin_x)
		var local_z := _rng.randf_range(rect.position.y + margin_z, rect.position.y + rect.size.y - margin_z)
		var instance: Node3D = null
		if _rng.randf() < vacant_lot_sewer_prop_ratio:
			instance = _duplicate_sewer_prop(SEWER_PROP_NAMES[_rng.randi_range(0, SEWER_PROP_NAMES.size() - 1)])
		if instance == null:
			var scene: PackedScene = VACANT_LOT_SCENES[_rng.randi_range(0, VACANT_LOT_SCENES.size() - 1)]
			instance = scene.instantiate()
		_place_prop(instance, local_x, local_z, _rng.randf_range(0.0, TAU), _rng.randf_range(0.85, 1.25))
		placed += 1

	if rect.size.x * rect.size.y >= vacant_lot_min_area_for_dumpster and _rng.randf() < vacant_lot_dumpster_chance:
		var corner := _random_corner_point(rect, vacant_lot_dumpster_edge_inset)
		var dumpster_scene: PackedScene = VACANT_LOT_LARGE_SCENES[_rng.randi_range(0, VACANT_LOT_LARGE_SCENES.size() - 1)]
		var dumpster := dumpster_scene.instantiate()
		_place_prop(dumpster, corner.x, corner.y, _rng.randf_range(0.0, TAU), _rng.randf_range(0.95, 1.1))
		placed += 1

	return placed


## Deja un bote de basura cerca de la banqueta (el borde del lote que
## mira a la calle, ver front_side) de una casa ya generada, y a veces
## 1-2 bolsas sueltas al lado. Devuelve true si en efecto se coloco algo
## (el sorteo de house_trash_can_chance eligio esta casa).
func _scatter_house_trash_can(spec: Dictionary) -> bool:
	if _rng.randf() >= house_trash_can_chance:
		return false

	var parcel_rect: Rect2 = spec.get("parcel_rect", Rect2())
	if parcel_rect.size.x <= 0.6 or parcel_rect.size.y <= 0.6:
		return false

	var front_side: int = int(spec.get("front_side", 0))
	var point := _front_curb_point(parcel_rect, front_side)

	var can_scene: PackedScene = HOUSE_TRASH_CAN_SCENES[_rng.randi_range(0, HOUSE_TRASH_CAN_SCENES.size() - 1)]
	var can_instance := can_scene.instantiate()
	_place_prop(can_instance, point.x, point.y, _rng.randf_range(0.0, TAU), _rng.randf_range(0.9, 1.1))

	if _rng.randf() < house_loose_bag_chance:
		var bag_count := _rng.randi_range(1, 2)
		for i in range(bag_count):
			var bag_scene: PackedScene = VACANT_LOT_SCENES[_rng.randi_range(0, VACANT_LOT_SCENES.size() - 1)]
			var bag := bag_scene.instantiate()
			var jitter_x := point.x + _rng.randf_range(-0.9, 0.9)
			var jitter_z := point.y + _rng.randf_range(-0.9, 0.9)
			_place_prop(bag, jitter_x, jitter_z, _rng.randf_range(0.0, TAU), _rng.randf_range(0.7, 1.0))

	return true


## Punto (X/Z locales) cerca del borde de `rect` que mira a la calle
## (front_side: 0=N, 1=E, 2=S, 3=O - mismo criterio que
## HouseGenerator._house_center_in_parcel), con un offset lateral al azar
## para no quedar pegado al eje central del lote (donde normalmente iria
## un camino de entrada).
func _front_curb_point(rect: Rect2, front_side: int) -> Vector2:
	var center := rect.position + rect.size * 0.5
	match front_side:
		0:
			return Vector2(center.x + _lateral_offset(rect.size.x), rect.position.y + house_trash_can_edge_inset)
		1:
			return Vector2(rect.end.x - house_trash_can_edge_inset, center.y + _lateral_offset(rect.size.y))
		2:
			return Vector2(center.x + _lateral_offset(rect.size.x), rect.end.y - house_trash_can_edge_inset)
		_:
			return Vector2(rect.position.x + house_trash_can_edge_inset, center.y + _lateral_offset(rect.size.y))


func _lateral_offset(extent: float) -> float:
	var half := maxf(extent * 0.5 - house_trash_can_edge_inset, 0.0)
	if half <= 0.0:
		return 0.0
	return _rng.randf_range(-half, half)


## Cachea (una sola vez por generacion) los modelos de arboles de
## tree_pack_1.1 - mismo pack que ChunkManager usa para el bosque silvestre,
## reusado tal cual sin agregar ningun asset nuevo. Las escalas de patio
## (yard_tree_scale_min/max) son mas chicas que las del bosque para que no
## se vean gigantes en un lote urbano.
func _load_tree_scenes() -> void:
	if not _tree_scenes.is_empty():
		return
	for i in range(1, TREE_MODEL_COUNT + 1):
		var model_path := "%stree%02d.fbx" % [TREE_MODELS_DIR, i]
		var texture_path := "%stree%02d.png" % [TREE_TEXTURES_DIR, i]
		if ResourceLoader.exists(model_path):
			_tree_scenes.append(load(model_path))
			_tree_textures.append(load(texture_path) if ResourceLoader.exists(texture_path) else null)
	if _tree_scenes.is_empty():
		push_warning("[CityDecoration] No se encontraron modelos en tree_pack_1.1 - revisa que assets/tree_pack_1.1 exista.")


## Patio de una casa ya generada = su parcel_rect, menos una franja pegada
## al borde del lote (ahi va la reja, ver HouseGenerator._build_fence_perimeter
## - asi ningun arbol queda "en medio de una valla") y menos la huella de la
## casa con un margen extra (para que ningun arbol quede pegado o encima de
## la construccion). Devuelve cuantos arboles se colocaron de verdad.
func _scatter_house_yard_trees(spec: Dictionary) -> int:
	if _rng.randf() >= house_yard_tree_chance:
		return 0

	var parcel_rect: Rect2 = spec.get("parcel_rect", Rect2())
	var allowed_rect: Rect2 = parcel_rect.grow(-yard_tree_edge_clearance)
	if allowed_rect.size.x <= 0.5 or allowed_rect.size.y <= 0.5:
		return 0

	var house_center: Vector2 = spec.get("house_center", parcel_rect.position + parcel_rect.size * 0.5)
	var house_width: float = spec.get("width", 0.0)
	var house_depth: float = spec.get("depth", 0.0)
	var house_rect := Rect2(
		house_center - Vector2(house_width, house_depth) * 0.5, Vector2(house_width, house_depth)
	).grow(yard_tree_house_clearance)

	var count := _rng.randi_range(house_yard_tree_min, house_yard_tree_max)
	var placed := 0
	for i in range(count):
		if _place_yard_tree(allowed_rect, house_rect):
			placed += 1
	return placed


## Lote baldio: mismo criterio que un patio, pero sin ninguna casa que
## excluir - todo `allowed_rect` (el rect del lote, menos el margen del
## borde/reja) esta libre para arboles.
func _scatter_vacant_lot_trees(parcel: Dictionary) -> int:
	if _rng.randf() >= vacant_lot_tree_chance:
		return 0

	var rect: Rect2 = parcel.get("rect", Rect2())
	var allowed_rect: Rect2 = rect.grow(-yard_tree_edge_clearance)
	if allowed_rect.size.x <= 0.5 or allowed_rect.size.y <= 0.5:
		return 0

	var count := _rng.randi_range(vacant_lot_tree_min, vacant_lot_tree_max)
	var placed := 0
	for i in range(count):
		if _place_yard_tree(allowed_rect, Rect2()):
			placed += 1
	return placed


## Intenta poner UN arbol en un punto al azar dentro de `allowed_rect` que
## no caiga dentro de `exclude_rect` (la huella de la casa, ya con margen -
## un Rect2() de tamaño cero nunca contiene ningun punto, asi que tambien
## sirve para el caso "sin casa que evitar" de los lotes baldios).
## Reintenta hasta yard_tree_placement_attempts veces antes de rendirse
## (patios chicos o con la casa ocupando casi todo el lote pueden no tener
## espacio libre en algun intento al azar).
func _place_yard_tree(allowed_rect: Rect2, exclude_rect: Rect2) -> bool:
	if _tree_scenes.is_empty():
		return false

	for attempt in range(yard_tree_placement_attempts):
		var local_x := _rng.randf_range(allowed_rect.position.x, allowed_rect.position.x + allowed_rect.size.x)
		var local_z := _rng.randf_range(allowed_rect.position.y, allowed_rect.position.y + allowed_rect.size.y)
		if exclude_rect.size.x > 0.0 and exclude_rect.size.y > 0.0 and exclude_rect.has_point(Vector2(local_x, local_z)):
			continue

		var index := _rng.randi_range(0, _tree_scenes.size() - 1)
		var instance: Node3D = _tree_scenes[index].instantiate()
		_place_prop(instance, local_x, local_z, _rng.randf_range(0.0, TAU), _rng.randf_range(yard_tree_scale_min, yard_tree_scale_max))
		_add_tree_collision(instance)

		var texture: Texture2D = _tree_textures[index] if index < _tree_textures.size() else null
		if texture != null:
			var material := StandardMaterial3D.new()
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # consistente con el look PSX del resto del juego
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR # las texturas de hojas usan alpha
			material.alpha_scissor_threshold = 0.5
			material.cull_mode = BaseMaterial3D.CULL_DISABLED # tarjetas de hojas/ramas visibles desde ambos lados
			_apply_tree_material(instance, material)
		return true
	return false


## Aplica `material` a todas las mallas (MeshInstance3D) bajo `root` - las
## texturas de tree_pack_1.1 no siempre quedan bien vinculadas por el
## importador FBX (mismo motivo por el que ChunkManager hace lo mismo con
## su bosque silvestre).
func _apply_tree_material(root: Node, material: StandardMaterial3D) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = material
	for child in root.get_children():
		_apply_tree_material(child, material)


## Colision "talable" (ChoppableTree, ver world/choppable_tree.gd y el
## mismo helper en ChunkManager._add_tree_collision) para arboles de
## patios/lotes baldios - sin esto MeleeController no tiene nada que
## golpear. Se mide el AABB visual real (ya posicionado/escalado por
## _place_prop) en espacio de mundo y se convierte a espacio local del
## arbol para el cilindro aproximado del tronco.
const TREE_TRUNK_RADIUS := 0.35
const TREE_COLLISION_HEIGHT_RATIO := 0.65
const CHOPPABLE_TREE_SCRIPT := preload("res://world/choppable_tree.gd")


func _add_tree_collision(tree_instance: Node3D) -> void:
	var world_aabb := _compute_world_aabb(tree_instance)
	if world_aabb.size.y <= 0.01:
		return
	var local_aabb: AABB = tree_instance.global_transform.affine_inverse() * world_aabb
	var height := maxf(local_aabb.size.y * TREE_COLLISION_HEIGHT_RATIO, 0.5)

	var body := CHOPPABLE_TREE_SCRIPT.new() as StaticBody3D
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TREE_TRUNK_RADIUS
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3(
		local_aabb.position.x + local_aabb.size.x * 0.5,
		height * 0.5,
		local_aabb.position.z + local_aabb.size.z * 0.5
	)
	body.add_child(shape)
	tree_instance.add_child(body)


func _compute_world_aabb(node: Node) -> AABB:
	var result := AABB()
	var has_result := false
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		var world_aabb: AABB = visual.global_transform * visual.get_aabb()
		result = world_aabb
		has_result = true
	for child in node.get_children():
		var child_aabb := _compute_world_aabb(child)
		if child_aabb.size == Vector3.ZERO:
			continue
		if not has_result:
			result = child_aabb
			has_result = true
		else:
			result = result.merge(child_aabb)
	return result


func _random_corner_point(rect: Rect2, inset: float) -> Vector2:
	var safe_inset_x := minf(inset, rect.size.x * 0.5 - 0.01)
	var safe_inset_z := minf(inset, rect.size.y * 0.5 - 0.01)
	var corners := [
		Vector2(rect.position.x + safe_inset_x, rect.position.y + safe_inset_z),
		Vector2(rect.end.x - safe_inset_x, rect.position.y + safe_inset_z),
		Vector2(rect.end.x - safe_inset_x, rect.end.y - safe_inset_z),
		Vector2(rect.position.x + safe_inset_x, rect.end.y - safe_inset_z),
	]
	return corners[_rng.randi_range(0, 3)]


## Envuelve `instance` en un socket propio y lo baja/sube en Y para que su
## base real (medida con _compute_local_aabb) quede apoyada en el piso -
## misma tecnica que CityBlockGenerator._add_light_instance.
func _place_prop(instance: Node3D, x: float, z: float, rotation_y: float, scale_factor: float) -> void:
	var local_aabb := _compute_local_aabb(instance)
	var socket := Node3D.new()
	_generated_root.add_child(socket)
	socket.position = Vector3(x, 0.0, z)
	socket.rotation.y = rotation_y
	socket.scale = Vector3.ONE * scale_factor
	instance.transform = Transform3D(Basis(), Vector3(0.0, -local_aabb.position.y, 0.0))
	socket.add_child(instance)


## Instancia (una sola vez, oculta) el pack combinado de drenaje y
## devuelve una copia (duplicate()) del nodo suelto `prop_name` - mismo
## patron que DrainageDungeonGenerator._scatter_cell_props. null si el
## nodo no existe (no deberia pasar: SEWER_PROP_NAMES es la misma lista ya
## verificada en ese generador).
func _duplicate_sewer_prop(prop_name: String) -> Node3D:
	if _sewer_template == null or not is_instance_valid(_sewer_template):
		var scene: PackedScene = load(SEWERS_SCENE_PATH)
		if scene == null:
			return null
		_sewer_template = scene.instantiate()
		add_child(_sewer_template)
		_sewer_template.visible = false

	var template := _sewer_template.find_child(prop_name, true, false) as Node3D
	if template == null:
		return null
	return template.duplicate() as Node3D


func _free_sewer_template() -> void:
	if _sewer_template != null and is_instance_valid(_sewer_template):
		_sewer_template.free()
	_sewer_template = null


## Combina el AABB de todas las mallas (VisualInstance3D) debajo de
## `root`, medido en su espacio local - misma tecnica que
## CityBlockGenerator._compute_local_aabb() / DrainageDungeonGenerator._compute_local_aabb().
func _compute_local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	var stack: Array = [[root, Transform3D.IDENTITY]]

	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var relative_transform: Transform3D = entry[1]

		if node is VisualInstance3D:
			var mesh_aabb: AABB = (node as VisualInstance3D).get_aabb()
			var relative_aabb: AABB = relative_transform * mesh_aabb
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
