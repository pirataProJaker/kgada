extends Node3D
class_name DrainageDungeonGenerator
## Arma un nivel de drenaje completo: genera el layout logico
## (DrainageLayoutGenerator), y por cada celda instancia la pieza real del
## pack que corresponda (DrainagePieceCatalog), rotada para que sus
## aberturas calcen con las de sus vecinas.
##
## Ubicacion de las piezas: YA NO se usa una grilla de espaciado fijo
## (cell_spacing). Cada pieza mide su propia caja real (box_min/box_max,
## ver DrainagePieceConfig) y el generador recorre el layout (que siempre
## es un arbol - ver DrainageLayoutGenerator, cada celda nueva se conecta
## una sola vez a la celda que la creo) encadenando posiciones: la celda
## vecina se ubica exactamente donde termina la caja de la celda actual
## mas donde empieza la caja de la vecina en el lado que las conecta - asi
## el borde de una caja siempre toca exactamente el borde de la otra, sea
## cual sea el tamaño real de cada pieza (una recta larga, una esquina
## corta, etc.), sin estirar ni deformar ningun modelo.
##
## Mecanica principal para el "sistema de drenaje masivo" pedido - esto es
## una primera version funcional (sin colision todavia, solo layout +
## piezas visuales) para validar que el random walk + catalogo de piezas
## dan un resultado decente antes de sumarle coleccion, props, iluminacion
## por seccion, etc.


@export var rng_seed: int = 0
## Si esta activo, se ignora `rng_seed` y se sortea una semilla nueva cada
## vez que corre la escena (usando randi() del RNG global, ya
## randomizado por Godot al arrancar) - asi cada corrida da un dungeon
## distinto. Desactivar esto (y fijar `rng_seed` a mano) si se necesita
## reproducir siempre el mismo layout para debuguear.
@export var randomize_seed_on_run: bool = true
@export var target_cell_count: int = 80
@export var branch_chance: float = 0.22
## Probabilidad de que dos ramas del laberinto que ya estan cerca (celdas
## vecinas en la grilla logica, pero que llegaron ahi por caminos
## distintos) se conecten entre si en vez de quedar aisladas - sin esto,
## cada rama es un callejon que nunca se vuelve a topar con otra (un
## arbol puro); con esto el nivel tiene loops/atajos y se siente mas como
## un laberinto real donde uno se puede perder. Ver DrainageLayoutGenerator.generate().
@export var loop_chance: float = 0.22

@export_group("Ubicacion de las piezas")
## Altura (Y) a la que se colocan todas las piezas del nivel.
@export var piece_height: float = 0.0
## Cuanto se superponen (metros) las cajas de dos celdas vecinas al
## encadenar posiciones - las cajas medidas (oriented_aabb) a veces dejan
## una rendija minima visible entre pieza y pieza (imprecision del propio
## modelo/import), asi que se acercan levemente de mas para que no quede
## hueco. 0 = bordes exactos sin superposicion.
@export var piece_overlap: float = 0.03
## Muestra, para cada pieza colocada, la caja real (box_min/box_max,
## calculada automaticamente midiendo el modelo) como un cubo
## semitransparente - sirve para verificar que las cajas conectan borde
## con borde entre celdas vecinas.
@export var show_piece_boxes: bool = true

@export_group("Piezas (que forma usa cada una)")
## Cada uno define que nodo del pack usar y hacia donde abre esa pieza SIN
## rotar (Norte/Este/Sur/Oeste) - ver world/drainage/drainage_piece_config.gd.
@export var dead_end_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/dead_end.tres")
@export var straight_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/straight.tres")
@export var corner_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/corner.tres")
@export var t_junction_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/t_junction.tres")
@export var cross_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/cross.tres")

@export_group("Entrada (pozo con escalera)")
## Si esta activo, la celda de entrada del dungeon (siempre un dead_end,
## ver DrainageLayoutGenerator/find_farthest_cell) usa Serwers01_006 (el
## unico nodo del pack con una abertura vertical de arriba hacia abajo por
## el centro, ver assets/drenaje/Models/Sewers.fbx) en vez de la pieza
## dead_end normal, y se le agrega una escalera procedural (sin modelo
## externo, ver _build_ladder) para subir/bajar por ese hueco. La
## abertura HORIZONTAL de esta pieza sigue calzando igual que un dead_end
## normal (mismo canonical_openings/rotation_direction, ver
## piece_configs/vertical_shaft.tres) - lo unico que cambia es el modelo y
## que agrega el hueco+escalera hacia arriba.
@export var use_vertical_shaft_at_entrance: bool = true
@export var vertical_shaft_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/vertical_shaft.tres")
## Cuanto sobresale la escalera (metros) por ENCIMA del techo real de la
## pieza (oriented_aabb.size.y, medido del modelo) - el largo total de la
## escalera es techo_de_la_pieza + este valor, para que siempre alcance a
## salir por el hueco de arriba sin importar que tan alta sea la pieza.
## Antes era un alto fijo (3.5m) que no tomaba en cuenta la altura real
## del modelo y se quedaba corta; luego se vio en el editor que quedaba
## unos 11 peldaños larga de mas, asi que se le resto 11*rung_spacing
## (0.3m c/u = 3.3m) a los 3.0m originales.
@export var ladder_surface_exit_height: float = -0.3
## Cuanto se corre la escalera (metros, offset FIJO, no relativo al tamaño
## de la pieza) desde el centro real de la pieza de entrada hacia el lado
## tapado (open_dir_index) - solo para que no quede bloqueando el paso
## justo por el medio del hueco. Un empujoncito chico (~30cm), la entrada
## sigue estando esencialmente al centro del modelo.
@export var ladder_back_offset: float = 0.60

@export_group("Decoracion (props sueltos: basura, escombros, etc.)")
## El pack Sewers.fbx trae 52 nodos sueltos SIN el prefijo "Serwers" (no
## son parte de la estructura del tunel) - la lista de abajo son los que
## se ven como basura/escombros tirados (se dejaron afuera adrede Pipe_*/
## door_metal_* porque son mas bien accesorios de instalacion que
## "basura", no props sueltos para tirar al piso).
@export var scatter_props: bool = true
@export var props_per_cell_min: int = 0
@export var props_per_cell_max: int = 3
const PROP_NAMES: Array[String] = [
	"Trash", "Trash_001", "Trash_002", "Trash_003", "Trash_004", "Trash_005",
	"Trash_006", "Trash_007", "Trash_008", "Trash_009", "Trash_010",
	"Trash_011", "Trash_012", "Trash_013", "Trash_M", "Trash_M_01",
	"debris", "debris_01", "debris_02", "debris_03", "debris_04", "debris_05",
	"Garbage_bag", "Garbage_bag_001", "Box_T", "Box_T_01", "Box_T_02",
	"Box_T_03", "Bricks", "Brick", "Tire", "Cylinder", "TB",
]

@export_group("Agua sucia (canal central)")
## Pone, al centro de cada pieza (donde el modelo tiene el leve hundimiento
## del canal), una malla de agua sucia en forma de "cruz de rectangulos":
## un cuadrado central siempre presente + un brazo por cada abertura
## REAL de la pieza (canonical_openings, ver DrainagePieceConfig - mismo
## espacio que oriented_aabb, o sea pre-rotacion de socket) que llega
## hasta borde de la pieza (para calzar con el brazo de la celda vecina) -
## los lados SIN abertura (pared) no generan brazo, se quedan en el borde
## del cuadrado central, nunca atraviesan una pared.
@export var scatter_water: bool = true
## Que tan ancho es el canal en relacion al ancho REAL de la pieza en esa
## direccion (1.0 = mismo ancho que el modelo, tocando pared a pared;
## menos que eso deja un margen visible de piso seco a los lados). Antes
## era un ancho fijo en metros (0.6) que se veia como una tira angosta -
## ahora escala con cada pieza, asi puede ser "tan ancho como el modelo"
## sin quedar angosto en piezas grandes ni desbordado en piezas chicas.
@export_range(0.1, 1.0, 0.01) var water_width_ratio: float = 0.92
@export var water_thickness: float = 0.04
## Altura (Y, relativa al piso de la pieza) a la que flota la malla de
## agua - un valor chico simula que corre por el fondo del hundimiento
## del canal sin enterrarse en el piso (z-fighting).
@export var water_height_offset: float = 0.03
## Cuanto se acerca el brazo al borde real de la pieza (mismo criterio
## que piece_overlap, pero en sentido contrario: NEGATIVO = el brazo se
## pasa un poco del borde de su propia pieza, hacia la pieza vecina, para
## GARANTIZAR que las dos mallas se toquen/superpongan de sobra en vez de
## dejar un hueco - como el material ahora es opaco (ver
## _build_merged_water_mesh) superponerse no se nota, as que conviene
## pasarse un poco de largo antes que quedar corto y dejar un hueco de
## piso seco entre dos piezas.
@export var water_edge_margin: float = -0.08
@export var water_color: Color = Color(0.16, 0.16, 0.07, 0.85)

var entrance_cell: Vector2i
var exit_cell: Vector2i

var _piece_source: Node3D
var _catalog: DrainagePieceCatalog
## Vector2i (celda del layout) -> Vector3 (posicion mundial X/Z ya
## encadenada por cajas; Y siempre 0 aca, se suma piece_height aparte).
## Se llena en _instance_layout() y lo usa _mark_entrance_and_exit().
var _cell_world_positions: Dictionary = {}
## Cajas de agua encoladas por _queue_water_box (cada una
## {"transform": Transform3D, "size": Vector3}, ya en espacio relativo a
## este generador) - se vacia y se consume una unica vez en
## _build_merged_water_mesh(), al final de _instance_layout().
var _pending_water_boxes: Array = []
## Nombre del nodo (config.node_name) -> {original_basis, oriented_aabb} -
## cache para no recalcular el AABB del mismo modelo una vez por cada
## celda que lo use (varias celdas pueden compartir, por ejemplo, la misma
## pieza "recta").
var _piece_measure_cache: Dictionary = {}


func _ready() -> void:
	_catalog = DrainagePieceCatalog.new({
		"dead_end": dead_end_config,
		"straight": straight_config,
		"corner": corner_config,
		"t_junction": t_junction_config,
		"cross": cross_config,
	})

	_piece_source = load(DrainagePieceCatalog.PIECE_SOURCE_PATH).instantiate()
	add_child(_piece_source)
	_piece_source.visible = false

	if randomize_seed_on_run:
		rng_seed = randi()

	var layout := DrainageLayoutGenerator.generate(rng_seed, target_cell_count, branch_chance, loop_chance)
	entrance_cell = Vector2i.ZERO
	exit_cell = DrainageLayoutGenerator.find_farthest_cell(layout, entrance_cell)
	_instance_layout(layout)
	_mark_entrance_and_exit()

	print("[DrainageDungeonGenerator] %d celdas generadas. Entrada: %s Salida: %s" % [layout.size(), entrance_cell, exit_cell])


func _instance_layout(layout: Dictionary) -> void:
	# Paso 1: medir cada celda (que pieza, que rotacion, que caja real
	# tiene) SIN instanciar nada todavia - _piece_source sigue vivo asi que
	# se puede medir directo sobre el template compartido.
	var cell_data: Dictionary = {} # Vector2i -> Dictionary de medidas
	for cell in layout.keys():
		var bitmask: int = layout[cell]
		var is_vertical_shaft: bool = use_vertical_shaft_at_entrance and cell == entrance_cell and vertical_shaft_config != null
		var effective_bitmask := bitmask
		var open_dir_index := -1
		if is_vertical_shaft:
			# Serwers01_006 es un TUNEL RECTO (2 aberturas, un par opuesto -
			# ver vertical_shaft.tres, canonical_openings=5 igual que
			# straight.tres), no un dead_end de verdad (que tiene solo 1). El
			# layout solo conecta esta celda por 1 lado (es una punta del
			# arbol), asi que el lado OPUESTO al conectado queda con la
			# abertura del modelo mirando al vacio - por eso se agrega ese
			# bit al bitmask objetivo (asi la rotacion sigue calzando el
			# lado conectado) y, mas abajo, se tapa ese lado con una celda
			# "fantasma" (dead_end normal) que no es parte del layout real.
			var connected_dir_index := _single_bit_index(bitmask)
			open_dir_index = DrainageLayoutGenerator.OPPOSITE_DIRECTION_INDEX[connected_dir_index]
			effective_bitmask = bitmask | (1 << open_dir_index)
		var resolved := _resolve_override(effective_bitmask, vertical_shaft_config) if is_vertical_shaft else _catalog.resolve(bitmask)
		var measured := _measure_piece(resolved)
		if measured.is_empty():
			continue
		measured["bitmask"] = effective_bitmask
		measured["cell"] = cell
		measured["is_vertical_shaft"] = is_vertical_shaft
		measured["open_dir_index"] = open_dir_index
		cell_data[cell] = measured

		if is_vertical_shaft and open_dir_index >= 0:
			var phantom_cell: Vector2i = cell + DrainageLayoutGenerator.DIRECTIONS[open_dir_index]
			if not layout.has(phantom_cell) and not cell_data.has(phantom_cell):
				var phantom_bitmask: int = 1 << DrainageLayoutGenerator.OPPOSITE_DIRECTION_INDEX[open_dir_index]
				var phantom_resolved := _catalog.resolve(phantom_bitmask)
				var phantom_measured := _measure_piece(phantom_resolved)
				if not phantom_measured.is_empty():
					phantom_measured["bitmask"] = phantom_bitmask
					phantom_measured["cell"] = phantom_cell
					phantom_measured["is_vertical_shaft"] = false
					cell_data[phantom_cell] = phantom_measured

	# Paso 2: recorrer el layout (siempre es un arbol, ver
	# DrainageLayoutGenerator) encadenando posiciones: la celda vecina se
	# ubica donde termina la caja de la celda actual + donde empieza la
	# caja de la vecina, en el lado que las conecta - asi los bordes
	# siempre calzan al milimetro sin importar el tamaño real de cada
	# pieza.
	_cell_world_positions = _compute_cell_positions(layout, cell_data)

	# Paso 3: recien aca se instancia (duplica) cada pieza, ya con su
	# posicion final calculada.
	for cell in cell_data.keys():
		_place_piece(cell_data[cell], _cell_world_positions.get(cell, Vector3.ZERO))

	if scatter_water:
		_build_merged_water_mesh()

	_piece_source.queue_free()
	_piece_source = null


## Busca el template de la pieza que pide `resolved` y mide su caja real
## (sin escalar, sin pivotear) en dos espacios:
## - oriented_aabb: espacio "orientado" (post correccion FBX, PRE rotacion
##   de socket) - es el mismo espacio en el que se para la pieza final.
## - rotated_aabb: oriented_aabb ya rotado por la rotacion de socket que
##   le toca a esta celda - este es el que se usa para saber cuanto mide
##   la pieza hacia cada direccion CARDINAL del mundo (Norte/Este/Sur/
##   Oeste), que es lo que hace falta para encadenar posiciones.
func _measure_piece(resolved: Dictionary) -> Dictionary:
	var node_name: String = resolved.get("node", "")
	var template: Node3D = _piece_source.find_child(node_name, true, false)
	if template == null:
		push_warning("DrainageDungeonGenerator: no se encontro la pieza '%s' en %s" % [node_name, DrainagePieceCatalog.PIECE_SOURCE_PATH])
		return {}

	var base_measure: Dictionary = _piece_measure_cache.get(node_name, {})
	if base_measure.is_empty():
		# La rotacion/escala "correcta" de la pieza (para que se vea
		# acostada y a su tamaño real, tal como se ve en
		# tests/drenaje_pieces_test.tscn) viene acumulada desde la raiz del
		# diorama, no es identidad - por eso se toma el basis GLOBAL de la
		# pieza mientras todavia esta parada en su jerarquia original
		# (leerlo despues de duplicate() no sirve, la copia sale sin padre
		# y su global_transform ya no significa lo mismo).
		var original_basis := template.global_transform.basis
		var local_aabb := _compute_local_aabb(template)
		var oriented_aabb: AABB = Transform3D(original_basis, Vector3.ZERO) * local_aabb
		base_measure = {"original_basis": original_basis, "oriented_aabb": oriented_aabb}
		_piece_measure_cache[node_name] = base_measure

	var rotation_degrees: float = resolved.get("rotation_degrees", 0.0)
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(rotation_degrees))
	var rotated_aabb: AABB = Transform3D(rotation_basis, Vector3.ZERO) * (base_measure["oriented_aabb"] as AABB)

	return {
		"resolved": resolved,
		"template": template,
		"original_basis": base_measure["original_basis"],
		"oriented_aabb": base_measure["oriented_aabb"],
		"rotated_aabb": rotated_aabb,
	}


## BFS desde entrance_cell (el layout siempre es un arbol - cada celda
## nueva se conecta una unica vez a la celda que la creo, ver
## DrainageLayoutGenerator) calculando, celda por celda, la posicion
## mundial X/Z que hace que la caja de cada celda toque exactamente la
## caja de su vecina ya posicionada.
func _compute_cell_positions(layout: Dictionary, cell_data: Dictionary) -> Dictionary:
	var positions: Dictionary = {entrance_cell: Vector3.ZERO}
	var queue: Array[Vector2i] = [entrance_cell]
	var head := 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if not cell_data.has(current):
			continue

		var current_measure: Dictionary = cell_data[current]
		var current_bitmask: int = current_measure["bitmask"]
		var current_pos: Vector3 = positions[current]

		for dir_index in range(DrainageLayoutGenerator.DIRECTIONS.size()):
			if current_bitmask & (1 << dir_index) == 0:
				continue

			var dir_vector: Vector2i = DrainageLayoutGenerator.DIRECTIONS[dir_index]
			var neighbor: Vector2i = current + dir_vector
			if positions.has(neighbor) or not cell_data.has(neighbor):
				continue

			var neighbor_measure: Dictionary = cell_data[neighbor]
			var opposite_index: int = DrainageLayoutGenerator.OPPOSITE_DIRECTION_INDEX[dir_index]

			var current_dist := _edge_distance(current_measure["rotated_aabb"], dir_index)
			var neighbor_dist := _edge_distance(neighbor_measure["rotated_aabb"], opposite_index)

			positions[neighbor] = current_pos + Vector3(dir_vector.x, 0.0, dir_vector.y) * (current_dist + neighbor_dist - piece_overlap)
			queue.append(neighbor)

	return positions


## Distancia (positiva) desde el origen de `aabb` hasta su borde que mira
## hacia `dir_index` (0=Norte/-Z, 1=Este/+X, 2=Sur/+Z, 3=Oeste/-X) - no
## asume que el origen este centrado ni dentro de la caja, solo lee el
## borde correspondiente tal cual quedo despues de rotar.
static func _edge_distance(aabb: AABB, dir_index: int) -> float:
	match dir_index:
		0:
			return -aabb.position.z
		1:
			return aabb.position.x + aabb.size.x
		2:
			return aabb.position.z + aabb.size.z
		_:
			return -aabb.position.x


## Devuelve el indice (0..3) del unico bit prendido de `mask` - se usa para
## las celdas dead_end del layout (siempre tienen exactamente 1 bit) al
## calcular el lado "abierto" (opuesto al conectado) de la pieza del pozo
## vertical (Serwers01_006). Si mask viniera vacio (no deberia pasar para
## un dead_end real) devuelve 0 como fallback silencioso.
static func _single_bit_index(mask: int) -> int:
	for i in range(4):
		if mask & (1 << i):
			return i
	return 0


## Convierte un vector direccion (en el plano X/Z) al mismo indice N/E/S/O
## (0..3) que usa _edge_distance - se usa para saber, YA en espacio local
## de la pieza (post rotacion inversa), hacia que lado cae una direccion
## que se conocia en espacio mundial (ver _add_ladder).
static func _vector_to_dir_index(v: Vector3) -> int:
	if absf(v.x) >= absf(v.z):
		return 1 if v.x > 0.0 else 3
	return 2 if v.z > 0.0 else 0


## Instancia (duplica) la pieza medida por _measure_piece() y la deja
## parada exactamente en `world_xz` (X/Z ya encadenados por cajas, ver
## _compute_cell_positions - Y se resuelve con piece_height). No escala ni
## pivotea nada: la pieza se usa a su tamaño real, tal cual la mide
## oriented_aabb.
func _place_piece(measure: Dictionary, world_xz: Vector3) -> void:
	var resolved: Dictionary = measure["resolved"]
	var template: Node3D = measure["template"]
	var original_basis: Basis = measure["original_basis"]
	var oriented_aabb: AABB = measure["oriented_aabb"]

	var instance: Node3D = template.duplicate()

	var socket := Node3D.new()
	add_child(socket)
	socket.position = Vector3(world_xz.x, piece_height, world_xz.z)
	socket.rotation_degrees.y = resolved["rotation_degrees"]

	socket.add_child(instance)
	# Solo se corrige la altura (para que la base de la pieza quede en
	# Y=0 dentro del socket) - en X/Z el origen de la pieza queda tal cual
	# esta en oriented_aabb, que es el mismo espacio usado para calcular
	# world_xz, asi que calzan sin ningun offset extra.
	instance.transform = Transform3D(original_basis, Vector3(0.0, -oriented_aabb.position.y, 0.0))

	# Caja real (box_min/box_max en el *_config.tres) - mismo espacio que
	# oriented_aabb, sin escalar: es la caja que efectivamente se uso para
	# encadenar la posicion de esta pieza con sus vecinas.
	var config: DrainagePieceConfig = resolved.get("config")
	if config != null:
		if config.use_auto_box:
			config.box_min = Vector3(oriented_aabb.position.x, 0.0, oriented_aabb.position.z)
			config.box_max = Vector3(oriented_aabb.position.x + oriented_aabb.size.x, oriented_aabb.size.y, oriented_aabb.position.z + oriented_aabb.size.z)

		if show_piece_boxes:
			_add_socket_box_visual(socket, config.box_min, config.box_max)

	if measure.get("is_vertical_shaft", false):
		_add_ladder(socket, oriented_aabb, measure.get("open_dir_index", -1))

	if scatter_water:
		var canonical_openings: int = resolved.get("canonical_openings", 0)
		_add_water(socket, oriented_aabb, canonical_openings)

	if scatter_props:
		_scatter_cell_props(socket, oriented_aabb, measure.get("cell", Vector2i.ZERO))


## Version de DrainagePieceCatalog.resolve() que fuerza el uso de
## `override_config` en vez de resolver por bitmask contra el catalogo de
## las 5 formas normales (dead_end/straight/corner/t_junction/cross) -
## usado para la celda de entrada, que quiere el mismo calce de aberturas
## que un dead_end pero con el modelo Serwers01_006 (pozo vertical) en su
## lugar. `canonical_openings`/`rotation_direction` de vertical_shaft.tres
## deberian describir la MISMA abertura horizontal que dead_end.tres (son
## piezas de una sola abertura) - si al probar se ve girada, corregir esos
## dos valores igual que se hizo con dead_end (ver /memories/repo/
## drenaje-piece-catalog.md, Fix 16/17).
func _resolve_override(bitmask: int, override_config: DrainagePieceConfig) -> Dictionary:
	var steps := DrainagePieceCatalog._find_rotation_steps(override_config.canonical_openings, bitmask)
	return {
		"node": override_config.node_name,
		"rotation_degrees": steps * 90.0 * override_config.rotation_direction,
		"canonical_openings": override_config.canonical_openings,
		"config": override_config,
	}


## Escalera procedural (sin modelo externo) para subir/bajar por el hueco
## vertical de Serwers01_006 - dos rieles laterales + peldaños cada 0.3m.
## El LARGO total se calcula en base a la altura real del techo de la
## pieza (oriented_aabb.size.y) + ladder_surface_exit_height, para que
## siempre sobresalga por el hueco de arriba sin quedar corta (antes
## usaba un alto fijo que no consideraba el techo real del modelo).
##
## Posicion en X/Z: en vez de centrarla en el medio del tunel (ahi
## bloqueaba el paso, quedaba "pasando por el puro medio"), se corre
## hacia el lado tapado (open_dir_index - el mismo lado que cierra la
## celda fantasma agregada en _instance_layout, ver Fix 20 en
## /memories/repo/drenaje-piece-catalog.md), pegada casi contra esa pared
## (wall_margin de separacion) - asi queda contra la pared del "pozo de
## salida a la superficie" en vez de tapar el pasillo. Si open_dir_index
## es -1 (no deberia pasar para la pieza de entrada) cae de vuelta al
## centro como antes.
func _add_ladder(socket: Node3D, oriented_aabb: AABB, open_dir_index: int) -> void:
	var ladder_x := oriented_aabb.position.x + oriented_aabb.size.x * 0.5
	var ladder_z := oriented_aabb.position.z + oriented_aabb.size.z * 0.5
	var total_height := oriented_aabb.size.y + ladder_surface_exit_height

	if open_dir_index >= 0:
		# La entrada (el hueco vertical) esta al CENTRO real de esta pieza -
		# ladder_x/ladder_z ya la dejan ahi. Lo unico que hace falta es un
		# empujoncito CHICO Y FIJO hacia el lado tapado (open_dir_index) para
		# que no quede bloqueando el paso exactamente por el medio - NO se
		# debe calcular en base a que tan lejos esta el borde de la pieza
		# (eso fue el bug anterior: con edge_dist grande, offset = edge_dist
		# - margin seguia siendo un numero grande, la escalera terminaba
		# lejos del centro otra vez). `ladder_back_offset` es simplemente
		# cuanto se corre, sin importar el tamaño de la pieza.
		var world_dir: Vector2i = DrainageLayoutGenerator.DIRECTIONS[open_dir_index]
		var local_dir: Vector3 = (socket.transform.basis.inverse() * Vector3(world_dir.x, 0.0, world_dir.y)).normalized()
		var local_dir_index := _vector_to_dir_index(local_dir)
		match local_dir_index:
			0:
				ladder_z -= ladder_back_offset
			1:
				ladder_x += ladder_back_offset
			2:
				ladder_z += ladder_back_offset
			_:
				ladder_x -= ladder_back_offset

	var ladder := Node3D.new()
	ladder.position = Vector3(ladder_x, 0.0, ladder_z)
	socket.add_child(ladder)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.35, 0.38)
	material.metallic = 0.6
	material.roughness = 0.4

	var rail_width := 0.06
	var rung_spacing := 0.3
	var rail_offset_x := 0.3

	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(rail_width, total_height, rail_width)
		rail.mesh = rail_mesh
		rail.material_override = material
		rail.position = Vector3(side * rail_offset_x, total_height * 0.5, 0.0)
		ladder.add_child(rail)

	var rung_count := int(total_height / rung_spacing)
	for i in range(rung_count):
		var rung := MeshInstance3D.new()
		var rung_mesh := BoxMesh.new()
		rung_mesh.size = Vector3(rail_offset_x * 2.0, rail_width, rail_width)
		rung.mesh = rung_mesh
		rung.material_override = material
		rung.position = Vector3(0.0, rung_spacing * (i + 1), 0.0)
		ladder.add_child(rung)


## Agua sucia al centro de cada pieza: un cuadrado central (siempre
## presente, es el "cruce" del canal) + un brazo por cada abertura REAL de
## la pieza (canonical_openings - mismo espacio pre-rotacion que
## oriented_aabb, ver DrainagePieceCatalog.resolve) que llega hasta el
## borde de la pieza en esa direccion, para calzar con el brazo de la
## celda vecina. Los lados SIN abertura (pared) simplemente no generan
## brazo - la malla nunca pasa del borde del cuadrado central hacia ese
## lado, o sea nunca atraviesa una pared.
##
## No crea ningun MeshInstance3D aca - solo ENCOLA las cajas (en espacio
## mundial, ver _queue_water_box) en `_pending_water_boxes`; recien al
## final de _instance_layout() se combinan TODAS en una sola malla (ver
## _build_merged_water_mesh) para que se vea como un unico cuerpo de agua
## continuo en vez de N mallas separadas que se notan como "union"/costura
## (doble transparencia superpuesta) donde dos piezas se tocan.
func _add_water(socket: Node3D, oriented_aabb: AABB, canonical_openings: int) -> void:
	var center_x := oriented_aabb.position.x + oriented_aabb.size.x * 0.5
	var center_z := oriented_aabb.position.z + oriented_aabb.size.z * 0.5
	# Ancho real del canal en cada eje, escalado al tamaño real de ESTA
	# pieza (water_width_ratio = 1.0 seria pared a pared) - asi una pieza
	# grande (recta larga) y una chica (esquina) quedan cada una con un
	# canal proporcional a su propio ancho, no un valor fijo que se ve
	# angosto en unas y desbordado en otras.
	var width_x := oriented_aabb.size.x * water_width_ratio
	var width_z := oriented_aabb.size.z * water_width_ratio
	var half_x := width_x * 0.5
	var half_z := width_z * 0.5
	var base_pos := Vector3(center_x, water_height_offset, center_z)

	_queue_water_box(socket, Vector3(width_x, water_thickness, width_z), base_pos)

	for dir_index in range(4):
		if canonical_openings & (1 << dir_index) == 0:
			continue

		var center_edge_dist := _center_edge_distance(oriented_aabb, dir_index, center_x, center_z)
		var is_z_axis := dir_index == 0 or dir_index == 2
		var half_along := half_z if is_z_axis else half_x
		var arm_length := center_edge_dist - water_edge_margin - half_along
		if arm_length <= 0.0:
			continue

		var box_size: Vector3
		var box_pos: Vector3
		match dir_index:
			0:
				box_size = Vector3(width_x, water_thickness, arm_length)
				box_pos = base_pos + Vector3(0.0, 0.0, -(half_z + arm_length * 0.5))
			1:
				box_size = Vector3(arm_length, water_thickness, width_z)
				box_pos = base_pos + Vector3(half_x + arm_length * 0.5, 0.0, 0.0)
			2:
				box_size = Vector3(width_x, water_thickness, arm_length)
				box_pos = base_pos + Vector3(0.0, 0.0, half_z + arm_length * 0.5)
			_:
				box_size = Vector3(arm_length, water_thickness, width_z)
				box_pos = base_pos + Vector3(-(half_x + arm_length * 0.5), 0.0, 0.0)
		_queue_water_box(socket, box_size, box_pos)


## Distancia desde el CENTRO real de `aabb` (en X/Z, `center_x`/`center_z`
## ya calculados por el llamador) hasta su borde que mira hacia
## `dir_index` (misma convencion 0=Norte/1=Este/2=Sur/3=Oeste que
## _edge_distance) - a diferencia de _edge_distance (que mide desde el
## origen/pivote de rotacion del socket, usado para encadenar posiciones
## entre celdas), esta mide desde el centro real de la pieza, que es
## donde se para el canal de agua.
static func _center_edge_distance(aabb: AABB, dir_index: int, center_x: float, center_z: float) -> float:
	match dir_index:
		0:
			return center_z - aabb.position.z
		1:
			return (aabb.position.x + aabb.size.x) - center_x
		2:
			return (aabb.position.z + aabb.size.z) - center_z
		_:
			return center_x - aabb.position.x


## Encola una caja de agua (tamaño `size`, centrada en `local_pos` dentro
## del espacio del socket) convertida a un Transform3D RELATIVO a este
## generador (self) - no al socket directamente, porque todas las cajas de
## todas las piezas se van a fusionar en una sola malla que cuelga de
## `self`, no de cada socket individual (ver _build_merged_water_mesh).
func _queue_water_box(socket: Node3D, size: Vector3, local_pos: Vector3) -> void:
	var box_world_transform := socket.global_transform * Transform3D(Basis(), local_pos)
	var box_relative_transform := global_transform.affine_inverse() * box_world_transform
	_pending_water_boxes.append({"transform": box_relative_transform, "size": size})


## Fusiona TODAS las cajas de agua encoladas por _queue_water_box (de
## todas las piezas del dungeon) en una sola malla (SurfaceTool.append_from
## por caja) - un unico MeshInstance3D con un unico material, en vez de un
## MeshInstance3D por pieza. Esto es lo que elimina la "union"/costura
## visible que se veia antes en cada borde entre dos piezas vecinas (dos
## superficies semitransparentes separadas, apenas superpuestas o con un
## hueco minimo, se ven mas oscuras/con una linea en el borde por el doble
## blend de alpha o el corte entre normals) - ahora es literalmente un solo
## cuerpo de agua continuo.
func _build_merged_water_mesh() -> void:
	if _pending_water_boxes.is_empty():
		return

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box_mesh := BoxMesh.new()
	for entry in _pending_water_boxes:
		box_mesh.size = entry["size"]
		surface_tool.append_from(box_mesh, 0, entry["transform"])

	var merged_mesh := surface_tool.commit()
	_pending_water_boxes.clear()

	var material := StandardMaterial3D.new()
	# OPACO a proposito (NO transparency ALPHA ni ALPHA_HASH) - se probo
	# ALPHA_HASH para darle un poco de transparencia (Fix 28) pero el
	# dithering se ve raro/con ruido en vez de una transparencia limpia, asi
	# que se volvio al agua opaca original (Fix 27): con blending alfa
	# normal, cada vez que dos cajas de dos piezas vecinas se tocan o se
	# superponen aunque sea un poco, el motor las dibuja SIN un orden
	# garantizado dentro de la misma malla (no hay depth-sort por
	# triangulo), lo que se ve como una banda mas oscura/una linea justo en
	# el borde. Con material opaco normal (z-buffer de toda la vida) dos
	# cajas que se tocan o se superponen se ven exactamente igual que una
	# sola, sin ninguna costura.
	material.albedo_color = Color(water_color.r, water_color.g, water_color.b, 1.0)
	# Agua sucia estancada: sin brillo/reflejo especular. Con los valores
	# por defecto de StandardMaterial3D (specular ~0.5) cualquier luz
	# direccional (el sol) genera un destello especular en la superficie
	# SIEMPRE que le llegue luz difusa ambiental, incluso bajo techo -
	# poniendo metallic_specular en 0 y roughness al maximo se elimina ese
	# reflejo por completo, quedando un charco opaco/mate como corresponde.
	material.metallic = 0.0
	material.metallic_specular = 0.0
	material.roughness = 1.0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = merged_mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)


## Dispersa 0..props_per_cell_max props sueltos (basura/escombros, ver
## PROP_NAMES) dentro de la caja de esta celda, con RNG determinista por
## celda (misma idea que el scattering de vegetacion del overworld en
## world/chunk_manager.gd) - asi la misma semilla siempre genera la misma
## basura en el mismo lugar. Se dejan con un margen del 20% desde los
## bordes de la caja para que tiendan a quedar contra las paredes/rincones
## en vez de tapar el centro del pasillo (no hay raycast/colision real
## contra el piso todavia, la pieza ya se sabe plana en Y=0 local).
func _scatter_cell_props(socket: Node3D, oriented_aabb: AABB, cell: Vector2i) -> void:
	if PROP_NAMES.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell) ^ rng_seed ^ 0xC0FFEE

	var count := rng.randi_range(props_per_cell_min, props_per_cell_max)
	if count <= 0:
		return

	var margin_x := oriented_aabb.size.x * 0.2
	var margin_z := oriented_aabb.size.z * 0.2

	for i in range(count):
		var prop_name: String = PROP_NAMES[rng.randi_range(0, PROP_NAMES.size() - 1)]
		var template: Node3D = _piece_source.find_child(prop_name, true, false) as Node3D
		if template == null:
			continue

		var instance: Node3D = template.duplicate()
		var local_x := rng.randf_range(oriented_aabb.position.x + margin_x, oriented_aabb.position.x + oriented_aabb.size.x - margin_x)
		var local_z := rng.randf_range(oriented_aabb.position.z + margin_z, oriented_aabb.position.z + oriented_aabb.size.z - margin_z)

		socket.add_child(instance)
		instance.position = Vector3(local_x, 0.0, local_z)
		instance.rotate_y(rng.randf_range(0.0, TAU))
		var scale_factor := rng.randf_range(0.8, 1.3)
		instance.scale *= scale_factor


## Crea el cubo semitransparente que muestra box_min/box_max de una pieza,
## como hijo del socket (asi rota junto con la pieza). Puramente visual /
## de depuracion - no afecta la posicion ni la rotacion de nada.
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


## Combina el AABB (bounding box) de todas las mallas (VisualInstance3D)
## debajo de `root`, medido en el espacio local de `root` - es decir,
## ignorando el transform propio de `root` (que estamos por sobreescribir),
## pero respetando los transforms relativos de sus hijos/nietos/etc.
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


## Carteles simples (Label3D) para ubicar rapido la entrada y la salida
## al probar el nivel generado.
func _mark_entrance_and_exit() -> void:
	_add_marker_label(entrance_cell, "ENTRADA", Color.LIME_GREEN)
	_add_marker_label(exit_cell, "SALIDA", Color.ORANGE_RED)


func _add_marker_label(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 72
	label.outline_size = 14
	label.modulate = color
	add_child(label)
	var world_xz: Vector3 = _cell_world_positions.get(cell, Vector3.ZERO)
	label.global_position = Vector3(world_xz.x, piece_height + 4.0, world_xz.z)
