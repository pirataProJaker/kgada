class_name BookcaseTall
extends Node3D

## Librero Alto Modular de Roble (Bookcase Tall)
## - Malla primaria exacta (120 tris) con estanterías y laterales de roble natural
## - Inicia COMPLETAMENTE VACÍO (0 libros pre-renderizados, 0 draw calls de libros)
## - 5 repisas con 20 ranuras modulares de libros (4 libros por repisa)
## - Integrado con FurnitureStorageContainer en modo SLOTS_3D
## - Permite insertar y retirar libros de forma modular (insert_book, take_book)
## - Malla compartida get_shared_mesh() para GPU Instancing (1 solo Draw Call en MultiMesh)

const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureStorageContainerScript = preload("res://world/furniture/furniture_storage_container.gd")

@export_group("Dimensiones")
@export var width: float = 0.80           ## Ancho total (80cm)
@export var depth: float = 0.30           ## Fondo total (30cm)
@export var height: float = 1.80          ## Altura total (1.80m)

const SHELF_Y_LEVELS: Array[float] = [0.02, 0.416, 0.762, 1.108, 1.454]
const BOOK_X_OFFSETS: Array[float] = [-0.24, -0.08, 0.08, 0.24]

var storage: FurnitureStorageContainerScript = null
var _book_nodes: Dictionary = {} # slot_index -> MeshInstance3D
var _frame_instance: MeshInstance3D = null
var _collision_body: StaticBody3D = null


## Retorna la malla compartida del librero vacío para GPU Instancing
static func get_shared_mesh() -> ArrayMesh:
	return FurniturePropsBuilderScript.get_bookcase_empty_mesh()


## Retorna las cajas de colisión para física del librero
static func get_collision_boxes(w: float = 0.80, d: float = 0.30, h: float = 1.80) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		}
	]


func _init() -> void:
	# 20 ranuras modulares de libros (5 repisas x 4 libros)
	storage = FurnitureStorageContainerScript.new(FurnitureStorageContainerScript.StorageMode.SLOTS_3D, 20)
	storage.is_open = true # Las repisas de un librero abierto siempre son visibles cuando tienen libros
	storage.storage_changed.connect(_on_storage_changed)


func _ready() -> void:
	_build_bookcase()


func _build_bookcase() -> void:
	for child in get_children():
		child.queue_free()
	_book_nodes.clear()

	var mat := FurniturePropsBuilderScript.get_props_material(0.65, 0.02)

	# 1. Armazón del librero vacío (figura primaria con texturizado de roble auténtico)
	var mesh := get_shared_mesh()
	_frame_instance = MeshInstance3D.new()
	_frame_instance.name = "BookcaseFrame"
	_frame_instance.mesh = mesh
	_frame_instance.material_override = mat
	add_child(_frame_instance)

	# 2. Colisión física sólida
	_collision_body = StaticBody3D.new()
	_collision_body.name = "BookcaseCollision"
	var c_shape := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(width, height, depth)
	c_shape.shape = b_shape
	c_shape.position = Vector3(0.0, height * 0.5, 0.0)
	_collision_body.add_child(c_shape)
	add_child(_collision_body)

	# 3. Actualizar libros visuales si hay items guardados
	_update_visual_books()


## Inserta un libro en una ranura específica (0 a 19) o en la primera ranura libre
func insert_book(slot: int = -1, book_type: String = "bible", custom_title: String = "") -> bool:
	var book_data := FurnitureStorageContainerScript.create_book(book_type, custom_title)
	var success: bool = storage.add_item(book_data, slot)
	if success:
		_update_visual_books()
	return success


## Retira el libro de una ranura específica
func take_book(slot: int) -> Dictionary:
	var item: Dictionary = storage.remove_item_at_slot(slot)
	if not item.is_empty():
		_update_visual_books()
	return item


## Retorna la transformación local exacta de una ranura modular de libro (0 a 19)
func get_slot_transform(slot_index: int) -> Transform3D:
	var shelf_idx: int = clampi(slot_index / 4, 0, SHELF_Y_LEVELS.size() - 1)
	var book_in_shelf: int = clampi(slot_index % 4, 0, BOOK_X_OFFSETS.size() - 1)

	var shelf_y := SHELF_Y_LEVELS[shelf_idx]
	var slot_x := BOOK_X_OFFSETS[book_in_shelf]
	var slot_z := 0.0 # Centrado en el fondo del estante

	return Transform3D(Basis.IDENTITY, Vector3(slot_x, shelf_y, slot_z))


func _on_storage_changed() -> void:
	_update_visual_books()


## Sincroniza los nodos visuales 3D de los libros con el contenedor en RAM
func _update_visual_books() -> void:
	var current_items: Dictionary = storage.get_all_items()

	# Eliminar libros que ya no están
	var to_remove: Array[int] = []
	for slot in _book_nodes:
		if not current_items.has(slot):
			to_remove.append(slot)
	for slot in to_remove:
		if is_instance_valid(_book_nodes[slot]):
			_book_nodes[slot].queue_free()
		_book_nodes.erase(slot)

	# Instanciar o actualizar libros presentes
	var mat := FurniturePropsBuilderScript.get_props_material(0.65, 0.02)
	for slot in current_items:
		if not _book_nodes.has(slot):
			var b_data: Dictionary = current_items[slot]
			var b_type: String = b_data.get("book_type", "bible")
			var b_mesh := FurniturePropsBuilderScript.get_book_mesh(b_type)

			var mi := MeshInstance3D.new()
			mi.name = "Book_Slot_%d" % slot
			mi.mesh = b_mesh
			mi.material_override = mat
			mi.transform = get_slot_transform(slot)
			add_child(mi)
			_book_nodes[slot] = mi
