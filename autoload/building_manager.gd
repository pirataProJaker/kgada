extends Node
## Autoload ("BuildingManager"): Gestor central de construcción modular,
## herramientas de trazado (palo, cuaderno/estacas, plano/cal),
## recetas desbloqueables por libros y cálculo dinámico de ahorro de materiales.

signal recipe_unlocked(recipe_id: String)
signal book_read(book_id: String)

const TOOLS_CONFIG_PATH := "res://content/building/construction_tools.json"
const RECIPES_CONFIG_PATH := "res://content/building/construction_recipes.json"

var tools_data: Dictionary = {}
var recipes_data: Array = []
var unlocked_books: Array[String] = []

func _ready() -> void:
	load_tools_config()
	load_recipes_config()
	print("[BuildingManager] Inicializado con %d herramientas y %d recetas." % [tools_data.size(), recipes_data.size()])

## Carga el archivo JSON de herramientas de construcción.
func load_tools_config() -> void:
	if not FileAccess.file_exists(TOOLS_CONFIG_PATH):
		push_warning("[BuildingManager] No se encontro %s" % TOOLS_CONFIG_PATH)
		return
	var file := FileAccess.open(TOOLS_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json_str := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Dictionary and parsed.has("tools"):
		tools_data = parsed["tools"]

## Carga el archivo JSON de recetas de construcción modular.
func load_recipes_config() -> void:
	if not FileAccess.file_exists(RECIPES_CONFIG_PATH):
		push_warning("[BuildingManager] No se encontro %s" % RECIPES_CONFIG_PATH)
		return
	var file := FileAccess.open(RECIPES_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json_str := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Dictionary and parsed.has("recipes"):
		recipes_data = parsed["recipes"]

## Comprueba si un ObjectDefinition corresponde a una herramienta de construcción válida.
func is_construction_tool(definition: ObjectDefinition) -> bool:
	if definition == null:
		return false
	var item_id := definition.id.to_lower()
	if tools_data.has(item_id):
		return true
	if item_id.contains("stick") or item_id.contains("palo") or item_id.contains("stake") or item_id.contains("cuaderno") or item_id.contains("blueprint") or item_id.contains("plano"):
		return true
	return false

## Obtiene la configuración de una herramienta por su ID o un fallback inteligente.
func get_tool_data(item_id: String) -> Dictionary:
	var clean_id := item_id.to_lower()
	if tools_data.has(clean_id):
		return tools_data[clean_id]
	if clean_id.contains("blueprint") or clean_id.contains("plano"):
		return tools_data.get("blueprint_tool", {})
	if clean_id.contains("stake") or clean_id.contains("cuaderno") or clean_id.contains("libro"):
		return tools_data.get("stake_rope_tool", {})
	# Default: palo de trazado
	return tools_data.get("stick_tool", {})

## Retorna la herramienta actualmente equipada en la mano del jugador local.
func get_equipped_construction_tool(player: Node) -> Dictionary:
	if player == null:
		return {}
	var inv: Inventory = player.get_node_or_null("Inventory")
	if inv == null:
		return {}
	var held_def: ObjectDefinition = inv.get_selected_definition()
	if held_def == null:
		return {}
	if is_construction_tool(held_def):
		return get_tool_data(held_def.id)
	return {}

## Desbloquea un libro de recetas al ser leído por el jugador.
func unlock_book(book_id: String) -> void:
	if not unlocked_books.has(book_id):
		unlocked_books.append(book_id)
		book_read.emit(book_id)
		print("[BuildingManager] ¡Libro desbloqueado con exito!: ", book_id)

## Verifica si una receta está desbloqueada para el jugador.
func is_recipe_unlocked(recipe: Dictionary) -> bool:
	var req_book = recipe.get("requires_book", null)
	if req_book == null or str(req_book).is_empty():
		return true
	return unlocked_books.has(str(req_book))

## Calcula el costo efectivo con el porcentaje de ahorro aplicado según la herramienta.
func calculate_discounted_cost(base_cost: Dictionary, savings: float) -> Dictionary:
	var discounted: Dictionary = {}
	for mat_name in base_cost.keys():
		var original_amount: int = int(base_cost[mat_name])
		var factor: float = max(0.0, 1.0 - savings)
		var final_amount: int = max(1, int(ceil(float(original_amount) * factor)))
		discounted[mat_name] = final_amount
	return discounted

## Devuelve todas las recetas filtradas o categorizadas.
func get_all_recipes() -> Array:
	return recipes_data
