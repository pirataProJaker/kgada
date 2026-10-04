extends SceneTree

func _init() -> void:
	var src_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790641186806.png"
	var img := Image.load_from_file(src_path)
	if img == null or img.is_empty():
		printerr("Error al cargar imagen")
		quit(1)
		return
	
	DirAccess.make_dir_recursive_absolute("res://assets/building/doors")
	img.save_png("res://assets/building/doors_atlas.png")
	print("✓ Atlas guardado en res://assets/building/doors_atlas.png (128x128)")

	# Extraer las 8 puertas de 32x64
	for row in range(2):
		for col in range(4):
			var idx := row * 4 + col
			var sub_img := Image.create(32, 64, false, img.get_format())
			sub_img.blit_rect(img, Rect2i(col * 32, row * 64, 32, 64), Vector2i.ZERO)
			var out_path := "res://assets/building/doors/door_%d.png" % idx
			sub_img.save_png(out_path)
			print("✓ Guardada puerta %d: %s" % [idx, out_path])
	
	# Actualizar wood_door.png con la puerta 5 (madera estándar clásica)
	var default_door := Image.create(32, 64, false, img.get_format())
	default_door.blit_rect(img, Rect2i(32, 64, 32, 64), Vector2i.ZERO)
	default_door.save_png("res://assets/building/wood_door.png")
	print("✓ Actualizado res://assets/building/wood_door.png")

	quit(0)
