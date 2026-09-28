extends Control
class_name BuildingCatalogMenu
## Ventana Modal de Catálogo Completo de Construcción ("Más...").
## Muestra todas las recetas de construcción en una cuadrícula interactiva,
## indicando si están bloqueadas por falta de lectura de libros y detallando
## el ahorro de materiales en tiempo real según la herramienta equipada.

signal recipe_chosen(element_type: int, material_type: int, recipe_name: String)

@onready var grid_container: GridContainer = $Panel/ScrollContainer/GridContainer
@onready var tool_info_label: Label = $Panel/ToolInfoLabel
@onready var close_button: Button = $Panel/CloseButton

var active_tool_info: Dictionary = {}

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close_catalog)

func open_catalog(tool_info: Dictionary) -> void:
	active_tool_info = tool_info
	var tool_name: String = tool_info.get("name", "Palo de Trazado")
	var savings: float = tool_info.get("material_savings", 0.0)

	if tool_info_label:
		tool_info_label.text = "Herramienta equipada: %s | Descuento activo: %d%%" % [tool_name, int(savings * 100.0)]

	_populate_recipes()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_catalog() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_catalog()

func _populate_recipes() -> void:
	if not grid_container:
		return

	# Limpiar hijos previos
	for child in grid_container.get_children():
		child.queue_free()

	var recipes: Array = BuildingManager.get_all_recipes()
	var savings: float = active_tool_info.get("material_savings", 0.0)

	for recipe in recipes:
		var card := _create_recipe_card(recipe, savings)
		grid_container.add_child(card)

func _create_recipe_card(recipe: Dictionary, savings: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 150)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var is_unlocked: bool = BuildingManager.is_recipe_unlocked(recipe)

	# Nombre de la receta
	var name_label := Label.new()
	name_label.text = recipe.get("name", "Elemento")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)

	# Costos calculados
	var base_cost: Dictionary = recipe.get("base_cost", {})
	var disc_cost: Dictionary = BuildingManager.calculate_discounted_cost(base_cost, savings)

	var cost_text := "Costo: "
	for mat in disc_cost.keys():
		var original: int = base_cost[mat]
		var discounted: int = disc_cost[mat]
		if discounted < original:
			cost_text += "%d %s (era %d), " % [discounted, mat, original]
		else:
			cost_text += "%d %s, " % [discounted, mat]
	cost_text = cost_text.trim_suffix(", ")

	var cost_label := Label.new()
	cost_label.text = cost_text
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5) if savings > 0 else Color(0.8, 0.8, 0.8))
	vbox.add_child(cost_label)

	# Botón de selección o etiqueta de bloqueo
	if is_unlocked:
		var btn := Button.new()
		btn.text = "Seleccionar"
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func():
			recipe_chosen.emit(recipe.get("element_type", 0), recipe.get("material_type", 0), recipe.get("name", ""))
			close_catalog()
		)
		vbox.add_child(btn)
	else:
		var lock_label := Label.new()
		var req_book: String = str(recipe.get("requires_book", "Libro desconocido"))
		lock_label.text = "🔒 Bloqueado\nRequiere: %s" % req_book
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 10)
		lock_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		vbox.add_child(lock_label)

	return panel
