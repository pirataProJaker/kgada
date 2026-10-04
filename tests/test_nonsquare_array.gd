extends SceneTree

func _init() -> void:
	var images: Array[Image] = []
	for i in range(20):
		var img := Image.create(512, 350, false, Image.FORMAT_RGBA8)
		img.fill(Color(float(i) / 20.0, 0.5, 0.5, 1.0))
		images.append(img)
	var arr := Texture2DArray.new()
	var err := arr.create_from_images(images)
	print("Texture2DArray con dimensiones rectangulares (512x350): err = %d, size = %dx%d, layers = %d" % [
		err, arr.get_width(), arr.get_height(), arr.get_layers()
	])
	quit(0)
