extends Control
## Formulario minimo para crear un mundo: nombre obligatorio y semilla
## opcional. Una semilla vacia se reemplaza por una aleatoria.

@onready var world_name_input: LineEdit = $Panel/VBox/WorldNameInput
@onready var seed_input: LineEdit = $Panel/VBox/SeedInput
@onready var error_label: Label = $Panel/VBox/ErrorLabel
@onready var create_button: Button = $Panel/VBox/Buttons/CreateButton
@onready var back_button: Button = $Panel/VBox/Buttons/BackButton


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	back_button.pressed.connect(_on_back_pressed)
	world_name_input.grab_focus()


func _on_create_pressed() -> void:
	var world_name := world_name_input.text.strip_edges()
	if world_name.is_empty():
		_show_error("Escribe un nombre para el mundo.")
		world_name_input.grab_focus()
		return

	var seed_text := seed_input.text.strip_edges()
	var world_seed: int
	if seed_text.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		world_seed = rng.randi_range(-2147483647, 2147483647)
	elif not seed_text.is_valid_int():
		_show_error("La semilla debe ser un numero entero o quedar vacia.")
		seed_input.grab_focus()
		return
	else:
		world_seed = int(seed_text)

	var world := SaveManager.create_world(world_name, world_seed)
	if world.is_empty():
		_show_error("No se pudo crear el mundo.")
		return

	get_tree().change_scene_to_file("res://tests/world_test.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/world_select_menu.tscn")


func _show_error(message: String) -> void:
	error_label.text = message