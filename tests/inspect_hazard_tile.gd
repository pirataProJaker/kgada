extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://assets/textures/military/")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.begins_with("military_tile_") and fname.ends_with(".png"):
				var img := Image.load_from_file("res://assets/textures/military/" + fname)
				if img:
					print(fname, ": ", img.get_width(), "x", img.get_height())
			fname = dir.get_next()
		dir.list_dir_end()
	quit(0)
