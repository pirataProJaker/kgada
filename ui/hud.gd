extends CanvasLayer
## HUD del jugador: hotbar siempre visible (numeros 1-9 y rueda del mouse
## para cambiar de slot) + pantalla de inventario completa que se abre con
## una tecla configurable (V por defecto, ver SettingsManager - accion
## "toggle_inventory"). Interaccion "estilo Minecraft": click en un slot toma
## su contenido con el cursor, click en otro lo intercambia.
##
## Numero de slots por defecto = los mismos que Minecraft (9 en el hotbar +
## 27 de inventario extra = 36), pero se lee directamente de la Inventory
## del jugador (que es @export-configurable) - este HUD nunca asume un
## numero fijo, se arma solo con lo que la Inventory tenga.

const SLOT_SIZE := 56

@onready var hotbar_slots_container: HBoxContainer = $Hotbar/Slots
@onready var inventory_panel: Control = $InventoryPanel
@onready var inventory_grid: GridContainer = $InventoryPanel/Panel/Grid
@onready var cursor_label: Label = $CursorLabel

var _inventory: Inventory = null
var _hotbar_slot_buttons: Array = []
var _inventory_slot_buttons: Array = []
var _cursor_slot: Dictionary = {"definition": null, "count": 0}
var _inventory_open := false


func _ready() -> void:
	inventory_panel.visible = false
	cursor_label.visible = false


func _process(_delta: float) -> void:
	if _inventory == null:
		_try_bind_inventory()
		return

	if _inventory_open:
		cursor_label.global_position = get_viewport().get_mouse_position() + Vector2(12, 12)


func _try_bind_inventory() -> void:
	var found := get_tree().get_nodes_in_group("local_inventory")
	if found.is_empty():
		return

	_inventory = found[0]
	_inventory.inventory_changed.connect(_refresh_all)
	_inventory.selected_slot_changed.connect(func(_i: int) -> void: _refresh_hotbar_selection())
	_build_slots()
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if _inventory == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == SettingsManager.get_key("toggle_inventory"):
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_inventory.select_hotbar_slot(event.keycode - KEY_1)

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_inventory.select_hotbar_slot(wrapi(_inventory.selected_index - 1, 0, _inventory.hotbar_size))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_inventory.select_hotbar_slot(wrapi(_inventory.selected_index + 1, 0, _inventory.hotbar_size))


func _toggle_inventory() -> void:
	_inventory_open = not _inventory_open
	inventory_panel.visible = _inventory_open
	cursor_label.visible = _inventory_open and _cursor_slot.definition != null

	if _inventory_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_return_cursor_to_inventory()


## Si el jugador cierra el inventario mientras tenia algo "levantado" con el
## cursor, lo regresa al primer slot vacio disponible en vez de perderlo.
func _return_cursor_to_inventory() -> void:
	if _cursor_slot.definition == null:
		return
	_inventory.add_item(_cursor_slot.definition, _cursor_slot.count)
	_cursor_slot = {"definition": null, "count": 0}
	cursor_label.visible = false


func _build_slots() -> void:
	for child in hotbar_slots_container.get_children():
		child.queue_free()
	for child in inventory_grid.get_children():
		child.queue_free()
	_hotbar_slot_buttons.clear()
	_inventory_slot_buttons.clear()

	for i in _inventory.hotbar_size:
		var button := _make_slot_button(i)
		hotbar_slots_container.add_child(button)
		_hotbar_slot_buttons.append(button)

	inventory_grid.columns = _inventory.extra_columns
	for i in _inventory.slots.size():
		var button := _make_slot_button(i)
		inventory_grid.add_child(button)
		_inventory_slot_buttons.append(button)


func _make_slot_button(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	button.clip_text = true
	button.pressed.connect(_on_slot_pressed.bind(index))

	var count_label := Label.new()
	count_label.name = "Count"
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count_label)

	return button


func _refresh_all() -> void:
	for i in _hotbar_slot_buttons.size():
		_refresh_slot_button(_hotbar_slot_buttons[i], i)
	for i in _inventory_slot_buttons.size():
		_refresh_slot_button(_inventory_slot_buttons[i], i)
	_refresh_hotbar_selection()


func _refresh_slot_button(button: Button, index: int) -> void:
	var slot: Dictionary = _inventory.get_slot(index)
	var count_label: Label = button.get_node("Count")
	if slot.definition == null:
		button.text = ""
		count_label.text = ""
	else:
		button.text = slot.definition.display_name
		count_label.text = str(slot.count) if slot.count > 1 else ""


func _refresh_hotbar_selection() -> void:
	for i in _hotbar_slot_buttons.size():
		var button: Button = _hotbar_slot_buttons[i]
		button.modulate = Color(1, 1, 0.5) if i == _inventory.selected_index else Color(1, 1, 1)


## Interaccion tipo Minecraft: si el cursor esta vacio, levanta el
## contenido del slot; si ya tiene algo, lo intercambia con el slot.
func _on_slot_pressed(index: int) -> void:
	var slot: Dictionary = _inventory.get_slot(index)

	if _cursor_slot.definition == null:
		if slot.definition == null:
			return
		_cursor_slot = slot.duplicate()
		_inventory.clear_slot(index)
	else:
		var previous: Dictionary = slot.duplicate()
		_inventory.set_slot(index, _cursor_slot.definition, _cursor_slot.count)
		_cursor_slot = previous

	_update_cursor_label()
	_refresh_all()


func _update_cursor_label() -> void:
	if _cursor_slot.definition == null:
		cursor_label.visible = false
		return
	cursor_label.visible = true
	var count_text := " x%d" % _cursor_slot.count if _cursor_slot.count > 1 else ""
	cursor_label.text = _cursor_slot.definition.display_name + count_text
