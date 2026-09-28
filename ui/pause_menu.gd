extends CanvasLayer
## Menú de Pausa in-game (PauseMenu).
## Se abre con Escape durante la partida en el mundo.
## Permite reanudar, abrir ajustes completos (controles y gráficos), guardar y salir al menú principal.

const SETTINGS_SCENE := preload("res://ui/settings_menu.tscn")

@onready var dimmer: ColorRect = $Dimmer
@onready var main_panel: Panel = $MainPanel
@onready var resume_button: Button = $MainPanel/VBox/ResumeButton
@onready var settings_button: Button = $MainPanel/VBox/SettingsButton
@onready var save_button: Button = $MainPanel/VBox/SaveButton
@onready var quit_button: Button = $MainPanel/VBox/QuitButton
@onready var status_label: Label = $MainPanel/VBox/StatusLabel
@onready var settings_container: Control = $SettingsContainer

var _settings_instance: Control = null
var _is_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.visible = false
	main_panel.visible = false
	settings_container.visible = false
	status_label.text = ""

	resume_button.pressed.connect(resume_game)
	settings_button.pressed.connect(_open_settings)
	save_button.pressed.connect(_on_save_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if Chat != null and Chat.is_open():
				return # El chat maneja su propio cierre con Escape
			if _is_paused:
				if settings_container.visible:
					_close_settings()
				else:
					resume_game()
				get_viewport().set_input_as_handled()
			else:
				pause_game()
				get_viewport().set_input_as_handled()


func pause_game() -> void:
	_is_paused = true
	visible = true
	dimmer.visible = true
	main_panel.visible = true
	settings_container.visible = false
	status_label.text = ""
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume_game() -> void:
	_is_paused = false
	visible = false
	dimmer.visible = false
	main_panel.visible = false
	settings_container.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	main_panel.visible = false
	settings_container.visible = true
	if _settings_instance == null:
		_settings_instance = SETTINGS_SCENE.instantiate()
		settings_container.add_child(_settings_instance)
		if _settings_instance.has_signal("back_requested"):
			_settings_instance.connect("back_requested", _close_settings)
		var bg := _settings_instance.get_node_or_null("Background")
		if bg != null:
			bg.visible = false


func _close_settings() -> void:
	settings_container.visible = false
	main_panel.visible = true


func _on_save_pressed() -> void:
	_perform_save()
	status_label.text = "¡Partida guardada exitosamente!"
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(status_label):
			status_label.text = ""
	)


func _on_quit_pressed() -> void:
	_perform_save()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _perform_save() -> void:
	var world := get_tree().current_scene
	if world != null and world.has_method("save_world_state"):
		world.call("save_world_state")
