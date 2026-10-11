class_name ObjectRecipeBase
extends RefCounted

## Clase Base Oficial para "Recetas" de Objetos, Muebles y Props (Play Sector X)
## Cualquier mueble nuevo debe heredar de esta clase y definir su composición geométrica
## mediante llamadas a 'builder.add_box()', 'builder.add_cylinder()', etc.
## Garantiza que ningún mueble nuevo añada draw calls al juego (+0 Draw Calls por diseño).

## Construye el objeto agregando sus primitivas al builder proporcionado
static func build(builder: Variant, base_transform: Transform3D, params: Dictionary = {}) -> void:
	# Las clases hijas deben sobrescribir este método
	push_error("ObjectRecipeBase: El método build() debe ser implementado por la receta concreta.")


## Retorna información descriptiva del objeto (dimensiones estándar, categoría, etc.)
static func get_metadata() -> Dictionary:
	return {
		"name": "Unnamed Object",
		"category": "misc",
		"dimensions": Vector3(1.0, 1.0, 1.0)
	}
