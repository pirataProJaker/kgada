extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://assets/textures/military")
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("military_tile_") and fname.ends_with(".png"):
			files.append("res://assets/textures/military/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()

	print("Archivos encontrados: ", files.size())
	var images: Array[Image] = []
	for p in files:
		var img := Image.load_from_file(p)
		if img:
			img.convert(Image.FORMAT_RGBA8)
			img.resize(256, 256, Image.INTERPOLATE_NEAREST)
			img.generate_mipmaps()
			images.append(img)
			print("Cargada: ", p.get_file())

	var tex_arr := Texture2DArray.new()
	var err := tex_arr.create_from_images(images)
	print("Texture2DArray creado: err=", err, " capas=", tex_arr.get_layers(), " dim=", tex_arr.get_width(), "x", tex_arr.get_height())
	quit(0)
