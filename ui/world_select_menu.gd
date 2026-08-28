extends Control
## Lista de mundos disponibles. Desde aqui se puede continuar un mundo
## existente o abrir el formulario para crear uno nuevo.

@onready var world_list: ItemList = $Panel/VBox/WorldList
@onready var create_button: Button = $Panel/VBox/Buttons/CreateButton
@onready var play_button: Button = $Panel/VBox/Buttons/PlayButton
@onready var back_button: Button = $Panel/VBox/Buttons/BackButton

var _selected_world_id := ""


func _ready() -> void:
	_refresh_world_list()
	world_list.item_selected.connect(_on_world_selected)
	create_button.pressed.connect(_on_create_pressed)
	play_button.pressed.connect(_on_play_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _refresh_world_list() -> void:
	world_list.clear()
	_selected_world_id = ""

	var worlds: Array = SaveManager.get_worlds()
	for world in worlds:
		var world_name := str(world.get("name", "Mundo sin nombre"))
		var world_seed := int(world.get("world_seed", SaveManager.DEFAULT_WORLD_SEED))
		var status := "guardado" if bool(world.get("has_progress", false)) else "nuevo"
		var index := world_list.add_item("%s  |  Semilla: %d  |  %s" % [world_name, world_seed, status])
		world_list.set_item_metadata(index, str(world.get("id", "")))

	if worlds.is_empty():
		world_list.add_item("No hay mundos creados todavia")
		play_button.disabled = true
		return

	world_list.select(0)
	_selected_world_id = str(world_list.get_item_metadata(0))
	play_button.disabled = false


func _on_world_selected(index: int) -> void:
	_selected_world_id = str(world_list.get_item_metadata(index))
	play_button.disabled = _selected_world_id.is_empty()


func _on_create_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/world_create_menu.tscn")


func _on_play_pressed() -> void:
	if _selected_world_id.is_empty() or not SaveManager.select_world(_selected_world_id):
		return
	get_tree().change_scene_to_file("res://tests/world_test.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
