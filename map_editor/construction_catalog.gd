extends RefCounted
class_name ConstructionCatalog

const FENCE_DEFINITION_SCRIPT := preload("res://map_editor/fence_construction_definition.gd")

static var _definitions: Dictionary = {}


static func get_categories() -> Array:
	return [
		{"id": "fences", "name": "Vallas"},
		{"id": "walls", "name": "Muros"},
		{"id": "posts", "name": "Postes"},
		{"id": "paths", "name": "Caminos"},
		{"id": "pipes", "name": "Tuberías"},
		{"id": "cables", "name": "Cables"},
		{"id": "railings", "name": "Barandales"},
		{"id": "roofs", "name": "Techos"},
		{"id": "floors", "name": "Pisos"},
	]


static func get_category_name(category_id: String) -> String:
	for category in get_categories():
		if str(category.get("id", "")) == category_id:
			return str(category.get("name", category_id))
	return category_id


static func get_definitions_for_category(category_id: String) -> Array:
	_ensure_definitions()
	var result: Array = []
	for definition in _definitions.values():
		if definition.category_id == category_id:
			result.append(definition)
	return result


static func get_definition(type_id: String) -> ConstructionDefinition:
	_ensure_definitions()
	return _definitions.get(type_id, null)


static func _ensure_definitions() -> void:
	if not _definitions.is_empty():
		return
	var fence_definition := FENCE_DEFINITION_SCRIPT.new()
	_definitions[fence_definition.type_id] = fence_definition
