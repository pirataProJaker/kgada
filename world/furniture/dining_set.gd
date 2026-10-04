class_name DiningSet
extends Node3D

## Conjunto de Comedor Completo (Mesa + 4 o 6 Sillas a juego)
## Organiza proceduralmente las sillas alrededor de la mesa con holgura ergonómica.
## Optimizado con GPU MultiMeshInstancing (solo 2 Draw Calls: 1 para la mesa, 1 para las sillas).

const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")

enum WoodFinish {
	ROBLE_CLARO = 0,  ## Roble claro refinado
	NOGAL_OSCURO = 1, ## Nogal oscuro elegante
	CAOBA_ROJIZA = 2, ## Caoba / Cedro rojizo cálido
	PINO_NATURAL = 3  ## Pino natural / Miel dorado
}

@export var finish: WoodFinish = WoodFinish.ROBLE_CLARO:
	set(val):
		finish = val
		if is_inside_tree():
			_build_set()

@export var chairs_count: int = 4 ## 4 o 6 sillas
@export var chair_tucked_distance: float = 0.48 ## Distancia de las sillas al centro de la mesa
@export var use_gpu_multimesh: bool = true ## Activa GPU Instancing para máxima velocidad

var _multimesh_system: Node3D = null


func _ready() -> void:
	_build_set()


func _build_set() -> void:
	for child in get_children():
		child.queue_free()

	if use_gpu_multimesh:
		var sys := FurnitureMultiMeshSystemScript.new()
		sys.name = "DiningMultiMesh"
		sys.add_dining_set(Transform3D.IDENTITY, finish, chairs_count, chair_tucked_distance)
		sys.build(true)
		add_child(sys)
		_multimesh_system = sys
	else:
		_build_legacy_individual_nodes()


func _build_legacy_individual_nodes() -> void:
	var table_script = preload("res://world/furniture/wooden_table.gd")
	var chair_script = preload("res://world/furniture/wooden_chair.gd")

	var table = table_script.new()
	table.name = "DiningTable"
	table.finish = finish
	add_child(table)

	var x_offsets := [-0.35, 0.35]
	var z_dist := chair_tucked_distance

	# Lado Frontal (+Z)
	for xo in x_offsets:
		var chair = chair_script.new()
		chair.finish = finish
		chair.position = Vector3(xo, 0.0, z_dist)
		chair.rotation.y = PI
		add_child(chair)

	# Lado Trasero (-Z)
	for xo in x_offsets:
		var chair = chair_script.new()
		chair.finish = finish
		chair.position = Vector3(xo, 0.0, -z_dist)
		chair.rotation.y = 0.0
		add_child(chair)

	if chairs_count >= 6:
		var t_len: float = float(table.get("table_length")) if table.get("table_length") != null else 1.40
		var head_dist: float = t_len * 0.5 + 0.22

		var chair_east = chair_script.new()
		chair_east.finish = finish
		chair_east.position = Vector3(head_dist, 0.0, 0.0)
		chair_east.rotation.y = -PI * 0.5
		add_child(chair_east)

		var chair_west = chair_script.new()
		chair_west.finish = finish
		chair_west.position = Vector3(-head_dist, 0.0, 0.0)
		chair_west.rotation.y = PI * 0.5
		add_child(chair_west)
