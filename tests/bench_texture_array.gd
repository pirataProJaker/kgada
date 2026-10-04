extends SceneTree

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var images: Array[Image] = []
	for i in range(35):
		var img := Image.create(1024, 1024, true, Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		images.append(img)
	var arr := Texture2DArray.new()
	arr.create_from_images(images)
	var dt := Time.get_ticks_msec() - t0
	print("Tiempo para Texture2DArray con 35 capas de 1024x1024: %d ms" % dt)
	quit(0)
