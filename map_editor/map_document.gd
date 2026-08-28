extends RefCounted
class_name MapDocument
## Fuente de verdad serializable del editor de mapas.
## La escena visual se reconstruye desde este documento; no se guarda como .tscn.

const FORMAT_VERSION := 1
const DEFAULT_GRID_SIZE := Vector2i(17, 17)
const DEFAULT_CELL_SIZE := 2.5
const DEFAULT_TERRAIN_HEIGHT := 10.0
const TERRAIN_MODE_FLAT := "flat"

var map_name := "Nuevo mapa"
var world_seed := 1
var terrain_mode := TERRAIN_MODE_FLAT
var grid_size := DEFAULT_GRID_SIZE
var cell_size := DEFAULT_CELL_SIZE
var sea_level := 0.0
var heights := PackedFloat32Array()
var objects: Array[Dictionary] = []


func _init(size: Vector2i = DEFAULT_GRID_SIZE) -> void:
	configure(size)


func configure(size: Vector2i) -> void:
	grid_size = Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	heights.resize(grid_size.x * grid_size.y)
	for index in heights.size():
		heights[index] = DEFAULT_TERRAIN_HEIGHT
	objects.clear()


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func get_height(cell: Vector2i) -> float:
	if not is_valid_cell(cell):
		return sea_level
	return heights[_height_index(cell)]


func set_height(cell: Vector2i, height: float) -> void:
	if not is_valid_cell(cell):
		return
	heights[_height_index(cell)] = height


func to_dictionary() -> Dictionary:
	var serialized_heights: Array = []
	serialized_heights.resize(heights.size())
	for index in heights.size():
		serialized_heights[index] = heights[index]

	return {
		"format_version": FORMAT_VERSION,
		"map_name": map_name,
		"world_seed": world_seed,
		"terrain_mode": terrain_mode,
		"grid_size": [grid_size.x, grid_size.y],
		"cell_size": cell_size,
		"sea_level": sea_level,
		"heights": serialized_heights,
		"objects": objects.duplicate(true),
	}


func save_to_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	file.close()
	return true


static func from_dictionary(data: Dictionary):
	var serialized_size: Variant = data.get("grid_size", [DEFAULT_GRID_SIZE.x, DEFAULT_GRID_SIZE.y])
	var size := DEFAULT_GRID_SIZE
	if serialized_size is Array and serialized_size.size() >= 2:
		size = Vector2i(maxi(int(serialized_size[0]), 1), maxi(int(serialized_size[1]), 1))

	var result := MapDocument.new(size)
	result.map_name = str(data.get("map_name", result.map_name))
	result.world_seed = int(data.get("world_seed", result.world_seed))
	result.terrain_mode = str(data.get("terrain_mode", TERRAIN_MODE_FLAT))
	if result.terrain_mode.is_empty():
		result.terrain_mode = TERRAIN_MODE_FLAT
	result.cell_size = maxf(float(data.get("cell_size", result.cell_size)), 0.1)
	result.sea_level = float(data.get("sea_level", result.sea_level))

	var serialized_heights: Variant = data.get("heights", [])
	if serialized_heights is Array:
		var copy_count := mini(serialized_heights.size(), result.heights.size())
		for index in copy_count:
			result.heights[index] = float(serialized_heights[index])

	var serialized_objects: Variant = data.get("objects", [])
	if serialized_objects is Array:
		for object_variant in serialized_objects:
			if object_variant is Dictionary:
				result.objects.append(object_variant.duplicate(true))
	return result


static func load_from_file(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return null
	return from_dictionary(parsed as Dictionary)


func _height_index(cell: Vector2i) -> int:
	return cell.x + cell.y * grid_size.x
