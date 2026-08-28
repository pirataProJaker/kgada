extends Control
## Menu de configuracion: dos pestañas - "Controles" (reconfigurar teclas) y
## "Graficos" (chunks renderizados, modo ventana, vsync). Usa el mismo estilo
## de panel semi transparente que el selector de mundos.

@onready var controls_tab: Button = $Panel/VBox/Tabs/ControlsTab
@onready var graphics_tab: Button = $Panel/VBox/Tabs/GraphicsTab
@onready var controls_panel: Control = $Panel/VBox/Content/ControlsPanel
@onready var graphics_panel: Control = $Panel/VBox/Content/GraphicsPanel
@onready var back_button: Button = $Panel/VBox/Buttons/BackButton

# Controles
@onready var key_buttons: Dictionary = {
	"move_forward": $Panel/VBox/Content/ControlsPanel/ForwardRow/KeyButton,
	"move_back": $Panel/VBox/Content/ControlsPanel/BackRow/KeyButton,
	"move_left": $Panel/VBox/Content/ControlsPanel/LeftRow/KeyButton,
	"move_right": $Panel/VBox/Content/ControlsPanel/RightRow/KeyButton,
	"jump": $Panel/VBox/Content/ControlsPanel/JumpRow/KeyButton,
	"interact": $Panel/VBox/Content/ControlsPanel/InteractRow/KeyButton,
	"toggle_inventory": $Panel/VBox/Content/ControlsPanel/InventoryRow/KeyButton,
}

# Graficos
@onready var chunks_spin: SpinBox = $Panel/VBox/Content/GraphicsPanel/ChunksRow/ChunksSpin
@onready var window_option: OptionButton = $Panel/VBox/Content/GraphicsPanel/WindowRow/WindowOption
@onready var vsync_check: CheckButton = $Panel/VBox/Content/GraphicsPanel/VsyncRow/VsyncCheck

var _awaiting_key: String = ""


func _ready() -> void:
	controls_tab.pressed.connect(func(): _show_tab(true))
	graphics_tab.pressed.connect(func(): _show_tab(false))
	back_button.pressed.connect(_on_back_pressed)

	# Conectar botones de teclas
	for action in key_buttons.keys():
		key_buttons[action].pressed.connect(_on_key_button_pressed.bind(action))

	# Conectar graficos
	chunks_spin.value_changed.connect(_on_chunks_changed)
	window_option.item_selected.connect(_on_window_changed)
	vsync_check.toggled.connect(_on_vsync_changed)

	# Opciones del modo ventana
	window_option.add_item("Ventana")
	window_option.add_item("Pantalla completa")
	window_option.add_item("Sin bordes")

	_refresh_controls()
	_refresh_graphics()
	_show_tab(true)


func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_key.is_empty():
		return
	if event is InputEventKey and event.pressed:
		var keycode: int = (event as InputEventKey).physical_keycode
		if keycode != KEY_ESCAPE:
			SettingsManager.set_key(_awaiting_key, keycode)
		_awaiting_key = ""
		_refresh_controls()
		get_viewport().set_input_as_handled()


## Muestra la pestana de controles (true) o graficos (false).
func _show_tab(show_controls: bool) -> void:
	controls_panel.visible = show_controls
	graphics_panel.visible = not show_controls
	controls_tab.button_pressed = show_controls
	graphics_tab.button_pressed = not show_controls


## Refresca los botones de teclas con la configuracion actual.
func _refresh_controls() -> void:
	for action in key_buttons.keys():
		var btn: Button = key_buttons[action]
		btn.text = SettingsManager.key_name(SettingsManager.get_key(action))


## Refresca los controles de graficos con la configuracion actual.
func _refresh_graphics() -> void:
	chunks_spin.value = SettingsManager.get_view_distance()
	window_option.selected = SettingsManager.graphics.get("window_mode", 0)
	vsync_check.button_pressed = SettingsManager.graphics.get("vsync", true)


func _on_key_button_pressed(action: String) -> void:
	_awaiting_key = action
	for btn in key_buttons.values():
		btn.text = "..." if btn == key_buttons[action] else SettingsManager.key_name(SettingsManager.get_key(action))


func _on_chunks_changed(value: float) -> void:
	SettingsManager.graphics["view_distance_chunks"] = int(value)
	SettingsManager.save_settings()


func _on_window_changed(index: int) -> void:
	SettingsManager.graphics["window_mode"] = index
	SettingsManager.save_settings()
	SettingsManager.apply_graphics()


func _on_vsync_changed(enabled: bool) -> void:
	SettingsManager.graphics["vsync"] = enabled
	SettingsManager.save_settings()
	SettingsManager.apply_graphics()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
