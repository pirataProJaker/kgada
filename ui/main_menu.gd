extends Control
## Menu principal (pantalla de inicio del juego). Punto de entrada real en
## vez de abrir tests/world_test.tscn directo - ver /memories/repo del
## diseño: un solo juego, sin launcher aparte, con este menu como el
## "launcher" interno (Jugar / Multijugador / Crear contenido / Opciones).

@onready var play_button: TextureButton = $Buttons/PlayButton
@onready var multiplayer_button: TextureButton = $Buttons/MultiplayerButton
@onready var editor_button: TextureButton = $Buttons/EditorButton
@onready var options_button: TextureButton = $Buttons/OptionsButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	editor_button.pressed.connect(_on_editor_pressed)
	options_button.pressed.connect(_on_options_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/world_select_menu.tscn")


func _on_multiplayer_pressed() -> void:
	# TODO: pantalla de lista de servers (estilo lista de "experiencias" de
	# Roblox) - todavia no esta construida, ver diseño en memoria del repo.
	push_warning("[main_menu] Multijugador (lista de servers) todavia no esta implementado.")


func _on_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/map_select_menu.tscn")


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/settings_menu.tscn")
