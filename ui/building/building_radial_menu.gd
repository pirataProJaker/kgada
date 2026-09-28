extends Control
class_name BuildingRadialMenu
## Rueda Selectora Radial de Construcción Modular.
## Soporta hasta 8 sectores configurables, cálculo angular dinámico del ratón,
## visualización central de detalles/descuentos y botón inferior "Más..."
## para abrir el catálogo completo de recetas.

signal element_selected(element_type: int, material_type: int, recipe_name: String)
signal catalog_requested

@export var radius: float = 160.0
@export var inner_radius: float = 55.0
@export var center_color: Color = Color(0.12, 0.12, 0.14, 0.88)
@export var sector_color: Color = Color(0.18, 0.18, 0.22, 0.82)
@export var sector_hover_color: Color = Color(0.85, 0.55, 0.20, 0.92)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.25)

var slots: Array[Dictionary] = [
	{"name": "Piso", "icon": "🟫", "type": 0, "desc": "Losa horizontal modular (mínimo 1x1m)"},
	{"name": "Pared", "icon": "🧱", "type": 1, "desc": "Muro vertical modular (mínimo 1x1m)"},
	{"name": "Techo", "icon": "🏠", "type": 2, "desc": "Cubierta o techo superior"},
	{"name": "Puerta", "icon": "🚪", "type": 3, "desc": "Vano para marco de puerta"},
	{"name": "Ventana", "icon": "🪟", "type": 4, "desc": "Vano para marco de ventana"},
	{"name": "Demoler", "icon": "🔨", "type": -1, "desc": "Elimina la estructura seleccionada"}
]

var hovered_index: int = -1
var active_tool_name: String = "Palo de Trazado"
var active_savings_pct: int = 0

@onready var title_label: Label = $CenterPanel/TitleLabel
@onready var desc_label: Label = $CenterPanel/DescLabel
@onready var tool_label: Label = $CenterPanel/ToolLabel
@onready var more_button: Button = $MoreButton

func _ready() -> void:
	visible = false
	if more_button:
		more_button.visible = false

func open_menu(tool_info: Dictionary) -> void:
	active_tool_name = tool_info.get("name", "Palo de Trazado")
	var savings: float = tool_info.get("material_savings", 0.0)
	active_savings_pct = int(savings * 100.0)

	if tool_label:
		tool_label.text = "Herramienta: %s\n(Ahorro: %d%%)" % [active_tool_name, active_savings_pct]

	hovered_index = -1
	_update_center_labels()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()

func close_menu() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		_process_mouse_hover(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if hovered_index >= 0 and hovered_index < slots.size():
				_confirm_selection(hovered_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			# Al soltar clic derecho, si hay un sector seleccionado, se confirma
			if hovered_index >= 0 and hovered_index < slots.size():
				_confirm_selection(hovered_index)
			else:
				close_menu()

func _process_mouse_hover(mouse_pos: Vector2) -> void:
	var center := size * 0.5
	var diff := mouse_pos - center
	var dist := diff.length()

	if dist >= inner_radius and dist <= radius + 25.0:
		var angle := diff.angle() # [-PI, PI]
		if angle < 0:
			angle += TAU
		var sector_step := TAU / float(slots.size())
		# Desplazar medio sector para que el índice 0 quede centrado arriba o a la derecha
		var shifted_angle := fmod(angle + sector_step * 0.5, TAU)
		var new_idx := int(shifted_angle / sector_step) % slots.size()
		if new_idx != hovered_index:
			hovered_index = new_idx
			_update_center_labels()
			queue_redraw()
	else:
		if hovered_index != -1:
			hovered_index = -1
			_update_center_labels()
			queue_redraw()

func _update_center_labels() -> void:
	if not title_label or not desc_label:
		return
	if hovered_index >= 0 and hovered_index < slots.size():
		var slot: Dictionary = slots[hovered_index]
		title_label.text = "%s %s" % [slot["icon"], slot["name"]]
		desc_label.text = slot["desc"]
	else:
		title_label.text = "Selecciona una opción"
		desc_label.text = "Apunta con el ratón al sector deseado"

func _confirm_selection(idx: int) -> void:
	var slot: Dictionary = slots[idx]
	element_selected.emit(slot["type"], slot.get("mat", 5), slot["name"])
	close_menu()

func _on_more_button_pressed() -> void:
	close_menu()
	catalog_requested.emit()

func _draw() -> void:
	if not visible:
		return

	var center := size * 0.5
	var num_sectors := slots.size()
	var sector_step := TAU / float(num_sectors)

	# Fondo circular general
	draw_circle(center, radius + 8.0, Color(0, 0, 0, 0.45))

	for i in range(num_sectors):
		var start_angle := i * sector_step - sector_step * 0.5
		var end_angle := start_angle + sector_step
		var is_hovered := (i == hovered_index)
		var col := sector_hover_color if is_hovered else sector_color

		_draw_pie_slice(center, inner_radius, radius, start_angle, end_angle, col)

		# Línea divisoria
		var dir := Vector2.from_angle(start_angle)
		draw_line(center + dir * inner_radius, center + dir * radius, border_color, 1.5)

		# Icono o texto del sector
		var mid_angle := start_angle + sector_step * 0.5
		var icon_pos := center + Vector2.from_angle(mid_angle) * ((radius + inner_radius) * 0.5)
		var slot: Dictionary = slots[i]
		var icon_str: String = slot.get("icon", "•")
		var font := ThemeDB.fallback_font
		draw_string(font, icon_pos + Vector2(-10, 8), icon_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)

	# Círculo interior hueco para datos
	draw_circle(center, inner_radius, center_color)
	draw_arc(center, inner_radius, 0, TAU, 32, border_color, 2.0)
	draw_arc(center, radius, 0, TAU, 48, border_color, 2.0)

func _draw_pie_slice(center: Vector2, r_inner: float, r_outer: float, a0: float, a1: float, col: Color) -> void:
	var segments := 12
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()

	for s in range(segments + 1):
		var t := float(s) / float(segments)
		var a: float = lerpf(a0, a1, t)
		pts.append(center + Vector2.from_angle(a) * r_outer)
		colors.append(col)

	for s in range(segments, -1, -1):
		var t := float(s) / float(segments)
		var a: float = lerpf(a0, a1, t)
		pts.append(center + Vector2.from_angle(a) * r_inner)
		colors.append(col)

	draw_polygon(pts, colors)
