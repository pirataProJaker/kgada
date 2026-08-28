extends Node3D
## Escena de calibracion (Fix 13, 2026-08-04).
##
## Adivinar el signo de rotation_direction a ciegas corriendo el dungeon
## random ENTERO ya fallo 2 veces seguidas (Fix 11, Fix 12) - el problema es
## que ahi es dificil aislar si lo que se ve mal es la pieza que se esta
## mirando o una vecina (ej. una T mal rotada en medio de un pasillo recto
## se puede confundir con "el recto esta cortado").
##
## Esta escena instancia, usando el MISMO DrainagePieceCatalog y los MISMOS
## *_config.tres reales que usa DrainageDungeonGenerator, TODAS las
## variantes de rotacion posibles de corner/t_junction/straight, una al
## lado de la otra, cada una con:
## - un cartel (Label3D) arriba con el nombre del nodo y el bitmask pedido
## - 4 esferas de color alrededor (Norte/Este/Sur/Oeste): VERDE = "aca
##   deberia haber una abertura", ROJO = "aca deberia haber pared". Estas
##   esferas se calculan directo del bitmask pedido (no dependen de si el
##   codigo rota bien o mal), o sea son la "respuesta correcta" fija con la
##   que hay que comparar la pieza real.
##
## Correr esta escena (F6), volar con la camara libre y comparar, pieza por
## pieza, si la abertura/pared real coincide con las esferas verdes/rojas.

const FREE_FLY_CAMERA_SCRIPT := preload("res://tests/free_fly_camera.gd")

@export var dead_end_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/dead_end.tres")
@export var straight_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/straight.tres")
@export var corner_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/corner.tres")
@export var t_junction_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/t_junction.tres")
@export var cross_config: DrainagePieceConfig = preload("res://world/drainage/piece_configs/cross.tres")

const SPACING_MARGIN := 6.0
const DIR_NAMES := ["N", "E", "S", "O"]
# Mismo orden/convencion que DrainageLayoutGenerator.DIRECTIONS (0=Norte=-Z,
# 1=Este=+X, 2=Sur=+Z, 3=Oeste=-X). Tipado explicito (Array[Vector3]) para
# que DIR_OFFSETS[i] infiera como Vector3 y no como Variant (si no, `var
# marker_pos := world_pos + ... + DIR_OFFSETS[i] * _marker_radius` no puede
# inferir el tipo y Godot lo marca como error).
const DIR_OFFSETS: Array[Vector3] = [Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0)]

var _piece_source: Node3D
var _catalog: DrainagePieceCatalog
var _marker_radius: float = 3.0


func _ready() -> void:
	_piece_source = load(DrainagePieceCatalog.PIECE_SOURCE_PATH).instantiate()
	add_child(_piece_source)
	_piece_source.visible = false

	_catalog = DrainagePieceCatalog.new({
		"dead_end": dead_end_config,
		"straight": straight_config,
		"corner": corner_config,
		"t_junction": t_junction_config,
		"cross": cross_config,
	})

	# Cada fila prueba TODAS las variantes de rotacion posibles de una
	# forma. Los masks se calculan a partir del canonical_openings ACTUAL
	# de cada *_config.tres (no estan hardcodeados) y `steps_list` garantiza
	# que la columna N siempre sea la rotacion de N pasos de 90 grados -
	# asi columna 0 siempre es la pieza SIN rotar (tal cual el .tres), util
	# para distinguir un bug de datos (canonical_openings mal marcado, se ve
	# mal incluso en columna 0) de un bug de signo (solo columnas impares).
	# "Serwers01" (SIN sufijo) NO es un candidato a "recto con pared" - es
	# el nodo que YA usa dead_end_config (dead_end.tres: node_name=
	# "Serwers01", canonical_openings=1, o sea 1 SOLA abertura, no 2). Por
	# eso el generador lo pone al principio/final del dungeon: los
	# extremos del arbol del layout (DrainageLayoutGenerator) son celdas
	# con bitmask de 1 solo bit, que resuelve a "dead_end" en
	# DrainagePieceCatalog.resolve(). Antes esta fila probaba mal ese nodo
	# con canonical_openings=5 (inventado, 2 aberturas) - por eso no
	# coincidia con nada real. Se prueba con dead_end_config de verdad y
	# las 4 rotaciones (con 1 sola abertura, las 4 orientaciones son todas
	# distintas entre si).
	var rows := [
		{"nombre": "corner", "config": corner_config, "steps_list": [0, 1, 2, 3]},
		{"nombre": "t_junction", "config": t_junction_config, "steps_list": [0, 1, 2, 3]},
		{"nombre": "straight (recto con pared) [Serwers01_007]", "config": straight_config, "steps_list": [0, 1]},
		{"nombre": "dead_end (Serwers01, inicio/final del dungeon)", "config": dead_end_config, "steps_list": [0, 1, 2, 3]},
	]

	var spacing := _measure_spacing(rows)
	_marker_radius = spacing * 0.22

	var max_cols := 0
	for row_index in rows.size():
		var row: Dictionary = rows[row_index]
		var steps_list: Array = row["steps_list"]
		var masks: Array = _rotation_masks(row["config"], steps_list)
		max_cols = max(max_cols, masks.size())
		for col_index in masks.size():
			var mask: int = masks[col_index]
			var steps: int = steps_list[col_index]
			var world_pos := Vector3(col_index * spacing, 0.0, row_index * spacing)
			_place_calibration_piece(mask, steps, row["nombre"], world_pos)

	_piece_source.queue_free()
	_piece_source = null

	_add_lighting()
	_add_camera(max_cols, rows.size(), spacing)


## Mide el footprint real (X/Z, ya orientado) de la pieza representativa de
## cada fila (steps=0, tal cual el .tres) para separar filas/columnas sin
## que ninguna pieza se pise con la de al lado, sin importar que tan grande
## sea cada modelo real.
func _measure_spacing(rows: Array) -> float:
	var max_dimension := 0.0
	for row in rows:
		var config: DrainagePieceConfig = row["config"]
		var template: Node3D = _piece_source.find_child(config.node_name, true, false)
		if template == null:
			continue
		var local_aabb := _compute_local_aabb(template)
		var oriented_aabb: AABB = Transform3D(template.global_transform.basis, Vector3.ZERO) * local_aabb
		max_dimension = max(max_dimension, max(oriented_aabb.size.x, oriented_aabb.size.z))
	return max_dimension + SPACING_MARGIN


static func _rotation_masks(config: DrainagePieceConfig, steps_list: Array) -> Array:
	var masks: Array = []
	for steps in steps_list:
		masks.append(DrainagePieceCatalog._rotate_mask(config.canonical_openings, steps))
	return masks


func _place_calibration_piece(bitmask: int, steps: int, row_name: String, world_pos: Vector3) -> void:
	var resolved := _catalog.resolve(bitmask)
	var node_name: String = resolved.get("node", "")
	var template: Node3D = _piece_source.find_child(node_name, true, false)
	if template == null:
		push_warning("Calibracion: no se encontro la pieza '%s' para mask %d" % [node_name, bitmask])
		return

	var original_basis := template.global_transform.basis
	var local_aabb := _compute_local_aabb(template)
	var oriented_aabb: AABB = Transform3D(original_basis, Vector3.ZERO) * local_aabb

	var rotation_degrees: float = resolved["rotation_degrees"]

	var socket := Node3D.new()
	add_child(socket)
	socket.position = world_pos
	socket.rotation_degrees.y = rotation_degrees

	var instance: Node3D = template.duplicate()
	socket.add_child(instance)
	instance.transform = Transform3D(original_basis, Vector3(0.0, -oriented_aabb.position.y, 0.0))

	_add_label(world_pos, "%s: %s\nmask=%d (%s) steps=%d\nrot=%.0f" % [row_name, node_name, bitmask, _mask_to_string(bitmask), steps, rotation_degrees])
	_add_direction_markers(world_pos, bitmask)


func _add_label(world_pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 10
	add_child(label)
	label.global_position = world_pos + Vector3.UP * 4.5


## Esferas verdes (abertura esperada) / rojas (pared esperada) en las 4
## direcciones cardinales alrededor de `world_pos`, calculadas directo del
## bitmask PEDIDO (la "respuesta correcta"), no de como termino rotando la
## pieza real - sirven de referencia fija para comparar a ojo.
func _add_direction_markers(world_pos: Vector3, bitmask: int) -> void:
	for dir_index in range(4):d
		var open := (bitmask & (1 << dir_index)) != 0
		var marker_color := Color(0.2, 1.0, 0.3) if open else Color(1.0, 0.15, 0.15)
		var marker_pos := world_pos + Vector3.UP * 1.2 + DIR_OFFSETS[dir_index] * _marker_radius

		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		marker.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = marker_color
		marker.material_override = material
		add_child(marker)
		marker.position = marker_pos

		# Letra N/E/S/O al lado de la esfera - antes habia que adivinar cual
		# esfera era cual direccion segun el angulo de camara.
		var dir_label := Label3D.new()
		dir_label.text = DIR_NAMES[dir_index]
		dir_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dir_label.no_depth_test = true
		dir_label.font_size = 32
		dir_label.outline_size = 8
		dir_label.modulate = marker_color
		add_child(dir_label)
		dir_label.global_position = marker_pos + Vector3.UP * 0.7


static func _mask_to_string(bitmask: int) -> String:
	var open_names: Array[String] = []
	for i in range(4):
		if bitmask & (1 << i):
			open_names.append(DIR_NAMES[i])
	return ",".join(open_names)


## Copia exacta de DrainageDungeonGenerator._compute_local_aabb() - combina
## el AABB de todas las mallas debajo de `root` en el espacio local de
## `root`.
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


func _add_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.6, 0.65)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.ambient_light_energy = 0.9
	world_env.environment = environment
	add_child(world_env)


## Encuadra TODA la grilla (todas las filas/columnas) desde arriba, sin
## importar cuantas filas/columnas terminen habiendo ni que tan separadas
## esten - antes la camara tenia posicion fija y la fila de abajo (recto)
## quedaba literalmente detras de la camara, pareciendo que faltaba en la
## escena.
func _add_camera(max_cols: int, num_rows: int, spacing: float) -> void:
	var grid_width: float = max(max_cols - 1, 0) * spacing
	var grid_depth: float = max(num_rows - 1, 0) * spacing
	var span: float = max(max(grid_width, grid_depth), spacing)
	var center := Vector3(grid_width * 0.5, 0.0, grid_depth * 0.5)

	var camera := Camera3D.new()
	camera.set_script(FREE_FLY_CAMERA_SCRIPT)
	camera.position = center + Vector3(0.0, span * 0.9 + 10.0, span * 0.55 + 8.0)
	camera.rotation_degrees = Vector3(-65.0, 0.0, 0.0)
	add_child(camera)
