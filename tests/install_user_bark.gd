@tool
extends SceneTree

func _init() -> void:
	var user_uploaded_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1789516457251.jpg"
	var img := Image.load_from_file(user_uploaded_path)
	if img == null:
		printerr("Error cargando imagen de usuario: ", user_uploaded_path)
		quit(1)
		return
	
	print("Imagen de usuario cargada: ", img.get_size(), " formato: ", img.get_format())
	
	# Guardar en alta calidad en res://assets/vegetation/alnus/alnus_bark.png
	var dest_path := "res://assets/vegetation/alnus/alnus_bark.png"
	var global_dest := ProjectSettings.globalize_path(dest_path)
	var err := img.save_png(global_dest)
	print("Guardado en ", dest_path, " res: ", err)
	
	# También asegurar en assets/textures/foliage/bark_oak.png
	var oak_dest := ProjectSettings.globalize_path("res://assets/textures/foliage/bark_oak.png")
	img.save_png(oak_dest)
	print("Guardado en bark_oak.png")
	
	quit(0)
