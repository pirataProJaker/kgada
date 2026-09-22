extends CanvasLayer

## Superposición de depuración: Contador de FPS en tiempo real y gráfica de Frame Time (arriba a la izquierda).
## Tecla F3 para ocultar/mostrar.

@export var enabled: bool = true:
	set(value):
		enabled = value
		visible = value

const HISTORY_SIZE := 100
const GRAPH_WIDTH := 160.0
const GRAPH_HEIGHT := 48.0
const TARGET_FRAME_TIME_MS := 16.667 # 60 FPS = 16.66 ms

var _history: Array[float] = []
var _fps_label: Label
var _graph_control: Control
var _fps_update_timer := 0.0
var _cached_fps_text := ""


func _ready() -> void:
	layer = 128
	visible = enabled
	_setup_ui()


func _setup_ui() -> void:
	var root_panel := PanelContainer.new()
	root_panel.name = "FPSPanel"
	root_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_panel.offset_left = 12
	root_panel.offset_top = 12
	add_child(root_panel)

	# Estilo PSX oscuro semi-transparente
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.12, 0.82)
	style.border_color = Color(0.3, 0.4, 0.45, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	root_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	root_panel.add_child(vbox)

	_fps_label = Label.new()
	_fps_label.name = "FPSLabel"
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size", 13)
	_fps_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_fps_label.text = "FPS: -- (-- ms)\nMin: -- | 1% Low: --"
	vbox.add_child(_fps_label)

	_graph_control = Control.new()
	_graph_control.name = "GraphView"
	_graph_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_control.custom_minimum_size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)
	_graph_control.draw.connect(_on_graph_draw)
	vbox.add_child(_graph_control)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			enabled = not enabled


func _process(delta: float) -> void:
	if not visible:
		return

	var frame_time_ms := delta * 1000.0
	_history.append(frame_time_ms)
	if _history.size() > HISTORY_SIZE:
		_history.pop_front()

	_fps_update_timer += delta
	if _fps_update_timer >= 0.15: # Actualiza texto cada 150ms para no saturar la vista
		_fps_update_timer = 0.0
		_update_labels(frame_time_ms)

	_graph_control.queue_redraw()


func _update_labels(last_frame_time_ms: float) -> void:
	var fps := Engine.get_frames_per_second()
	
	# Calcular Minimo y 1% Low de los ultimos fotogramas
	var max_frame_time := 0.0
	var sorted_times := _history.duplicate()
	sorted_times.sort()
	
	for t in _history:
		if t > max_frame_time:
			max_frame_time = t
	
	var min_fps: int = int(1000.0 / max_frame_time) if max_frame_time > 0.001 else fps
	
	# 1% Low (el percentil 99 de tiempos de fotograma más lentos)
	var p99_idx := clampi(int(float(sorted_times.size()) * 0.99), 0, sorted_times.size() - 1)
	var p99_time: float = float(sorted_times[p99_idx]) if not sorted_times.is_empty() else last_frame_time_ms
	var one_percent_low: int = int(1000.0 / p99_time) if p99_time > 0.001 else fps

	# Color segun salud de FPS
	var color_tag := "green"
	if fps < 35 or min_fps < 25:
		color_tag = "red"
	elif fps < 55 or min_fps < 45:
		color_tag = "yellow"

	_fps_label.text = "FPS: %d (%.1f ms)\nMin: %d | 1%% Low: %d" % [fps, last_frame_time_ms, min_fps, one_percent_low]
	if color_tag == "green":
		_fps_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
	elif color_tag == "yellow":
		_fps_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	else:
		_fps_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))


func _on_graph_draw() -> void:
	var size := _graph_control.size
	var bg_rect := Rect2(Vector2.ZERO, size)
	
	# Fondo de la grafica
	_graph_control.draw_rect(bg_rect, Color(0.04, 0.05, 0.06, 0.9), true)
	_graph_control.draw_rect(bg_rect, Color(0.2, 0.25, 0.3, 0.6), false, 1.0)

	# Linea guia 60 FPS (16.6 ms)
	var y_60fps := size.y - (16.667 / 50.0) * size.y
	_graph_control.draw_line(Vector2(0, y_60fps), Vector2(size.x, y_60fps), Color(0.2, 0.8, 0.4, 0.35), 1.0)

	# Linea guia 30 FPS (33.3 ms)
	var y_30fps := size.y - (33.333 / 50.0) * size.y
	_graph_control.draw_line(Vector2(0, y_30fps), Vector2(size.x, y_30fps), Color(0.8, 0.3, 0.2, 0.35), 1.0)

	if _history.size() < 2:
		return

	# Dibujar barras verticales de cada fotograma (verde = rapido, amarillo = medio, rojo = tiron/spike)
	var bar_w := size.x / float(HISTORY_SIZE)
	var max_scale_ms := 50.0 # 50 ms en el tope superior de la grafica (20 FPS)

	for i in range(_history.size()):
		var t_ms: float = _history[i]
		var norm_h := clampf(t_ms / max_scale_ms, 0.0, 1.0)
		var h := norm_h * size.y
		var x := float(i) * bar_w
		var y := size.y - h

		var col := Color(0.25, 0.88, 0.38, 0.85) # Verde < 18ms
		if t_ms > 28.0:
			col = Color(0.95, 0.25, 0.25, 0.95) # Rojo > 28ms (Spike evidente)
		elif t_ms > 18.0:
			col = Color(0.95, 0.80, 0.20, 0.85) # Amarillo 18-28ms

		_graph_control.draw_rect(Rect2(x, y, maxf(bar_w - 0.5, 1.0), h), col, true)
