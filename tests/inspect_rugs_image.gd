extends SceneTree

func _init() -> void:
	var path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.user_uploaded/media_1790967656197.jpg"
	var img := Image.load_from_file(path)
	if not img:
		print("ERROR cargando imagen")
		quit(1)
		return
	print("IMAGE LOADED: size = %dx%d, format = %d" % [img.get_width(), img.get_height(), img.get_format()])
	quit(0)
