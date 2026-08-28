extends Node
class_name Inventory
## Inventario del jugador. Por defecto imita los numeros de Minecraft
## (configurable via @export si algun dia se quiere otra cosa): un hotbar de
## 9 slots (0-8) + una cuadricula extra de 3 filas x 9 columnas = 27 -> 36
## slots en total. El slot del hotbar seleccionado es lo que el jugador
## "tiene en la mano" - lo usan HeldItemView (para mostrarlo) y
## PlacementController (para colocarlo en el mundo).

signal inventory_changed
signal selected_slot_changed(index: int)

@export var hotbar_size: int = 9
@export var extra_rows: int = 3
@export var extra_columns: int = 9
@export var max_stack_size: int = 64

var selected_index: int = 0
var slots: Array = [] # Array de {"definition": ObjectDefinition, "count": int}


func _ready() -> void:
	var total_slots := hotbar_size + extra_rows * extra_columns
	slots.resize(total_slots)
	for i in slots.size():
		slots[i] = {"definition": null, "count": 0}

	if get_parent().is_multiplayer_authority():
		add_to_group("local_inventory")


func get_slot(index: int) -> Dictionary:
	return slots[index]


func set_slot(index: int, definition: ObjectDefinition, count: int) -> void:
	if count <= 0 or definition == null:
		slots[index] = {"definition": null, "count": 0}
	else:
		slots[index] = {"definition": definition, "count": count}
	inventory_changed.emit()


func clear_slot(index: int) -> void:
	slots[index] = {"definition": null, "count": 0}
	inventory_changed.emit()


## Intenta agregar `count` unidades de `definition`: primero apila en slots
## existentes del mismo objeto, luego usa el primer slot vacio. Regresa
## cuantas unidades NO se pudieron meter (0 = todo entro completo).
func add_item(definition: ObjectDefinition, count: int) -> int:
	var remaining := count

	for i in slots.size():
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if slot.definition == definition and slot.count < max_stack_size:
			var space: int = max_stack_size - slot.count
			var added: int = min(space, remaining)
			slot.count += added
			remaining -= added

	for i in slots.size():
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if slot.definition == null:
			var added: int = min(max_stack_size, remaining)
			slots[i] = {"definition": definition, "count": added}
			remaining -= added

	inventory_changed.emit()
	return remaining


func select_hotbar_slot(index: int) -> void:
	if index < 0 or index >= hotbar_size:
		return
	selected_index = index
	selected_slot_changed.emit(index)


func get_selected_definition() -> ObjectDefinition:
	var slot: Dictionary = slots[selected_index]
	return slot.definition


## Quita `count` unidades del slot seleccionado (llamado al colocar el
## objeto en el mundo - "se consume" al ponerlo).
func consume_selected(count: int = 1) -> void:
	var slot: Dictionary = slots[selected_index]
	if slot.definition == null:
		return
	slot.count -= count
	if slot.count <= 0:
		slots[selected_index] = {"definition": null, "count": 0}
	inventory_changed.emit()
