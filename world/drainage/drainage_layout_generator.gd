extends RefCounted
class_name DrainageLayoutGenerator
## Genera el "mapa logico" de un nivel de drenaje/alcantarillado: un grid 2D
## (X,Z) donde cada celda visitada guarda un bitmask de que direcciones
## tienen un tunel conectado. No instancia ninguna pieza 3D - eso lo hace
## DrainageDungeonGenerator, usando este layout + DrainagePieceCatalog.
##
## Algoritmo: "random walk" con ramificacion ocasional (varios caminantes),
## deterministico si se usa siempre la misma seed - sigue el mismo patron
## de generacion por seed que world/chunk_manager.gd (sin transmitir
## geometria por red, solo la seed).

## N, E, S, W - bit 0..3 respectivamente.
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const OPPOSITE_DIRECTION_INDEX := [2, 3, 0, 1]


## Devuelve Dictionary<Vector2i, int> - posicion de celda -> bitmask de
## aberturas (bit i = 1 si hay tunel hacia DIRECTIONS[i]).
## `branch_chance` es la probabilidad de que, al avanzar un caminante, se
## quede tambien una copia en la celda vieja (crea una ramificacion extra).
## `loop_chance` es la probabilidad de que, al toparse con una celda
## VECINA que ya existe (normalmente se ignora y se prueba otra
## direccion), se conecte igual - esto crea un ciclo/interconexion entre
## dos ramas que de otra forma quedarian aisladas entre si, dandole al
## nivel una sensacion de laberinto real en vez de un arbol puro donde
## cada rama nunca se vuelve a topar con otra. OJO: como la posicion
## final de cada pieza se mide/encadena por el arbol original (ver
## DrainageDungeonGenerator._compute_cell_positions), estas conexiones
## "loop" no reciben su propio calculo de posicion (los dos extremos ya
## estan posicionados por sus propias ramas) - pueden quedar con una
## pequeña imprecision visual si las piezas de cada rama midieron
## distinto largo acumulado; mantener `loop_chance` bajo (algo como
## 0.08-0.15) para que sea ocasional y no dependa de que siempre calce
## perfecto.
static func generate(rng_seed: int, target_cell_count: int, branch_chance: float = 0.15, loop_chance: float = 0.1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# La entrada (Vector2i.ZERO) SIEMPRE arranca conectada hacia el Norte -
	# direccion FIJA, no aleatoria (antes el primer paso del caminante
	# elegia una direccion al azar, asi que a veces el random walk terminaba
	# ocupando la celda de "atras" de la entrada, y el pasillo con pared que
	# tapa el otro lado del pozo vertical -ver Fix 20 en
	# /memories/repo/drenaje-piece-catalog.md- no se podia agregar). Al fijar
	# la direccion, la celda de atras (Sur) se puede reservar/prohibir desde
	# el arranque y listo, siempre queda libre para ese tapon sin importar
	# la seed.
	var entrance_dir_index := 0
	var entrance_forward: Vector2i = DIRECTIONS[entrance_dir_index]
	var behind_entrance: Vector2i = DIRECTIONS[OPPOSITE_DIRECTION_INDEX[entrance_dir_index]]

	var visited: Dictionary = {} # Vector2i -> int bitmask
	visited[Vector2i.ZERO] = 1 << entrance_dir_index
	visited[entrance_forward] = 1 << OPPOSITE_DIRECTION_INDEX[entrance_dir_index]

	# Celdas que el random walk nunca puede visitar ni conectar - por ahora
	# solo la de atras de la entrada, pero queda como Dictionary por si a
	# futuro se necesita reservar mas de una.
	var forbidden: Dictionary = {behind_entrance: true}

	var walkers: Array[Vector2i] = [entrance_forward]

	while visited.size() < target_cell_count and not walkers.is_empty():
		var walker_index := rng.randi_range(0, walkers.size() - 1)
		var pos: Vector2i = walkers[walker_index]
		var dir_order := _shuffled_direction_indices(rng)

		var advanced := false
		for dir_index in dir_order:
			var next_pos: Vector2i = pos + DIRECTIONS[dir_index]
			if forbidden.has(next_pos):
				continue

			if visited.has(next_pos):
				# Ya existe esa celda (es de otra rama, o ya se paso por ahi) -
				# normalmente se ignora y se prueba otra direccion, pero a
				# veces se conecta igual para que las ramas se interconecten
				# entre si (ver doc de loop_chance arriba).
				if next_pos != pos and rng.randf() < loop_chance and (visited[pos] & (1 << dir_index)) == 0:
					visited[pos] = visited[pos] | (1 << dir_index)
					visited[next_pos] = visited[next_pos] | (1 << OPPOSITE_DIRECTION_INDEX[dir_index])
				continue

			visited[pos] = visited[pos] | (1 << dir_index)
			visited[next_pos] = 1 << OPPOSITE_DIRECTION_INDEX[dir_index]
			walkers[walker_index] = next_pos

			if rng.randf() < branch_chance:
				walkers.append(pos) # deja un "hijo" ramificando desde la celda vieja

			advanced = true
			break

		if not advanced:
			walkers.remove_at(walker_index) # sin vecinos libres cerca, este caminante termino

	return visited


## Recorre el layout (BFS por numero de saltos) y devuelve la celda mas
## lejana desde `start` - se usa como salida del nivel, mientras `start`
## (siempre Vector2i.ZERO en generate()) es la entrada.
static func find_farthest_cell(layout: Dictionary, start: Vector2i) -> Vector2i:
	var distance: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var farthest := start
	var farthest_distance := 0
	var head := 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var bitmask: int = layout[current]

		for dir_index in range(DIRECTIONS.size()):
			if bitmask & (1 << dir_index) == 0:
				continue
			var neighbor: Vector2i = current + DIRECTIONS[dir_index]
			if distance.has(neighbor):
				continue
			distance[neighbor] = distance[current] + 1
			if distance[neighbor] > farthest_distance:
				farthest_distance = distance[neighbor]
				farthest = neighbor
			queue.append(neighbor)

	return farthest


static func _shuffled_direction_indices(rng: RandomNumberGenerator) -> Array[int]:
	var indices: Array[int] = [0, 1, 2, 3]
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	return indices
