extends Node3D
class_name CityBlockGenerator
## Genera una grilla de calles (pack URBAN, road_1_*) tipo Manhattan: N
## calles verticales x M calles horizontales, con una interseccion real
## (recta/esquina/T/cruz - CityPieceCatalog) en cada cruce, rotada para
## que sus aberturas calcen con las de al lado - misma logica de
## bitmask+rotacion que DrainageDungeonGenerator, pero mucho mas simple
## porque ES una grilla real (streets siempre rectas) en vez de un
## laberinto: no hace falta encadenar posiciones celda por celda, alcanza
## con sumar el tamaño de cada tramo.
##
## Cada tramo de calle entre dos cruces (una "cuadra") tiene un numero
## ALEATORIO de piezas rectas (min/max_segments_per_edge) - como todas las
## piezas del pack son tiles cuadrados del mismo tamaño (se mide una sola
## vez con tile_size, igual que DrainageDungeonGenerator mide sus piezas
## con _compute_local_aabb), esto hace que las manzanas resultantes salgan
## de tamaños distintos (mas tiles = manzana mas larga) sin estirar ni
## deformar ningun modelo.
##
## Las manzanas (el rectangulo LIBRE entre 4 calles, donde van las casas)
## quedan expuestas en `block_rects` (Array[Rect2]) y `block_parcels`
## (Array[Dictionary], con rect y frente), en coordenadas X/Z locales de
## este nodo.

const HOUSE_GENERATOR_SCRIPT := preload("res://world/city/house_generator.gd")
const DECORATION_GENERATOR_SCRIPT := preload("res://world/city/city_decoration.gd")

@export var rng_seed: int = 0
@export var randomize_seed_on_run: bool = true
## Cuantas calles verticales/horizontales hay menos una - o sea, cuantas
## "columnas"/"filas" de manzanas salen (2 = una calle a cada lado + una
## en medio = 2 manzanas en esa direccion).
@export_range(1, 12) var blocks_x: int = 4
@export_range(1, 12) var blocks_z: int = 3
## Cuantas piezas rectas (al azar, entre estos dos numeros) separan dos
## cruces consecutivos - controla el tamaño de cada cuadra.
@export var min_segments_per_edge: int = 1
@export var max_segments_per_edge: int = 3

@export_group("Forma de las manzanas")
@export var elongated_blocks_enabled: bool = true
@export_range(2, 12, 1) var min_lots_per_long_side: int = 6
@export_range(2, 12, 1) var max_lots_per_long_side: int = 12
@export_range(0.0, 0.8, 0.05) var lot_frontage_variation: float = 0.6
@export_range(0.0, 0.8, 0.05) var lot_depth_variation: float = 0.5
@export_range(0.5, 8.0, 0.5) var lot_minimum_variation_margin: float = 3.0
## Lineas rosas de depuracion sobre cada lote/parcela - ademas de ayudar a
## calibrar el tamaño de manzanas en tests/city_block_test.tscn, sirven en
## el mundo real para ubicar la ciudad a simple vista desde lejos (pedido
## explicito) - por eso el default es true.
@export var show_parcel_outlines: bool = true
@export var parcel_outline_color: Color = Color(1.0, 0.05, 0.45, 1.0)
@export_range(0.1, 2.0, 0.05) var parcel_outline_thickness: float = 0.6

@export_group("Ubicacion de las piezas")
@export var piece_height: float = 0.0
## Cuanto se superponen (metros) las piezas vecinas al colocarlas - mismo
## criterio que piece_overlap en DrainageDungeonGenerator, para tapar
## rendijas minimas de import.
@export var piece_overlap: float = 0.02
## Muestra la caja real medida de cada pieza (verde) - para verificar que
## las piezas calzan borde con borde.
@export var show_piece_boxes: bool = false
## Muestra el rectangulo (naranja, plano) del area libre de cada manzana -
## el espacio disponible antes del inset de parcela de las casas.
@export var show_block_rects: bool = false

@export_group("Casas")
## Cuando esta activo, la ciudad crea su propio HouseGenerator despues de
## construir las calles y le entrega las parcelas resultantes.
@export var generate_houses: bool = true
## 0 = intenta colocar una casa en cada parcela valida.
@export_range(0, 512, 1) var house_count: int = 0
@export var house_randomize_seed_on_run: bool = false
@export var house_rng_seed_offset: int = 1009
@export var house_show_debug_labels: bool = false
@export var house_show_roofs: bool = true
@export var house_show_fences: bool = true
@export_range(0.0, 1.0, 0.05) var house_fence_probability: float = 0.72
@export_range(0.0, 1.0, 0.05) var house_small_fence_probability: float = 0.35
@export_range(0.0, 1.0, 0.05) var vacant_lot_probability: float = 0.15
@export_range(0.0, 5.0, 0.1) var house_parcel_boundary_inset: float = 0.5
@export_range(0.0, 20.0, 0.1) var house_front_yard_depth: float = 7.0
@export_range(0.0, 12.0, 0.1) var house_side_yard_width: float = 3.0
@export_range(0.0, 20.0, 0.1) var house_rear_yard_depth: float = 4.0
@export var house_narrow_lots_enabled: bool = true
@export_range(0.0, 60.0, 0.5) var house_narrow_lot_max_frontage: float = 18.0
@export_range(0.0, 2.0, 0.1) var house_narrow_lot_side_clearance: float = 1.0

@export_group("Decoracion (basura y detalles, ciudad abandonada)")
## Cuando esta activo, la ciudad crea su propio CityDecoration despues de
## que HouseGenerator termina, y le entrega generated_houses/vacant_parcels
## (ver CityDecoration). Requiere generate_houses activo (sin casas no hay
## nada que decorar: ni lotes baldios ni frentes de casa).
@export var scatter_decorations: bool = true
@export var decoration_randomize_seed_on_run: bool = false
@export var decoration_rng_seed_offset: int = 2027
@export var decoration_scatter_vacant_lots: bool = true
@export_range(0.0, 1.0, 0.05) var decoration_vacant_lot_trash_chance: float = 0.6
@export_range(0, 12, 1) var decoration_vacant_lot_props_min: int = 2
@export_range(0, 12, 1) var decoration_vacant_lot_props_max: int = 6
@export_range(0.0, 1.0, 0.05) var decoration_vacant_lot_sewer_prop_ratio: float = 0.35
@export var decoration_vacant_lot_min_area_for_dumpster: float = 40.0
@export_range(0.0, 1.0, 0.05) var decoration_vacant_lot_dumpster_chance: float = 0.25
@export var decoration_scatter_house_trash_cans: bool = true
@export_range(0.0, 1.0, 0.05) var decoration_house_trash_can_chance: float = 0.4
@export_range(0.0, 1.0, 0.05) var decoration_house_loose_bag_chance: float = 0.35

@export_group("Parcelas residenciales")
## Objetivo de lotes residenciales por manzana. El sistema escoge el layout
## mas grande que quepa sin deformar las casas.
@export_range(1, 4, 1) var target_lots_per_block: int = 4
## Medidas minimas utiles despues del inset de parcela, no una posicion fija.
@export_range(10.0, 60.0, 0.5) var minimum_lot_frontage: float = 13.0
@export_range(10.0, 80.0, 0.5) var minimum_lot_depth: float = 20.0

@export_group("Piezas (pack URBAN, Roads/Road type 1)")
@export var straight_config: CityPieceConfig = preload("res://world/city/piece_configs/straight.tres")
@export var corner_config: CityPieceConfig = preload("res://world/city/piece_configs/corner.tres")
@export var t_junction_config: CityPieceConfig = preload("res://world/city/piece_configs/t_junction.tres")
@export var cross_config: CityPieceConfig = preload("res://world/city/piece_configs/cross.tres")

@export_group("Entradas exteriores")
## Coloca carreteras largas de bienvenida en cruces seleccionados del
## perimetro. Las esquinas del mapa se excluyen para que cada entrada tenga
## una sola direccion exterior y pueda convertirse en una cross limpia.
@export var entry_roads_enabled: bool = true
@export_range(0, 12) var entry_road_count: int = 2
@export var entry_road_config: CityPieceConfig = preload("res://world/city/piece_configs/entry_road.tres")
@export var show_entry_road_boxes: bool = false
## Correccion opcional por si la orientacion original del FBX de entrada
## necesita una vuelta adicional despues de comprobarla visualmente.
@export var entry_road_rotation_offset_degrees: float = 0.0
## Alinea la calzada diagonal real de road_1_sheer con la orilla de la
## calzada del modelo cross. No usa el centro de la caja verde: mide la
## superficie material Road en el extremo que entra a la ciudad.
@export var entry_road_align_to_cross_corner: bool = true

@export_group("Iluminacion (semaforos y linternas)")
@export var scatter_lights: bool = true
## Cruces en T (3 calles) y cruces de 4 calles -> semaforo. Una esquina
## simple (2 calles, un solo giro) NO es un cruce real - ahi no hace falta
## semaforo, se ve mas natural con una linterna comun (mismo criterio que
## una ciudad real: los semaforos van donde convergen 3 o mas calles).
@export var traffic_light_scene: PackedScene = preload("res://assets/URBAN/URBAN/Traffic lights/traffic_light_L.fbx")
## Grados extra (aplicados encima de la rotacion del socket) para hacer
## que el semaforo quede mirando HACIA la calle en vez de hacia la
## banqueta - ajustar a mano desde el Inspector si con este pack el
## modelo original queda mirando para el otro lado (0/90/180/270).
@export var traffic_light_facing_offset_degrees: float = 90.0
## Factor de la mitad del tile donde se ancla el semaforo: 0.5 es la
## esquina geometrica exacta del modelo T/cruz. Se deja exportado para
## poder retirarlo apenas el pack necesite un pequeno inset de banqueta.
@export_range(0.4, 0.5, 0.01) var traffic_light_corner_factor: float = 0.5
## Distancia en metros que el semaforo se separa de la esquina hacia el
## centro del cruce, en diagonal. 3.0 m lo retira claramente del vertice
## sin cambiar la esquina de la interseccion que se eligio.
@export_range(0.0, 5.0, 0.05) var traffic_light_corner_inset: float = 3.0
## Probabilidad de que una interseccion de 4 calles (`cross`) tenga
## semaforos. 0.5 = aproximadamente la mitad de las cruces; cada cruz
## seleccionada sigue recibiendo sus 4 semaforos.
@export_range(0.0, 1.0, 0.05) var traffic_light_cross_probability: float = 0.5
## Esquinas simples (2 calles, un giro) -> linterna comun.
@export var street_light_scene: PackedScene = preload("res://assets/URBAN/URBAN/Traffic lights/street_light.fbx")
## Igual que traffic_light_facing_offset_degrees pero para la linterna de
## esquina - el pack trae el modelo orientado hacia la banqueta por
## defecto, este offset lo gira para que apunte hacia la calle.
@export var street_light_facing_offset_degrees: float = 0.0

## Tamaño (metros) de un tile de calle - medido automaticamente en
## _ready() a partir de la pieza cruz (todas las piezas del pack son tiles
## cuadrados del mismo tamaño, incluida la recta, asi que sirve como
## unidad de grilla para todo el sistema).
var tile_size: float = 0.0
## Rect2(posicion, tamaño) del area libre de cada manzana, en X/Z locales
## de este nodo - para que el futuro sistema de casas sepa donde puede
## construir.
var block_rects: Array[Rect2] = []
## Contrato rico para la generacion integrada: cada entrada representa un
## lote, con `rect`, `front_side` (0=N, 1=E, 2=S, 3=O), `block_index`,
## `lot_index` y `source_index`.
var block_parcels: Array[Dictionary] = []

var _catalog: CityPieceCatalog
var _rng: RandomNumberGenerator
var _house_generator: HouseGenerator
var _decoration_generator: CityDecoration
var _parcel_outline_root: Node3D


func _ready() -> void:
	if randomize_seed_on_run:
		rng_seed = randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_rng = rng

	_catalog = CityPieceCatalog.new({
		"straight": straight_config,
		"corner": corner_config,
		"t_junction": t_junction_config,
		"cross": cross_config,
	})

	tile_size = _measure_tile_size()
	if tile_size <= 0.0:
		push_warning("CityBlockGenerator: no se pudo medir el tamaño del tile (revisar model_scene de cross_config).")
		return

	_build_grid(rng)
	_create_house_generator()
	_create_decoration_generator()

	print("[CityBlockGenerator] %d x %d manzanas generadas (tile=%.2fm, seed=%d)" % [blocks_x, blocks_z, tile_size, rng_seed])


func _create_house_generator() -> void:
	if not generate_houses or block_parcels.is_empty():
		return
	_house_generator = HOUSE_GENERATOR_SCRIPT.new() as HouseGenerator
	if _house_generator == null:
		push_warning("CityBlockGenerator: no se pudo crear HouseGenerator.")
		return

	_house_generator.name = "HouseGenerator"
	_house_generator.auto_generate = false
	_house_generator.parcel_source_path = NodePath("..")
	_house_generator.house_count = clampi(house_count if house_count > 0 else block_parcels.size(), 1, 512)
	_house_generator.randomize_seed_on_run = house_randomize_seed_on_run
	_house_generator.rng_seed = rng_seed + house_rng_seed_offset
	_house_generator.show_debug_labels = house_show_debug_labels
	_house_generator.show_roofs = house_show_roofs
	_house_generator.show_fences = house_show_fences
	_house_generator.fence_probability = house_fence_probability
	_house_generator.small_fence_probability = house_small_fence_probability
	_house_generator.vacant_lot_probability = vacant_lot_probability
	_house_generator.parcel_boundary_inset = house_parcel_boundary_inset
	_house_generator.front_yard_depth = house_front_yard_depth
	_house_generator.side_yard_width = house_side_yard_width
	_house_generator.rear_yard_depth = house_rear_yard_depth
	_house_generator.narrow_lots_enabled = house_narrow_lots_enabled
	_house_generator.narrow_lot_max_frontage = house_narrow_lot_max_frontage
	_house_generator.narrow_lot_side_clearance = house_narrow_lot_side_clearance
	add_child(_house_generator)
	_house_generator.call_deferred("generate_houses")


## Crea el CityDecoration (mismo patron que _create_house_generator) y
## encola su generacion DESPUES de la de HouseGenerator: ambas llamadas se
## difieren con call_deferred en el mismo orden en que se encolan aca -
## Godot vacia esa cola en orden FIFO, asi que _run_decoration_pass()
## siempre corre una vez que generate_houses() ya termino y
## generated_houses/vacant_parcels ya estan listos para leer.
func _create_decoration_generator() -> void:
	if not scatter_decorations or _house_generator == null:
		return
	_decoration_generator = DECORATION_GENERATOR_SCRIPT.new() as CityDecoration
	if _decoration_generator == null:
		push_warning("CityBlockGenerator: no se pudo crear CityDecoration.")
		return

	_decoration_generator.name = "CityDecoration"
	if decoration_randomize_seed_on_run:
		_decoration_generator.rng_seed = randi()
	else:
		_decoration_generator.rng_seed = rng_seed + decoration_rng_seed_offset
	_decoration_generator.scatter_vacant_lots = decoration_scatter_vacant_lots
	_decoration_generator.vacant_lot_trash_chance = decoration_vacant_lot_trash_chance
	_decoration_generator.vacant_lot_props_min = decoration_vacant_lot_props_min
	_decoration_generator.vacant_lot_props_max = decoration_vacant_lot_props_max
	_decoration_generator.vacant_lot_sewer_prop_ratio = decoration_vacant_lot_sewer_prop_ratio
	_decoration_generator.vacant_lot_min_area_for_dumpster = decoration_vacant_lot_min_area_for_dumpster
	_decoration_generator.vacant_lot_dumpster_chance = decoration_vacant_lot_dumpster_chance
	_decoration_generator.scatter_house_trash_cans = decoration_scatter_house_trash_cans
	_decoration_generator.house_trash_can_chance = decoration_house_trash_can_chance
	_decoration_generator.house_loose_bag_chance = decoration_house_loose_bag_chance
	add_child(_decoration_generator)
	call_deferred("_run_decoration_pass")


func _run_decoration_pass() -> void:
	if _decoration_generator != null and is_instance_valid(_decoration_generator) and _house_generator != null:
		_decoration_generator.generate_decorations(_house_generator)


## Mide el tile cuadrado del pack usando la pieza cruz (la que toca las 4
## direcciones) - su footprint X/Z es el tamaño de UN tile de calle.
func _measure_tile_size() -> float:
	if cross_config == null or cross_config.model_scene == null:
		return 0.0
	var aabb := _measure_scene_aabb(cross_config.model_scene)
	return maxf(aabb.size.x, aabb.size.z)


## Calcula el tamaño MAXIMO posible (peor caso) que esta ciudad puede
## llegar a medir segun su configuracion actual (blocks_x/blocks_z,
## min/max_lots_per_long_side, etc) - SIN necesidad de generarla (no hace
## falta estar en el arbol de escena ni correr _build_grid/RNG alguno).
## Sirve para reservar de antemano cuanto terreno aplanar en el mundo real
## ANTES de que la ciudad exista de verdad (ver CityWorldSpawner).
##
## No sabemos de antemano cual eje terminara siendo el "largo" (eso se
## sortea en _build_grid), asi que el peor caso simplemente asume que
## CUALQUIERA de los dos ejes podria alcanzar el maximo de tiles del eje
## largo - da un rectangulo generosamente mas grande de lo que la ciudad
## real terminara midiendo, lo cual es The Safe Choice (mejor sobrar
## terreno plano que quedarse corto y que se vea un escalon en el borde).
func estimate_max_footprint_size() -> Vector2:
	var measured_tile_size := _measure_tile_size()
	if measured_tile_size <= 0.0:
		return Vector2.ZERO
	tile_size = measured_tile_size
	var long_max_segments := _maximum_segments_for_long_side()
	var long_tiles := long_max_segments + 1 # +1: cruces cuentan como un tile mas
	return Vector2(
		float(blocks_x) * long_tiles * measured_tile_size,
		float(blocks_z) * long_tiles * measured_tile_size
	)


## Caja real de la ciudad ya generada, incluidos cruces, calles de entrada y
## lineas de parcela visibles. Debe llamarse despues de agregar el nodo al
## arbol, para que _ready() haya construido el layout y sus mallas.
func get_generated_footprint_aabb() -> AABB:
	if tile_size <= 0.0:
		return AABB()
	return _compute_local_aabb(self)


func _measure_scene_aabb(scene: PackedScene) -> AABB:
	var instance: Node3D = scene.instantiate()
	var aabb := _compute_local_aabb(instance)
	instance.free()
	return aabb


## Arma la grilla completa: cols = blocks_x+1 calles verticales, rows =
## blocks_z+1 calles horizontales. Los tramos entre cruces (segments_x
## por columna, segments_z por fila) se sortean UNA VEZ y se comparten
## entre todas las filas/columnas - asi las calles quedan siempre
## perfectamente rectas (una calle vertical real no puede tener un ancho
## de cuadra distinto segun la fila en la que la mires).
func _build_grid(rng: RandomNumberGenerator) -> void:
	var segments_x: Array[int] = []
	var segments_z: Array[int] = []
	if elongated_blocks_enabled and generate_houses:
		var long_axis_is_x := rng.randi_range(0, 1) == 0
		var long_min_segments := _minimum_segments_for_long_side()
		var long_max_segments := _maximum_segments_for_long_side()
		var depth_segments := _minimum_segments_for_two_lot_rows()
		# blocks_x/blocks_z se usan TAL CUAL estan configurados (grilla
		# NxM normal, calles verticales y horizontales repitiendose varias
		# veces) - no se recalculan, para no colapsar un eje a solo 1-2
		# manzanas (eso hacia que la ciudad se viera como una tira en vez
		# de una cuadricula real).
		#
		# REGLA CLAVE: el eje corto de TODA manzana mide exactamente lo que
		# ocupan dos filas de casas espalda con espalda - ni un tile mas.
		# Asi nunca queda un hueco muerto al centro ni patios gigantes.
		# La variedad de tamaño viene SOLO del eje largo: cada columna/fila
		# sortea su propia longitud (mas tiles = mas casas en fila).
		for _col in range(blocks_x):
			if long_axis_is_x:
				segments_x.append(rng.randi_range(long_min_segments, long_max_segments))
			else:
				segments_x.append(depth_segments)
		for _row in range(blocks_z):
			if long_axis_is_x:
				segments_z.append(depth_segments)
			else:
				segments_z.append(rng.randi_range(long_min_segments, long_max_segments))
	else:
		var minimum_segments_for_houses := _minimum_segments_for_house_density()
		var effective_min_segments := maxi(min_segments_per_edge, minimum_segments_for_houses)
		var effective_max_segments := maxi(max_segments_per_edge, effective_min_segments)
		for _col in range(blocks_x):
			segments_x.append(rng.randi_range(effective_min_segments, effective_max_segments))
		for _row in range(blocks_z):
			segments_z.append(rng.randi_range(effective_min_segments, effective_max_segments))

	# Posicion de cada calle en "unidades de tile" (cuanta piezas hay
	# antes de ella, contando cruces y rectas por igual - todas miden un
	# tile), despues se multiplica por tile_size para tener metros reales.
	var cols := blocks_x + 1
	var rows := blocks_z + 1
	var col_units: Array[int] = [0]
	for col in range(blocks_x):
		col_units.append(col_units[col] + segments_x[col] + 1)
	var row_units: Array[int] = [0]
	for row in range(blocks_z):
		row_units.append(row_units[row] + segments_z[row] + 1)

	var selected_entries := _select_entry_roads(cols, rows, rng)
	var entries_by_cell: Dictionary = {}
	for entry in selected_entries:
		entries_by_cell[Vector2i(entry["col"], entry["row"])] = entry

	# Cruces.
	for row in range(rows):
		for col in range(cols):
			var entry_data: Dictionary = entries_by_cell.get(Vector2i(col, row), {})
			var entry_bit: int = int(entry_data.get("outward_bit", 0))
			var bitmask := 0
			if row > 0:
				bitmask |= 1 << 0 # Norte
			if col < cols - 1:
				bitmask |= 1 << 1 # Este
			if row < rows - 1:
				bitmask |= 1 << 2 # Sur
			if col > 0:
				bitmask |= 1 << 3 # Oeste
			bitmask |= entry_bit

			var resolved := _catalog.resolve(bitmask)
			var world_pos := Vector3(col_units[col] * tile_size, piece_height, row_units[row] * tile_size)
			_place_piece(resolved, world_pos, bitmask)
			if entry_bit != 0:
				_place_entry_road(world_pos, entry_bit)

	# Tramos rectos horizontales (Este-Oeste, bitmask 0b1010) - uno por
	# cada fila, entre cada par de columnas consecutivas.
	for row in range(rows):
		for col in range(blocks_x):
			for k in range(segments_x[col]):
				var unit := col_units[col] + k + 1
				var world_pos := Vector3(unit * tile_size, piece_height, row_units[row] * tile_size)
				var resolved := _catalog.resolve(0b1010)
				_place_piece(resolved, world_pos, 0b1010)

	# Tramos rectos verticales (Norte-Sur, bitmask 0b0101) - uno por cada
	# columna, entre cada par de filas consecutivas.
	for col in range(cols):
		for row in range(blocks_z):
			var resolved := _catalog.resolve(0b0101)
			for k in range(segments_z[row]):
				var unit := row_units[row] + k + 1
				var world_pos := Vector3(col_units[col] * tile_size, piece_height, unit * tile_size)
				_place_piece(resolved, world_pos, 0b0101)

	_build_block_rects(col_units, row_units)


func _minimum_segments_for_house_density() -> int:
	if not generate_houses:
		return 1
	var raw_frontage := minimum_lot_frontage + house_parcel_boundary_inset * 2.0
	var raw_depth := minimum_lot_depth + house_parcel_boundary_inset * 2.0
	var required_block_side := maxf(raw_frontage, raw_depth)
	return maxi(1, int(ceil(required_block_side / tile_size)))


func _minimum_segments_for_long_side() -> int:
	var raw_frontage := minimum_lot_frontage + house_parcel_boundary_inset * 2.0
	var lot_count := clampi(min_lots_per_long_side, 2, 12)
	var minimum_average_frontage := raw_frontage + lot_minimum_variation_margin
	return maxi(min_segments_per_edge, int(ceil(float(lot_count) * minimum_average_frontage / tile_size)))


func _maximum_segments_for_long_side() -> int:
	var raw_frontage := minimum_lot_frontage + house_parcel_boundary_inset * 2.0
	var lot_count := maxi(clampi(max_lots_per_long_side, 2, 12), clampi(min_lots_per_long_side, 2, 12))
	var minimum_average_frontage := raw_frontage + lot_minimum_variation_margin
	return maxi(_minimum_segments_for_long_side(), int(ceil(float(lot_count) * minimum_average_frontage / tile_size)))


func _minimum_segments_for_two_lot_rows() -> int:
	var raw_depth := minimum_lot_depth + house_parcel_boundary_inset * 2.0
	var minimum_average_depth := raw_depth + lot_minimum_variation_margin
	return maxi(min_segments_per_edge, int(ceil(minimum_average_depth * 2.0 / tile_size)))


## Elige posiciones de entrada aleatorias entre los puntos del perimetro que
## no son esquinas. Se mezclan con el mismo RNG/seed del layout y se toma un
## numero exacto (`entry_road_count`), asi no hay una ejecucion en la que la
## probabilidad casualmente deje la ciudad sin ninguna entrada.
func _select_entry_roads(cols: int, rows: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if not entry_roads_enabled or entry_road_count <= 0:
		return candidates

	for col in range(1, cols - 1):
		candidates.append({"col": col, "row": 0, "outward_bit": 1 << 0})
		candidates.append({"col": col, "row": rows - 1, "outward_bit": 1 << 2})
	for row in range(1, rows - 1):
		candidates.append({"col": 0, "row": row, "outward_bit": 1 << 3})
		candidates.append({"col": cols - 1, "row": row, "outward_bit": 1 << 1})

	if candidates.is_empty():
		return candidates

	# Fisher-Yates para seleccionar entradas sin repetir una celda del borde.
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: Dictionary = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary

	var selected: Array[Dictionary] = []
	var count := mini(entry_road_count, candidates.size())
	for index in range(count):
		selected.append(candidates[index])
	return selected


## El area LIBRE de cada manzana es el rectangulo entre el borde interno
## de las 4 esquinas que la rodean - se deja medio tile de margen desde
## el centro de cada cruce (mitad del tile de calle) para no invadir la
## calle/banqueta.
func _build_block_rects(col_units: Array[int], row_units: Array[int]) -> void:
	block_rects.clear()
	block_parcels.clear()
	if _parcel_outline_root != null and is_instance_valid(_parcel_outline_root):
		_parcel_outline_root.free()
	_parcel_outline_root = null
	if show_parcel_outlines:
		_parcel_outline_root = Node3D.new()
		_parcel_outline_root.name = "ParcelOutlines"
		add_child(_parcel_outline_root)
	var half := tile_size * 0.5
	for row in range(blocks_z):
		for col in range(blocks_x):
			var x_min: float = col_units[col] * tile_size + half
			var x_max: float = col_units[col + 1] * tile_size - half
			var z_min: float = row_units[row] * tile_size + half
			var z_max: float = row_units[row + 1] * tile_size - half
			if x_max <= x_min or z_max <= z_min:
				continue
			var rect := Rect2(Vector2(x_min, z_min), Vector2(x_max - x_min, z_max - z_min))
			var block_index := block_rects.size()
			block_rects.append(rect)
			var lots := _subdivide_block(rect)
			for lot_index in range(lots.size()):
				var lot: Dictionary = lots[lot_index]
				lot["source_index"] = block_parcels.size()
				lot["block_index"] = block_index
				lot["lot_index"] = lot_index
				block_parcels.append(lot)
				if show_parcel_outlines:
					_add_parcel_outline_visual(lot["rect"])
			if show_block_rects:
				_add_block_rect_visual(rect)



func _subdivide_block(rect: Rect2) -> Array[Dictionary]:
	if elongated_blocks_enabled:
		var elongated_lots := _build_elongated_lot_layout(rect)
		if not elongated_lots.is_empty():
			return elongated_lots

	if target_lots_per_block == 3:
		var three_lot_layout := _build_three_lot_layout(rect)
		if not three_lot_layout.is_empty():
			return three_lot_layout

	var layouts: Array[Vector2i] = []
	if target_lots_per_block >= 4:
		layouts.append(Vector2i(2, 2))
	if target_lots_per_block >= 2:
		layouts.append(Vector2i(2, 1))
		layouts.append(Vector2i(1, 2))
	layouts.append(Vector2i(1, 1))

	for layout in layouts:
		var columns := layout.x
		var rows := layout.y
		var lot_size := Vector2(rect.size.x / float(columns), rect.size.y / float(rows))
		var front_axis := _choose_lot_front_axis(lot_size)
		if front_axis < 0:
			continue

		var lots: Array[Dictionary] = []
		for row in range(rows):
			for column in range(columns):
				var lot_rect := Rect2(
					rect.position + Vector2(float(column) * lot_size.x, float(row) * lot_size.y),
					lot_size
				)
				var front_side := 0
				if front_axis == 0:
					front_side = 0 if row == 0 else 2
				else:
					front_side = 3 if column == 0 else 1
				lots.append({"rect": lot_rect, "front_side": front_side})
		return lots
	return []


func _build_elongated_lot_layout(rect: Rect2) -> Array[Dictionary]:
	var long_axis_is_x := rect.size.x >= rect.size.y
	var raw_frontage := minimum_lot_frontage + house_parcel_boundary_inset * 2.0
	var raw_depth := minimum_lot_depth + house_parcel_boundary_inset * 2.0
	var long_size := rect.size.x if long_axis_is_x else rect.size.y
	var short_size := rect.size.y if long_axis_is_x else rect.size.x
	var minimum_lot_count := clampi(min_lots_per_long_side, 2, 12)
	var minimum_average_frontage := raw_frontage + lot_minimum_variation_margin
	# NO se limita a max_lots_per_long_side: una manzana mas grande debe
	# traducirse en MAS casas en fila, no en patios gigantes. El techo real
	# es cuantos lotes de tamaño minimo caben fisicamente en el largo.
	var feasible_maximum_lot_count := int(floor(long_size / minimum_average_frontage))
	if feasible_maximum_lot_count < minimum_lot_count:
		return []
	var row_count := 2
	var minimum_average_depth := raw_depth + lot_minimum_variation_margin
	if short_size < minimum_average_depth * float(row_count):
		return []

	# El numero de lotes por fila se elige cerca del maximo que cabe (con
	# algo de variacion) - asi el sobrante de una manzana grande casi
	# siempre se llena con MAS lotes en vez de estirar cada uno a un patio
	# enorme.
	var row_lot_counts: Array[int] = []
	for _row in range(row_count):
		var row_lot_count := feasible_maximum_lot_count
		if _rng != null and feasible_maximum_lot_count > minimum_lot_count:
			var lot_count_floor := maxi(minimum_lot_count, feasible_maximum_lot_count - 2)
			row_lot_count = _rng.randi_range(lot_count_floor, feasible_maximum_lot_count)
		row_lot_counts.append(row_lot_count)

	var row_depths := _build_variable_frontages(short_size, row_count, raw_depth, lot_depth_variation)
	if row_depths.size() != row_count:
		return []
	# La profundidad de cada fila de casas tiene un tope razonable (no crece
	# sin limite solo porque la manzana tambien salio grande en el eje
	# corto). Si sobra espacio despues del tope, ese sobrante se queda como
	# terreno libre al centro de la manzana en vez de convertirse en un
	# patio gigante por casa.
	var row_depth_cap := raw_depth * (1.0 + lot_depth_variation)
	for row in range(row_count):
		row_depths[row] = minf(row_depths[row], row_depth_cap)

	var lots: Array[Dictionary] = []
	for row in range(row_count):
		var row_lot_count: int = row_lot_counts[row]
		var long_frontages := _build_variable_frontages(long_size, row_lot_count, raw_frontage, lot_frontage_variation)
		if long_frontages.size() != row_lot_count:
			return []
		var long_cursor := 0.0
		var row_depth: float = row_depths[row]
		for column in range(row_lot_count):
			var long_frontage: float = long_frontages[column]
			var lot_rect := Rect2()
			var front_side := 0
			if long_axis_is_x:
				lot_rect = Rect2(
					rect.position + Vector2(long_cursor, row_depths[0] if row == 1 else 0.0),
					Vector2(long_frontage, row_depth)
				)
				front_side = 0 if row == 0 else 2
			else:
				lot_rect = Rect2(
					rect.position + Vector2(row_depths[0] if row == 1 else 0.0, long_cursor),
					Vector2(row_depth, long_frontage)
				)
				front_side = 3 if row == 0 else 1
			lots.append({
				"rect": lot_rect,
				"front_side": front_side,
			})
			long_cursor += long_frontage
	return lots


func _build_variable_frontages(total_size: float, lot_count: int, minimum_frontage: float, variation_override: float = -1.0) -> Array[float]:
	var frontages: Array[float] = []
	if lot_count <= 0:
		return frontages

	var variation := clampf(lot_frontage_variation if variation_override < 0.0 else variation_override, 0.0, 0.8)
	var remaining_size := maxf(0.0, total_size - minimum_frontage * float(lot_count))
	var minimum_weight := maxf(0.15, 1.0 - variation)
	var maximum_weight := 1.0 + variation
	var weights: Array[float] = []
	var weight_sum := 0.0
	for _index in range(lot_count):
		var weight := 1.0
		if _rng != null and variation > 0.0:
			weight = _rng.randf_range(minimum_weight, maximum_weight)
		weights.append(weight)
		weight_sum += weight

	for weight in weights:
		var extra_size := remaining_size * weight / weight_sum if weight_sum > 0.0 else 0.0
		frontages.append(minimum_frontage + extra_size)
	return frontages


func _add_parcel_outline_visual(rect: Rect2) -> void:
	if _parcel_outline_root == null:
		return
	var thickness := maxf(parcel_outline_thickness, 0.1)
	var height := 4.2
	_add_parcel_outline_segment(
		Vector3(rect.position.x + rect.size.x * 0.5, height, rect.position.y),
		Vector3(rect.size.x + thickness, thickness, thickness)
	)
	_add_parcel_outline_segment(
		Vector3(rect.position.x + rect.size.x * 0.5, height, rect.end.y),
		Vector3(rect.size.x + thickness, thickness, thickness)
	)
	_add_parcel_outline_segment(
		Vector3(rect.position.x, height, rect.position.y + rect.size.y * 0.5),
		Vector3(thickness, thickness, rect.size.y + thickness)
	)
	_add_parcel_outline_segment(
		Vector3(rect.end.x, height, rect.position.y + rect.size.y * 0.5),
		Vector3(thickness, thickness, rect.size.y + thickness)
	)


func _add_parcel_outline_segment(center: Vector3, size: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = center
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = parcel_outline_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 10
	mesh_instance.material_override = material
	_parcel_outline_root.add_child(mesh_instance)


func _build_three_lot_layout(rect: Rect2) -> Array[Dictionary]:
	var half_size := rect.size * 0.5
	var front_axis := _choose_lot_front_axis(half_size)
	if front_axis < 0:
		return []

	var lots: Array[Dictionary] = []
	if front_axis == 0:
		lots.append({
			"rect": Rect2(rect.position, half_size),
			"front_side": 0,
		})
		lots.append({
			"rect": Rect2(rect.position + Vector2(half_size.x, 0.0), half_size),
			"front_side": 0,
		})
		lots.append({
			"rect": Rect2(rect.position + Vector2(0.0, half_size.y), Vector2(rect.size.x, half_size.y)),
			"front_side": 2,
		})
	else:
		lots.append({
			"rect": Rect2(rect.position, half_size),
			"front_side": 3,
		})
		lots.append({
			"rect": Rect2(rect.position + Vector2(0.0, half_size.y), half_size),
			"front_side": 3,
		})
		lots.append({
			"rect": Rect2(rect.position + Vector2(half_size.x, 0.0), Vector2(half_size.x, rect.size.y)),
			"front_side": 1,
		})
	return lots


func _choose_lot_front_axis(lot_size: Vector2) -> int:
	var raw_frontage := minimum_lot_frontage + house_parcel_boundary_inset * 2.0
	var raw_depth := minimum_lot_depth + house_parcel_boundary_inset * 2.0
	var north_south_fits := lot_size.x >= raw_frontage and lot_size.y >= raw_depth
	var east_west_fits := lot_size.y >= raw_frontage and lot_size.x >= raw_depth
	if north_south_fits and east_west_fits:
		if absf(lot_size.x - lot_size.y) <= 0.01:
			return 0 if _rng == null or _rng.randi_range(0, 1) == 0 else 1
		return 0 if lot_size.y >= lot_size.x else 1
	if north_south_fits:
		return 0
	if east_west_fits:
		return 1
	return -1


func _place_piece(resolved: Dictionary, world_pos: Vector3, bitmask: int) -> void:
	var config: CityPieceConfig = resolved.get("config")
	if config == null or config.model_scene == null:
		push_warning("CityBlockGenerator: pieza '%s' sin model_scene asignado." % str(resolved.get("shape", "?")))
		return

	var instance: Node3D = config.model_scene.instantiate()
	var local_aabb := _compute_local_aabb(instance)

	var socket := Node3D.new()
	add_child(socket)
	socket.position = world_pos
	socket.rotation_degrees.y = resolved["rotation_degrees"]

	# No asumimos que el pivote del modelo ya esta centrado en su propio
	# footprint (X/Z) - se centra a mano restando el centro real del AABB
	# medido, igual criterio que aplica Y (apoyar sobre el piso). Sin esto,
	# cualquier pivote descentrado hace que la pieza se corra del centro
	# del tile en X/Z apenas se rota (el offset de pivote rota CON la
	# pieza), lo que se ve como calles que no calzan / cruces "movidos".
	var center_offset := Vector3(
		-(local_aabb.position.x + local_aabb.size.x * 0.5),
		-local_aabb.position.y,
		-(local_aabb.position.z + local_aabb.size.z * 0.5)
	)

	if config.use_auto_box:
		var half_x := local_aabb.size.x * 0.5
		var half_z := local_aabb.size.z * 0.5
		config.box_min = Vector3(-half_x, 0.0, -half_z)
		config.box_max = Vector3(half_x, local_aabb.size.y, half_z)

	instance.transform = Transform3D(Basis(), center_offset)
	socket.add_child(instance)
	_add_static_mesh_collision(instance)
	if show_piece_boxes:
		_add_socket_box_visual(socket, config.box_min, config.box_max)

	var shape: String = resolved.get("shape", "")
	if scatter_lights and shape in ["corner", "cross"]:
		_add_intersection_light(world_pos, bitmask, shape)


## Coloca road_1_sheer fuera del borde, con su extremo interior tocando el
## borde exterior de la cross. No se asume que mide un tile: se mide el AABB
## real (48m de largo en el pack actual), se centra su pivote y se calcula
## la distancia del socket usando mitad del cross + mitad de la entrada -
## piece_overlap. El bit exterior tambien define si va a N/S/E/O.
func _place_entry_road(world_pos: Vector3, outward_bit: int) -> void:
	var config := entry_road_config
	if config == null or config.model_scene == null:
		push_warning("CityBlockGenerator: entrada exterior sin model_scene asignado.")
		return

	var instance: Node3D = config.model_scene.instantiate()
	var local_aabb := _compute_local_aabb(instance)
	var outward_index := _bit_to_direction_index(outward_bit)
	var inward_bit := 1 << ((outward_index + 2) % 4)
	var target_openings := outward_bit | inward_bit
	var rotation_steps := CityPieceCatalog._find_rotation_steps(config.canonical_openings, target_openings)
	var rotation_degrees := rotation_steps * 90.0 * config.rotation_direction + entry_road_rotation_offset_degrees
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(rotation_degrees))
	var oriented_aabb: AABB = Transform3D(rotation_basis, Vector3.ZERO) * local_aabb
	var outward_direction := _bit_to_direction(outward_bit)
	var road_length := oriented_aabb.size.x if absf(outward_direction.x) > 0.5 else oriented_aabb.size.z
	var center_distance := tile_size * 0.5 + road_length * 0.5 - piece_overlap
	var lateral_shift := Vector3.ZERO
	if entry_road_align_to_cross_corner:
		lateral_shift = _compute_entry_corner_lateral_shift(instance, local_aabb, rotation_basis, outward_direction)

	var socket := Node3D.new()
	add_child(socket)
	socket.position = world_pos + outward_direction * center_distance + lateral_shift
	socket.rotation_degrees.y = rotation_degrees

	var center_offset := Vector3(
		-(local_aabb.position.x + local_aabb.size.x * 0.5),
		-local_aabb.position.y,
		-(local_aabb.position.z + local_aabb.size.z * 0.5)
	)
	instance.transform = Transform3D(Basis(), center_offset)
	socket.add_child(instance)
	_add_static_mesh_collision(instance)

	if config.use_auto_box:
		config.box_min = Vector3(-local_aabb.size.x * 0.5, 0.0, -local_aabb.size.z * 0.5)
		config.box_max = Vector3(local_aabb.size.x * 0.5, local_aabb.size.y, local_aabb.size.z * 0.5)
	if show_entry_road_boxes:
		_add_socket_box_visual(socket, config.box_min, config.box_max)


## Devuelve el desplazamiento lateral necesario para que el centro de la
## calzada visible en el extremo interior de road_1_sheer coincida con el
## centro de la calzada en la orilla de la cross. La entrada tiene una
## seccion de Road de 11.2m, igual que la cross (-5.6..+5.6); usar la mitad
## del tile aqui la llevaba a la esquina/banqueta en vez de a la calle.
func _compute_entry_corner_lateral_shift(root: Node3D, local_aabb: AABB, rotation_basis: Basis, outward_direction: Vector3) -> Vector3:
	var road_vertices: Array[Vector3] = []
	_collect_surface_vertices(root, Transform3D.IDENTITY, "Road", road_vertices)
	if road_vertices.is_empty():
		return Vector3.ZERO

	var road_aabb := AABB(road_vertices[0], Vector3.ZERO)
	for vertex in road_vertices.slice(1):
		road_aabb = road_aabb.expand(vertex)

	var long_axis_is_x := road_aabb.size.x >= road_aabb.size.z
	var local_long_axis := Vector3.RIGHT if long_axis_is_x else Vector3.BACK
	var outward_long_axis_world := rotation_basis * local_long_axis
	var outward_is_positive_local := outward_long_axis_world.dot(outward_direction) > 0.0
	var inner_long_coordinate: float
	if long_axis_is_x:
		inner_long_coordinate = road_aabb.position.x if outward_is_positive_local else road_aabb.end.x
	else:
		inner_long_coordinate = road_aabb.position.z if outward_is_positive_local else road_aabb.end.z

	var endpoint_tolerance := 0.05
	var endpoint_lateral_sum := 0.0
	var endpoint_count := 0
	for vertex in road_vertices:
		var longitudinal_value := vertex.x if long_axis_is_x else vertex.z
		if absf(longitudinal_value - inner_long_coordinate) > endpoint_tolerance:
			continue
		endpoint_lateral_sum += vertex.z if long_axis_is_x else vertex.x
		endpoint_count += 1
	if endpoint_count == 0:
		return Vector3.ZERO

	var endpoint_lateral_local := endpoint_lateral_sum / endpoint_count
	var model_lateral_center := local_aabb.position.z + local_aabb.size.z * 0.5 if long_axis_is_x else local_aabb.position.x + local_aabb.size.x * 0.5
	var endpoint_lateral_relative := endpoint_lateral_local - model_lateral_center
	var local_lateral_vector := Vector3(0.0, 0.0, endpoint_lateral_relative) if long_axis_is_x else Vector3(endpoint_lateral_relative, 0.0, 0.0)
	var endpoint_lateral_world_vector := rotation_basis * local_lateral_vector
	var world_lateral_axis := Vector3(0.0, 0.0, 1.0) if absf(outward_direction.x) > 0.5 else Vector3(1.0, 0.0, 0.0)
	var endpoint_lateral_world := endpoint_lateral_world_vector.dot(world_lateral_axis)
	if is_zero_approx(endpoint_lateral_world):
		return Vector3.ZERO

	# El centro lateral de la calzada de la cross es 0 despues de centrar su
	# AABB. `tile_size * 0.5` solo corresponde al borde LONGITUDINAL de la
	# calle; usarlo tambien aqui ponia el tramo diagonal en la banqueta.
	var target_lateral_world := 0.0
	return world_lateral_axis * (target_lateral_world - endpoint_lateral_world)


## Las piezas de calle (rectas, cruces, entradas) son escenas FBX importadas
## que hasta ahora solo se agregaban como visual - sin esto el jugador
## caminaba sobre la colision del terreno de ChunkManager (aplanado, pero a
## veces con un pequeno desnivel respecto a la superficie visible de la
## calle) en vez de la calle misma, lo que se sentia como "la calle no tiene
## colision". Recorre todos los MeshInstance3D del modelo instanciado y les
## agrega colision trimesh exacta (mismo patron que HouseGenerator usa para
## las casas).
func _add_static_mesh_collision(root: Node) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).create_trimesh_collision()
	for child in root.get_children():
		_add_static_mesh_collision(child)


func _collect_surface_vertices(node: Node, relative_transform: Transform3D, material_name: String, output: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			for surface_index in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface_index)
				if material == null or material.resource_name.to_lower() != material_name.to_lower():
					continue
				var arrays: Array = mesh.surface_get_arrays(surface_index)
				if arrays.is_empty():
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					output.append(relative_transform * vertex)

	for child in node.get_children():
		if child is Node3D:
			_collect_surface_vertices(child, relative_transform * (child as Node3D).transform, material_name, output)
		else:
			_collect_surface_vertices(child, relative_transform, material_name, output)


func _bit_to_direction_index(bitmask: int) -> int:
	for direction_index in range(4):
		if bitmask & (1 << direction_index):
			return direction_index
	return 0


func _bit_to_direction(bitmask: int) -> Vector3:
	match _bit_to_direction_index(bitmask):
		0:
			return Vector3(0.0, 0.0, -1.0)
		1:
			return Vector3(1.0, 0.0, 0.0)
		2:
			return Vector3(0.0, 0.0, 1.0)
		_:
			return Vector3(-1.0, 0.0, 0.0)


## En una cruz de 4 calles seleccionada pone un semaforo en CADA una de las
## 4 esquinas (NE/SE/SO/NO), para cubrir las cuatro aproximaciones. Las T no
## reciben semaforos. En una esquina simple pone la linterna. Las posiciones
## se expresan en espacio de mundo, igual que `bitmask`, para no depender de
## la rotacion del socket de la pieza.
func _add_intersection_light(world_pos: Vector3, bitmask: int, shape: String) -> void:
	var is_real_intersection := shape == "cross"
	if shape == "cross" and _rng != null and _rng.randf() > traffic_light_cross_probability:
		return
	var scene: PackedScene = traffic_light_scene if is_real_intersection else street_light_scene
	var facing_offset: float = traffic_light_facing_offset_degrees if is_real_intersection else street_light_facing_offset_degrees
	if scene == null:
		return

	var offsets: Array[Vector3] = []
	if shape == "cross":
		for corner in _get_corner_candidates():
			var corner_offset: Vector3 = corner[2]
			offsets.append(corner_offset)
	else:
		var offset = _find_open_corner_offset(bitmask)
		if offset == null:
			return
		offsets.append(offset)

	for offset in offsets:
		_add_light_instance(world_pos, offset, scene, facing_offset, is_real_intersection)


func _add_light_instance(world_pos: Vector3, offset: Vector3, scene: PackedScene, facing_offset: float, is_real_intersection: bool) -> void:
	var light_offset := offset
	if is_real_intersection and traffic_light_corner_inset > 0.0:
		light_offset -= light_offset.normalized() * traffic_light_corner_inset

	var instance: Node3D = scene.instantiate()
	var light_aabb := _compute_local_aabb(instance)
	var floor_aabb := _compute_floor_aabb(instance)
	var light_anchor_offset := Vector3(
		-(floor_aabb.position.x + floor_aabb.size.x * 0.5),
		-light_aabb.position.y,
		-(floor_aabb.position.z + floor_aabb.size.z * 0.5)
	)
	var light_socket := Node3D.new()
	add_child(light_socket)
	light_socket.position = world_pos + light_offset
	instance.transform = Transform3D(Basis(), light_anchor_offset)
	light_socket.add_child(instance)
	# El vector radial de una esquina siempre apunta en diagonal (45/135/225/
	# 315 grados). Para un semaforo real eso no sirve: debe quedar alineado
	# con uno de los ejes de la calle. Un cuarto de vuelta corrige esa
	# diagonal y, como `light_offset` cambia segun NE/SE/SO/NO, cada esquina
	# termina automaticamente mirando hacia el eje cardinal correspondiente.
	# facing_offset queda como correccion extra ajustable desde el Inspector
	# por si el modelo original no mira hacia -Z de fabrica.
	var base_facing_degrees := rad_to_deg(atan2(light_offset.x, light_offset.z))
	if is_real_intersection:
		base_facing_degrees += 45.0
	light_socket.rotation_degrees.y = base_facing_degrees + facing_offset


## Encuentra la huella de los vertices que tocan el piso de un modelo
## importado. Para traffic_light_L esto es distinto del centro de su AABB:
## el brazo y la cabeza del semaforo alargan el volumen hacia la calle,
## pero el poste debe anclarse por su base en la esquina de la banqueta.
func _compute_floor_aabb(root: Node3D) -> AABB:
	var vertices: Array[Vector3] = []
	var stack: Array = [[root, Transform3D.IDENTITY]]

	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var relative_transform: Transform3D = entry[1]

		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				for surface_index in mesh.get_surface_count():
					var arrays: Array = mesh.surface_get_arrays(surface_index)
					if arrays.is_empty():
						continue
					var mesh_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for vertex in mesh_vertices:
						vertices.append(relative_transform * vertex)

		for child in node.get_children():
			if child is Node3D:
				stack.append([child, relative_transform * (child as Node3D).transform])
			else:
				stack.append([child, relative_transform])

	if vertices.is_empty():
		return _compute_local_aabb(root)

	var min_y := INF
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)

	var floor_vertices: Array[Vector3] = []
	for vertex in vertices:
		if vertex.y <= min_y + 0.01:
			floor_vertices.append(vertex)
	if floor_vertices.is_empty():
		return _compute_local_aabb(root)

	var result := AABB(floor_vertices[0], Vector3.ZERO)
	for vertex in floor_vertices.slice(1):
		result = result.expand(vertex)
	return result


## Devuelve el offset (local al tile, en metros) de la esquina NE/SE/SO/NO
## que queda entre dos direcciones cardinales REALMENTE abiertas segun
## `bitmask` (0=Norte,1=Este,2=Sur,3=Oeste) - null si ninguna calza (no
## deberia pasar en corner/t_junction/cross, que siempre tienen al menos
## un par de lados abiertos adyacentes).
func _find_open_corner_offset(bitmask: int):
	for corner in _get_corner_candidates():
		var dir_a: int = corner[0]
		var dir_b: int = corner[1]
		if bitmask & (1 << dir_a) and bitmask & (1 << dir_b):
			return corner[2]
	return null


func _get_corner_candidates() -> Array:
	var half := tile_size * traffic_light_corner_factor
	return [
		[0, 1, Vector3(half, 0.0, -half)], # Norte+Este -> esquina NE
		[1, 2, Vector3(half, 0.0, half)], # Este+Sur -> esquina SE
		[2, 3, Vector3(-half, 0.0, half)], # Sur+Oeste -> esquina SO
		[3, 0, Vector3(-half, 0.0, -half)], # Oeste+Norte -> esquina NO
	]


## Cubo semitransparente verde con el tamaño real medido de una pieza -
## misma tecnica que DrainageDungeonGenerator._add_socket_box_visual().
func _add_socket_box_visual(socket: Node3D, box_min: Vector3, box_max: Vector3) -> void:
	var size := box_max - box_min
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = (box_min + box_max) * 0.5

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 1.0, 0.4, 0.25)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material

	socket.add_child(mesh_instance)


## Rectangulo plano naranja marcando el area libre de una manzana - solo
## para previsualizar donde van las casas mas adelante, no es geometria
## real.
func _add_block_rect_visual(rect: Rect2) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(rect.size.x, 0.05, rect.size.y)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.05, rect.position.y + rect.size.y * 0.5)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.55, 0.1, 0.25)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material

	add_child(mesh_instance)


## Combina el AABB de todas las mallas (VisualInstance3D) debajo de
## `root`, medido en su espacio local - misma tecnica que
## DrainageDungeonGenerator._compute_local_aabb().
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
