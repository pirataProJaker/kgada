extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://assets/textures/military/")
	var files: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.begins_with("military_tile_") and f.ends_with(".png"):
				files.append(f)
			f = dir.get_next()
		dir.list_dir_end()
	files.sort()
	for i in range(files.size()):
		print("Index %2d: %s" % [i, files[i]])
	quit(0)
