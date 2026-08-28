extends Control

const MAP_DOCUMENT_SCRIPT := preload("res://map_editor/map_document.gd")
const MAP_LIBRARY_SCRIPT := preload("res://map_editor/map_library.gd")
const MAP_DRAFT_PATH := "user://map_editor_draft.json"
const DEFAULT_MAP_GRID_SIZE := Vector2i(65, 65)

@onready var saved_map_list: ItemList = $Panel/VBox/SavedMapList
@onready var open_map_button: Button = $Panel/VBox/Buttons/OpenMapButton
@onready var create_map_button: Button = $Panel/VBox/Buttons/CreateMapButton
@onready var back_button: Button = $Panel/VBox/Buttons/BackButton
@onready var new_map_dialog: ConfirmationDialog = $NewMapDialog
@onready var new_map_name_input: LineEdit = $NewMapDialog/Content/MapNameInput
@onready var error_label: Label = $NewMapDialog/Content/ErrorLabel


func _ready() -> void:
	_refresh_saved_map_list()
	saved_map_list.item_selected.connect(_on_saved_map_selected)
	saved_map_list.item_activated.connect(_on_saved_map_activated)
	open_map_button.pressed.connect(_on_open_map_pressed)
	create_map_button.pressed.connect(_on_create_map_pressed)
	back_button.pressed.connect(_on_back_pressed)
	new_map_dialog.confirmed.connect(_on_new_map_confirmed)
	_update_open_map_button()


func _refresh_saved_map_list() -> void:
	saved_map_list.clear()
	var selected_index := -1
	for path in MAP_LIBRARY_SCRIPT.get_saved_map_paths():
		var saved_document = MAP_DOCUMENT_SCRIPT.load_from_file(path)
		if saved_document == null:
			continue
		var item_text := "%s  |  %d x %d" % [
			str(saved_document.map_name),
			saved_document.grid_size.x,
			saved_document.grid_size.y,
		]
		var item_index := saved_map_list.add_item(item_text)
		saved_map_list.set_item_metadata(item_index, path)

	if saved_map_list.item_count == 0 and FileAccess.file_exists(MAP_DRAFT_PATH):
		var draft = MAP_DOCUMENT_SCRIPT.load_from_file(MAP_DRAFT_PATH)
		if draft != null:
			var draft_index := saved_map_list.add_item("%s  |  borrador actual" % str(draft.map_name))
			saved_map_list.set_item_metadata(draft_index, MAP_DRAFT_PATH)
			selected_index = draft_index

	if saved_map_list.item_count == 0:
		var empty_index := saved_map_list.add_item("No hay mapas guardados todavia")
		saved_map_list.set_item_metadata(empty_index, "")
		saved_map_list.set_item_disabled(empty_index, true)
	else:
		if selected_index < 0:
			selected_index = 0
		saved_map_list.select(selected_index)

	_update_open_map_button()


func _update_open_map_button() -> void:
	var selected_items := saved_map_list.get_selected_items()
	open_map_button.disabled = selected_items.is_empty()
	if not selected_items.is_empty():
		open_map_button.disabled = str(saved_map_list.get_item_metadata(selected_items[0])).is_empty()


func _on_saved_map_selected(_index: int) -> void:
	_update_open_map_button()


func _on_saved_map_activated(_index: int) -> void:
	_open_selected_map()


func _on_open_map_pressed() -> void:
	_open_selected_map()


func _open_selected_map() -> void:
	var selected_items := saved_map_list.get_selected_items()
	if selected_items.is_empty():
		return
	var map_path := str(saved_map_list.get_item_metadata(selected_items[0]))
	if map_path.is_empty() or MAP_DOCUMENT_SCRIPT.load_from_file(map_path) == null:
		error_label.text = "No se pudo cargar el mapa seleccionado."
		return
	_open_editor_with_map(map_path)


func _on_create_map_pressed() -> void:
	new_map_name_input.clear()
	error_label.text = ""
	new_map_dialog.popup_centered()
	call_deferred("_focus_new_map_name")


func _focus_new_map_name() -> void:
	if new_map_dialog.visible:
		new_map_name_input.grab_focus()


func _on_new_map_confirmed() -> void:
	var map_name := new_map_name_input.text.strip_edges()
	if map_name.is_empty():
		error_label.text = "Escribe un nombre para el mapa."
		new_map_dialog.popup_centered()
		call_deferred("_focus_new_map_name")
		return

	var new_document = MAP_DOCUMENT_SCRIPT.new(DEFAULT_MAP_GRID_SIZE)
	new_document.map_name = map_name
	var map_path := MAP_LIBRARY_SCRIPT.next_map_path()
	if not new_document.save_to_file(map_path) or not new_document.save_to_file(MAP_DRAFT_PATH):
		error_label.text = "No se pudo guardar el mapa."
		return
	_open_editor_with_map(map_path)


func _open_editor_with_map(map_path: String) -> void:
	get_tree().set_meta("map_editor_document_path", map_path)
	var result := get_tree().change_scene_to_file("res://map_editor/map_editor.tscn")
	if result != OK:
		get_tree().remove_meta("map_editor_document_path")
		error_label.text = "No se pudo abrir el editor."


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")