extends Node3D
class_name DrenajePiecesTest
## Escena de prueba (2026-08-04): instancia Sewers.fbx (pack "drenaje") y
## acomoda cada pieza ESTRUCTURAL (nodos cuyo nombre empieza con "Serwers" -
## el resto son props decorativos sueltos: Trash, debris, Garbage_bag,
## Box_T, Bricks, Pipe, door_metal, etc., no forman parte del tunel en si)
## en una sola fila de izquierda a derecha, cada una con un Label3D flotando
## encima con su INDICE y su nombre real de nodo.
##
## Objetivo: correr esta escena (F6), volar con la camara libre a lo largo
## de la fila, y poder decir "la pieza 4 (Serwers01) es una esquina, la 12
## es un tramo recto, etc." sin ambiguedad - el label muestra el nombre
## exacto tal cual esta en el .fbx/.dae original, asi que lo que se
## identifique se puede mapear 1:1 de vuelta al archivo fuente.
##
## El pack trae 66 nodos con el prefijo "Serwers" (Serwers/Serwers01/
## Serwers02/SerwersP/SerwersP1, cada uno con muchas variantes numeradas
## _001, _002, etc. - probablemente el mismo molde con distinto nivel de
## daño/mugre, pero eso hay que confirmarlo viendolo).

const SEWERS_SCENE := preload("res://assets/drenaje/Models/Sewers.fbx")
const FREE_FLY_CAMERA_SCRIPT := preload("res://tests/free_fly_camera.gd")
const PIECE_PREFIX := "Serwers" # estructura del tunel; el resto son props sueltos
const SPACING := 12.0 # metros entre el origen de una pieza y la siguiente


func _ready() -> void:
	var source := SEWERS_SCENE.instantiate()
	add_child(source)

	var pieces := _collect_pieces(source)
	pieces.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.name < b.name)

	print("[drenaje_pieces_test] %d piezas encontradas (prefijo '%s')" % [pieces.size(), PIECE_PREFIX])
	for i in pieces.size():
		_place_piece(pieces[i], i)

	_add_lighting()
	_add_camera()


## Recorre el arbol del modelo importado buscando nodos Node3D cuyo nombre
## empiece con PIECE_PREFIX. No sigue buscando DENTRO de un nodo ya
## encontrado (para no separar tambien su malla interna como si fuera otra
## pieza distinta) - cada pieza se extrae completa, con su MeshInstance3D y
## cualquier hijo que traiga.
func _collect_pieces(node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in node.get_children():
		if child is Node3D and (child as Node3D).name.begins_with(PIECE_PREFIX):
			result.append(child)
		else:
			result.append_array(_collect_pieces(child))
	return result


## Saca la pieza de donde estaba (el diorama original) y la reubica en la
## fila, en la posicion `index * SPACING` sobre el eje X. Conserva la
## orientacion/escala originales (solo se cambia la posicion) para que se
## vea "parada" tal como la diseño el autor del pack, no con una rotacion
## arbitraria.
func _place_piece(piece: Node3D, index: int) -> void:
	var original_basis := piece.global_transform.basis
	piece.reparent(self)
	var row_position := Vector3(index * SPACING, 0.0, 0.0)
	piece.global_transform = Transform3D(original_basis, row_position)

	# El label se agrega como hijo de la escena raiz (no de la pieza) para
	# que su posicion no herede la rotacion/escala original de la pieza -
	# si no, con piezas que vienen rotadas del diorama, el offset "hacia
	# arriba" termina apuntando de lado y todos los carteles se ven
	# amontonados en vez de uno arriba de cada modelo.
	var label := Label3D.new()
	label.text = "%d: %s" % [index, piece.name]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 12
	add_child(label)
	label.global_position = row_position + Vector3.UP * 3.0


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


## Camara libre (WASD + mouse, ver free_fly_camera.gd) arrancando frente a
## la primera pieza de la fila, un poco elevada y hacia atras para verla
## completa apenas arranca la escena.
func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.set_script(FREE_FLY_CAMERA_SCRIPT)
	camera.position = Vector3(-3.0, 2.5, 6.0)
	camera.rotation_degrees = Vector3(-15.0, -25.0, 0.0)
	add_child(camera)
