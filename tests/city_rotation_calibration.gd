extends Node3D
## Escena de calibracion para las piezas de calle (pack URBAN, Road type 1)
## - copia del criterio de tests/drainage_rotation_calibration.gd, adaptada
## a CityPieceCatalog/CityPieceConfig.
##
## Instancia, usando el MISMO CityPieceCatalog y los MISMOS *_config.tres
## reales que usa CityBlockGenerator, TODAS las variantes de rotacion
## posibles de straight/corner/t_junction/cross, una al lado de la otra,
## cada una con:
## - un cartel (Label3D) arriba con el bitmask pedido y los grados de
##   rotacion aplicados
## - 4 esferas de color alrededor (Norte/Este/Sur/Oeste): VERDE = "aca
##   deberia haber una abertura de calle", ROJO = "aca deberia haber
##   banqueta/pared". Estas esferas se calculan directo del bitmask PEDIDO
##   (la "respuesta correcta"), no de como termino rotando la pieza real.
##
## Sirve para diagnosticar el bug de "en una posicion calza bien pero
## rotado a cierto angulo no" - eso pasa cuando canonical_openings o
## rotation_direction de un *_config.tres no coincide de verdad con el
## modelo (dato mal puesto), y solo se nota en ciertos pasos de rotacion.
## Correr esta escena (F6), volar con la camara libre y comparar, pieza
## por pieza, si la calle/banqueta real coincide con las esferas
## verdes/rojas en las 4 rotaciones de cada fila.

const FREE_FLY_CAMERA_SCRIPT := preload("res://tests/free_fly_camera.gd")

@export var straight_config: CityPieceConfig = preload("res://world/city/piece_configs/straight.tres")
@export var corner_config: CityPieceConfig = preload("res://world/city/piece_configs/corner.tres")
@export var t_junction_config: CityPieceConfig = preload("res://world/city/piece_configs/t_junction.tres")
@export var cross_config: CityPieceConfig = preload("res://world/city/piece_configs/cross.tres")

const SPACING_MARGIN := 6.0
const DIR_NAMES := ["N", "E", "S", "O"]
# Mismo orden/convencion que CityBlockGenerator (0=Norte=-Z, 1=Este=+X,
# 2=Sur=+Z, 3=Oeste=-X).
const DIR_OFFSETS: Array[Vector3] = [Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0)]

var _catalog: CityPieceCatalog
var _marker_radius: float = 3.0


func _ready() -> void:
	_catalog = CityPieceCatalog.new({
		"straight": straight_config,
		"corner": corner_config,
		"t_junction": t_junction_config,
		"cross": cross_config,
	})

	# Cada fila prueba TODAS las variantes de rotacion posibles de una
	# forma. Los masks se calculan a partir del canonical_openings ACTUAL
	# de cada *_config.tres (no estan hardcodeados) - columna 0 siempre es
	# la pieza SIN rotar (tal cual el .tres), util para distinguir un bug
	# de datos (canonical_openings mal marcado, se ve mal incluso en
	# columna 0) de un bug de signo/rotation_direction (solo se ve mal en
	# algunas columnas).
	var rows := [
		{"nombre": "straight", "config": straight_config, "steps_list": [0, 1]},
		{"nombre": "corner", "config": corner_config, "steps_list": [0, 1, 2, 3]},
		{"nombre": "t_junction", "config": t_junction_config, "steps_list": [0, 1, 2, 3]},
		{"nombre": "cross", "config": cross_config, "steps_list": [0]},
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

	_add_lighting()
	_add_camera(max_cols, rows.size(), spacing)


## Mide el footprint real (X/Z) de la pieza representativa de cada fila
## para separar filas/columnas sin que ninguna pieza se pise con la de al
## lado, sin importar el tamaño real de cada modelo.
func _measure_spacing(rows: Array) -> float:
	var max_dimension := 0.0
	for row in rows:
		var config: CityPieceConfig = row["config"]
		if config == null or config.model_scene == null:
			continue
		var instance: Node3D = config.model_scene.instantiate()
		var local_aabb := _compute_local_aabb(instance)
		instance.free()
		max_dimension = max(max_dimension, max(local_aabb.size.x, local_aabb.size.z))
	return max_dimension + SPACING_MARGIN


static func _rotation_masks(config: CityPieceConfig, steps_list: Array) -> Array:
	var masks: Array = []
	for steps in steps_list:
		masks.append(CityPieceCatalog._rotate_mask(config.canonical_openings, steps))
	return masks


func _place_calibration_piece(bitmask: int, steps: int, row_name: String, world_pos: Vector3) -> void:
	var resolved := _catalog.resolve(bitmask)
	var config: CityPieceConfig = resolved.get("config")
	if config == null or config.model_scene == null:
		push_warning("Calibracion: falta model_scene para la fila '%s' (mask %d)" % [row_name, bitmask])
		return

	var instance: Node3D = config.model_scene.instantiate()
	var local_aabb := _compute_local_aabb(instance)

	var socket := Node3D.new()
	add_child(socket)
	socket.position = world_pos
	socket.rotation_degrees.y = resolved["rotation_degrees"]

	# Mismo centrado en X/Z/Y que CityBlockGenerator._place_piece() - no se
	# asume que el pivote del modelo ya viene centrado en su footprint.
	var center_offset := Vector3(
		-(local_aabb.position.x + local_aabb.size.x * 0.5),
		-local_aabb.position.y,
		-(local_aabb.position.z + local_aabb.size.z * 0.5)
	)
	instance.transform = Transform3D(Basis(), center_offset)
	socket.add_child(instance)

	_add_label(world_pos, "%s\nmask=%d (%s) steps=%d\nrot=%.0f" % [row_name, bitmask, _mask_to_string(bitmask), steps, resolved["rotation_degrees"]])
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


## Esferas verdes (abertura de calle esperada) / rojas (banqueta/pared
## esperada) en las 4 direcciones cardinales alrededor de `world_pos`,
## calculadas directo del bitmask PEDIDO - la "respuesta correcta" fija con
## la que hay que comparar la pieza real.
func _add_direction_markers(world_pos: Vector3, bitmask: int) -> void:
	for dir_index in range(4):
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


## Copia exacta de CityBlockGenerator._compute_local_aabb().
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


## Encuadra TODA la grilla (todas las filas/columnas) desde arriba.
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
