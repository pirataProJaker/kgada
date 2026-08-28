extends Node
## Autoload ("ObjectRegistry"): escanea TODOS los .tres de ObjectDefinition
## que existen -- tanto los que vienen con el juego (res://content/objects/)
## como los que un jugador cualquiera creo sin programar desde el editor de
## contenido (user://custom_objects/) -- y arma un registro id -> definicion.
##
## Esto es lo que hace que "/give <objeto>" y el sistema de colocacion
## (fantasma) sean universales: no hay una lista fija de objetos en el
## codigo, cualquier .tres nuevo aparece solo la proxima vez que se escanea.

var _definitions: Dictionary = {} # id (String) -> ObjectDefinition


func _ready() -> void:
	refresh()


## Vuelve a escanear ambas carpetas. Se llama automaticamente al iniciar y
## despues de guardar un objeto nuevo desde el editor de contenido, para que
## quede disponible al instante sin reiniciar el juego.
func refresh() -> void:
	_definitions.clear()
	_scan_directory("res://content/objects")
	_scan_directory("user://custom_objects")


func _scan_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			_try_register(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _try_register(resource_path: String) -> void:
	var res := load(resource_path)
	if res is ObjectDefinition and not res.id.is_empty():
		_definitions[res.id] = res


func get_all() -> Array:
	return _definitions.values()


func get_by_id(id: String) -> ObjectDefinition:
	return _definitions.get(id)


## Busca un objeto por id exacto ("core/basic_chest"), por el ultimo
## segmento del id ("basic_chest"), o por display_name (contiene, sin
## importar mayusculas) - asi "/give cofre" o "/give basic_chest" o
## "/give core/basic_chest" funcionan igual de bien.
func find(query: String) -> ObjectDefinition:
	if query.is_empty():
		return null
	var lower_query := query.to_lower()

	if _definitions.has(query):
		return _definitions[query]

	for def in _definitions.values():
		if def.id.to_lower() == lower_query:
			return def
	for def in _definitions.values():
		var short_id: String = def.id.get_file() if def.id.contains("/") else def.id
		if short_id.to_lower() == lower_query:
			return def
	for def in _definitions.values():
		if def.display_name.to_lower() == lower_query:
			return def
	for def in _definitions.values():
		if def.display_name.to_lower().contains(lower_query):
			return def
	return null
