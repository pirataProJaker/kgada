class_name NightstandOak
extends Node3D

## Mesa de Noche de Roble con Cajón Deslizante (Nightstand Oak)
## - Malla primaria exacta calibrada al atlas oficial con veta de roble y cajón enmarcado
## - Cajón deslizante interactivo en el eje Z (0 a 20cm) con Tween y tecla [E]
## - Almacenamiento desacoplado mediante FurnitureStorageContainer (Modo DRAWER_SLIDING)
## - Lazy Evaluation para GPU: Cuando el cajón está cerrado, los ítems interiores
##   NO se renderizan (0 draw calls, 0 vértices).
## - Malla unificada get_shared_mesh() para 1 solo Draw Call en GPU Instancing.

const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureStorageContainerScript = preload("res://world/furniture/furniture_storage_container.gd")
const FurnitureInteractProxyScript = preload("res://world/furniture/furniture_interact_proxy.gd")

@export_group("Dimensiones")
@export var width: float = 0.48
@export var depth: float = 0.43
@export var height: float = 0.705

@export_group("Cajón")
@export_range(0.0, 1.0) var drawer_open_ratio: float = 0.0:
	set(val):
		drawer_open_ratio = clampf(val, 0.0, 1.0)
		_update_drawer_position()

const DRAWER_TRAVEL: float = 0.20 ## Recorrido deslizante hacia adelante (20cm)

var storage: FurnitureStorageContainerScript = null
var _frame_mesh_instance: MeshInstance3D = null
var _drawer_pivot: Node3D = null
var _drawer_mesh_instance: MeshInstance3D = null
var _contents_pivot: Node3D = null
var _collision_body: StaticBody3D = null
var _interact_proxy: FurnitureInteractProxy = null


## Retorna la malla compartida completa (cuerpo + cajón cerrado) para GPU Instancing
static func get_shared_mesh() -> ArrayMesh:
	return FurniturePropsBuilderScript.get_nightstand_complete_mesh()


## Retorna las cajas de colisión para el sistema MultiMesh
static func get_collision_boxes(w: float = 0.48, d: float = 0.43, h: float = 0.705) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		}
	]


func _init() -> void:
	storage = FurnitureStorageContainerScript.new(FurnitureStorageContainerScript.StorageMode.DRAWER_SLIDING, 4)
	storage.storage_changed.connect(_on_storage_changed)


func _ready() -> void:
	_build_nightstand()


func _build_nightstand() -> void:
	for child in get_children():
		child.queue_free()

	var mat := FurniturePropsBuilderScript.get_props_material(0.60, 0.02)

	# 1. Armazón principal
	_frame_mesh_instance = MeshInstance3D.new()
	_frame_mesh_instance.name = "FrameMesh"
	_frame_mesh_instance.mesh = FurniturePropsBuilderScript.get_nightstand_frame_mesh()
	_frame_mesh_instance.material_override = mat
	add_child(_frame_mesh_instance)

	# 2. Pivote y Malla del Cajón Deslizante
	_drawer_pivot = Node3D.new()
	_drawer_pivot.name = "DrawerPivot"
	_drawer_pivot.position = Vector3.ZERO
	add_child(_drawer_pivot)

	_drawer_mesh_instance = MeshInstance3D.new()
	_drawer_mesh_instance.name = "DrawerMesh"
	_drawer_mesh_instance.mesh = FurniturePropsBuilderScript.get_nightstand_drawer_mesh()
	_drawer_mesh_instance.material_override = mat
	_drawer_pivot.add_child(_drawer_mesh_instance)

	# 3. Contenedor de visuales de ítems interiores (Lazy Evaluation)
	_contents_pivot = Node3D.new()
	_contents_pivot.name = "ContentsPivot"
	_contents_pivot.visible = false
	_drawer_pivot.add_child(_contents_pivot)

	# 4. Colisión estática base
	_collision_body = StaticBody3D.new()
	_collision_body.name = "NightstandCollision"
	var c_shape := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(width, height, depth)
	c_shape.shape = b_shape
	c_shape.position = Vector3(0.0, height * 0.5, 0.0)
	_collision_body.add_child(c_shape)
	add_child(_collision_body)

	# 5. Proxy de interacción para tecla [E]
	_interact_proxy = FurnitureInteractProxyScript.new()
	_interact_proxy.name = "InteractProxy"
	_interact_proxy.target_node = self
	var p_shape := CollisionShape3D.new()
	var p_box := BoxShape3D.new()
	p_box.size = Vector3(width * 0.9, 0.20, 0.08)
	p_shape.shape = p_box
	p_shape.position = Vector3(0.0, 0.55, depth * 0.5 + 0.02)
	_interact_proxy.add_child(p_shape)
	add_child(_interact_proxy)

	_update_drawer_position()


## Alterna la apertura / cierre del cajón
func toggle_drawer(animated: bool = true) -> void:
	var target := 1.0 if drawer_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "drawer_open_ratio", target, 0.35)
	else:
		drawer_open_ratio = target


func interact(_interactor: Node = null) -> void:
	toggle_drawer(true)


func _update_drawer_position() -> void:
	if _drawer_pivot == null:
		return

	_drawer_pivot.position.z = drawer_open_ratio * DRAWER_TRAVEL

	if storage != null:
		storage.open_ratio = drawer_open_ratio
		storage.is_open = drawer_open_ratio > 0.05

	# LAZY EVALUATION
	if _contents_pivot != null:
		var should_show: bool = storage.should_render_contents()
		_contents_pivot.visible = should_show


func _on_storage_changed() -> void:
	_update_drawer_items()


func _update_drawer_items() -> void:
	if _contents_pivot == null:
		return

	for child in _contents_pivot.get_children():
		child.queue_free()

	var items: Dictionary = storage.get_all_items()
	var mat := FurniturePropsBuilderScript.get_props_material(0.60, 0.02)

	var offsets := [
		Vector3(-0.08, 0.50, -0.04),
		Vector3( 0.08, 0.50, -0.04),
		Vector3(-0.08, 0.50,  0.06),
		Vector3( 0.08, 0.50,  0.06)
	]

	var idx := 0
	for slot in items:
		if idx >= offsets.size():
			break
		var item_data: Dictionary = items[slot]
		var item_id: String = item_data.get("id", "")
		var mi := MeshInstance3D.new()
		mi.material_override = mat

		if item_id == "milk":
			mi.mesh = FurniturePropsBuilderScript.get_milk_mesh()
		elif item_id == "cereal":
			mi.mesh = FurniturePropsBuilderScript.get_cereal_mesh()
		elif item_id == "soup":
			mi.mesh = FurniturePropsBuilderScript.get_soup_can_mesh()
		elif item_id == "beer":
			mi.mesh = FurniturePropsBuilderScript.get_beer_can_mesh()
		elif item_id == "mug":
			mi.mesh = FurniturePropsBuilderScript.get_mug_mesh()
		elif item_id.begins_with("book"):
			mi.mesh = FurniturePropsBuilderScript.get_book_mesh(item_data.get("book_type", "bible"))
		else:
			mi.mesh = FurniturePropsBuilderScript.get_newspaper_mesh()

		mi.position = offsets[idx]
		_contents_pivot.add_child(mi)
		idx += 1
