extends RefCounted

const MAP_LIBRARY_FOLDER := "map_editor_maps"
const MAP_LIBRARY_DIRECTORY := "user://" + MAP_LIBRARY_FOLDER
const MAP_FILE_PREFIX := "map_"


static func get_saved_map_paths() -> Array[String]:
	_ensure_map_directory()
	var directory := DirAccess.open(MAP_LIBRARY_DIRECTORY)
	var paths: Array[String] = []
	if directory == null:
		return paths
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.get_extension().to_lower() == "json":
			paths.append("%s/%s" % [MAP_LIBRARY_DIRECTORY, filename])
		filename = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths


static func next_map_path() -> String:
	_ensure_map_directory()
	var map_number := 1
	var candidate := "%s/%s%03d.json" % [MAP_LIBRARY_DIRECTORY, MAP_FILE_PREFIX, map_number]
	while FileAccess.file_exists(candidate):
		map_number += 1
		candidate = "%s/%s%03d.json" % [MAP_LIBRARY_DIRECTORY, MAP_FILE_PREFIX, map_number]
	return candidate


static func _ensure_map_directory() -> void:
	var directory := DirAccess.open("user://")
	if directory == null or directory.dir_exists(MAP_LIBRARY_FOLDER):
		return
	directory.make_dir(MAP_LIBRARY_FOLDER)