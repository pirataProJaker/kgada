extends Node
## Autoload singleton ("SettingsManager"): guarda y recupera la configuracion
## del jugador (controles y graficos) en user://settings.cfg (formato ConfigFile).
## Otros sistemas (InputManager, ChunkManager, DisplayServer) leen de aqui.

const SETTINGS_PATH := "user://settings.cfg"

# Acciones configurables (tecla fisica por defecto)
const DEFAULT_KEYS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"interact": KEY_E,
	"toggle_inventory": KEY_V,
}

# Configuracion de graficos por defecto
const DEFAULT_GRAPHICS := {
	"view_distance_chunks": 1,   # radio en chunks (1 = 3x3 = 9 chunks)
	"window_mode": 0,            # 0 = ventana, 1 = pantalla completa, 2 = sin bordes
	"vsync": true,
}

var keys: Dictionary = {}
var graphics: Dictionary = {}


func _ready() -> void:
	load_settings()


## Carga la configuracion desde user://settings.cfg (o usa los valores por
## defecto si no existe).
func load_settings() -> void:
	keys = DEFAULT_KEYS.duplicate()
	graphics = DEFAULT_GRAPHICS.duplicate()

	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		return # no hay configuracion guardada, usar defaults

	# Cargar teclas
	for action in DEFAULT_KEYS.keys():
		if config.has_section_key("controls", action):
			keys[action] = config.get_value("controls", action, DEFAULT_KEYS[action])

	# Cargar graficos
	for setting in DEFAULT_GRAPHICS.keys():
		if config.has_section_key("graphics", setting):
			graphics[setting] = config.get_value("graphics", setting, DEFAULT_GRAPHICS[setting])


## Guarda la configuracion actual en user://settings.cfg.
func save_settings() -> void:
	var config := ConfigFile.new()
	for action in keys.keys():
		config.set_value("controls", action, keys[action])
	for setting in graphics.keys():
		config.set_value("graphics", setting, graphics[setting])
	config.save(SETTINGS_PATH)


## Devuelve la tecla fisica (KEY_*) asignada a una accion de movimiento.
func get_key(action: String) -> int:
	return keys.get(action, DEFAULT_KEYS.get(action, KEY_UNKNOWN))


## Asigna una tecla fisica a una accion y guarda.
func set_key(action: String, keycode: int) -> void:
	keys[action] = keycode
	save_settings()


## Devuelve el nombre legible de una tecla (ej. "W", "Espacio").
static func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)


## Aplica la configuracion de graficos (modo ventana, vsync).
func apply_graphics() -> void:
	var mode: int = graphics.get("window_mode", 0)
	match mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if graphics.get("vsync", true) else DisplayServer.VSYNC_DISABLED
	)


## Devuelve la distancia de chunks configurada.
func get_view_distance() -> int:
	return graphics.get("view_distance_chunks", 1)
