class_name SinkUnitWhite
extends Node3D

## Mueble Fregadero / Lavaplatos Blanco con Grifería (Sink Unit White)
## - Malla primaria exacta (304 tris) calibrada al atlas oficial: gabinete blanco envejecido,
##   encimera, poceta de acero inoxidable y grifo monomando
## - 2 puertas abatibles independientes con bisagras en los bordes
## - Almacenamiento desacoplado mediante FurnitureStorageContainer (Modo SLOTS_3D)
## - Lazy Evaluation para GPU: Cuando las puertas están cerradas, los objetos interiores
##   NO se renderizan (0 draw calls, 0 vértices).
## - Malla unificada get_shared_mesh() para 1 solo Draw Call en GPU Instancing.

const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureStorageContainerScript = preload("res://world/furniture/furniture_storage_container.gd")
const FurnitureInteractProxyScript = preload("res://world/furniture/furniture_interact_proxy.gd")

@export_group("Dimensiones")
@export var width: float = 1.01           ## Ancho total (1.01m)
@export var depth: float = 0.62           ## Fondo total (62cm)
@export var counter_height: float = 0.88  ## Altura del mesón (88cm)

@export_group("Puertas")
@export_range(0.0, 1.0) var doors_open_ratio: float = 0.0:
	set(val):
		doors_open_ratio = clampf(val, 0.0, 1.0)
		_update_doors()

const MAX_SWING_ANGLE: float = deg_to_rad(100.0)

var storage: FurnitureStorageContainerScript = null
var _frame_instance: MeshInstance3D = null
var _door_left_pivot: Node3D = null
var _door_right_pivot: Node3D = null
var _door_left_mesh: MeshInstance3D = null
var _door_right_mesh: MeshInstance3D = null
var _contents_pivot: Node3D = null
var _collision_body: StaticBody3D = null
var _interact_proxy: FurnitureInteractProxy = null


## Retorna la malla compartida completa (cuerpo + grifo + 2 puertas cerradas) para GPU Instancing
static func get_shared_mesh() -> ArrayMesh:
	return FurniturePropsBuilderScript.get_sink_complete_mesh()


## Retorna las cajas de colisión para física del fregadero
static func get_collision_boxes(w: float = 1.01, d: float = 0.62, h: float = 0.88) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		}
	]


func _init() -> void:
	storage = FurnitureStorageContainerScript.new(FurnitureStorageContainerScript.StorageMode.SLOTS_3D, 4)
	storage.storage_changed.connect(_on_storage_changed)


func _ready() -> void:
	_build_sink_unit()


func _build_sink_unit() -> void:
	for child in get_children():
		child.queue_free()

	var mat := FurniturePropsBuilderScript.get_props_material(0.45, 0.10)

	# 1. Armazón principal con mesón, lavaplatos y grifo
	_frame_instance = MeshInstance3D.new()
	_frame_instance.name = "SinkFrame"
	_frame_instance.mesh = FurniturePropsBuilderScript.get_sink_cabinet_mesh()
	_frame_instance.material_override = mat
	add_child(_frame_instance)

	# 2. Puerta Izquierda (Bisagra en borde izquierdo)
	_door_left_pivot = Node3D.new()
	_door_left_pivot.name = "DoorLeftPivot"
	_door_left_pivot.position = Vector3(-0.490, 0.0, 0.300)
	add_child(_door_left_pivot)

	_door_left_mesh = MeshInstance3D.new()
	_door_left_mesh.name = "DoorLeftMesh"
	_door_left_mesh.mesh = FurniturePropsBuilderScript.get_sink_door_left_mesh()
	_door_left_mesh.material_override = mat
	_door_left_mesh.position = Vector3.ZERO
	_door_left_pivot.add_child(_door_left_mesh)

	# 3. Puerta Derecha (Bisagra en borde derecho)
	_door_right_pivot = Node3D.new()
	_door_right_pivot.name = "DoorRightPivot"
	_door_right_pivot.position = Vector3(0.490, 0.0, 0.300)
	add_child(_door_right_pivot)

	_door_right_mesh = MeshInstance3D.new()
	_door_right_mesh.name = "DoorRightMesh"
	_door_right_mesh.mesh = FurniturePropsBuilderScript.get_sink_door_right_mesh()
	_door_right_mesh.material_override = mat
	_door_right_mesh.position = Vector3.ZERO
	_door_right_pivot.add_child(_door_right_mesh)

	# 4. Contenedor de visuales de ítems interiores (Lazy Evaluation)
	_contents_pivot = Node3D.new()
	_contents_pivot.name = "ContentsPivot"
	_contents_pivot.visible = false # Cerrado = 0 draw calls
	add_child(_contents_pivot)

	# 5. Colisión física sólida
	_collision_body = StaticBody3D.new()
	_collision_body.name = "SinkCollision"
	var c_shape := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(width, counter_height, depth)
	c_shape.shape = b_shape
	c_shape.position = Vector3(0.0, counter_height * 0.5, 0.0)
	_collision_body.add_child(c_shape)
	add_child(_collision_body)

	# 6. Proxy de interacción para tecla [E]
	_interact_proxy = FurnitureInteractProxyScript.new()
	_interact_proxy.name = "InteractProxy"
	_interact_proxy.target_node = self
	var p_shape := CollisionShape3D.new()
	var p_box := BoxShape3D.new()
	p_box.size = Vector3(width * 0.95, counter_height * 0.8, 0.10)
	p_shape.shape = p_box
	p_shape.position = Vector3(0.0, counter_height * 0.5, depth * 0.5 + 0.05)
	_interact_proxy.add_child(p_shape)
	add_child(_interact_proxy)

	_update_doors()


## Alterna la apertura de las puertas
func toggle_doors(animated: bool = true) -> void:
	var target := 1.0 if doors_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "doors_open_ratio", target, 0.40)
	else:
		doors_open_ratio = target


func interact(_interactor: Node = null) -> void:
	toggle_doors(true)


func _update_doors() -> void:
	if _door_left_pivot == null or _door_right_pivot == null:
		return

	var angle := doors_open_ratio * MAX_SWING_ANGLE
	_door_left_pivot.rotation.y = -angle
	_door_right_pivot.rotation.y = angle

	if storage != null:
		storage.open_ratio = doors_open_ratio
		storage.is_open = doors_open_ratio > 0.05

	# LAZY EVALUATION
	if _contents_pivot != null:
		_contents_pivot.visible = storage.should_render_contents()


func _on_storage_changed() -> void:
	_update_sink_items()


func _update_sink_items() -> void:
	if _contents_pivot == null:
		return

	for child in _contents_pivot.get_children():
		child.queue_free()

	var items: Dictionary = storage.get_all_items()
	var mat := FurniturePropsBuilderScript.get_props_material(0.45, 0.10)

	var offsets := [
		Vector3(-0.22, 0.12, 0.0),
		Vector3(-0.08, 0.12, 0.0),
		Vector3( 0.08, 0.12, 0.0),
		Vector3( 0.22, 0.12, 0.0)
	]

	var idx := 0
	for slot in items:
		if idx >= offsets.size():
			break
		var item_data: Dictionary = items[slot]
		var item_id: String = item_data.get("id", "")
		var mi := MeshInstance3D.new()
		mi.material_override = mat

		if item_id == "soup":
			mi.mesh = FurniturePropsBuilderScript.get_soup_can_mesh()
		elif item_id == "beer":
			mi.mesh = FurniturePropsBuilderScript.get_beer_can_mesh()
		elif item_id == "mug":
			mi.mesh = FurniturePropsBuilderScript.get_mug_mesh()
		elif item_id == "plate":
			mi.mesh = FurniturePropsBuilderScript.get_plate_mesh()
		else:
			mi.mesh = FurniturePropsBuilderScript.get_cereal_mesh()

		mi.position = offsets[idx]
		_contents_pivot.add_child(mi)
		idx += 1
