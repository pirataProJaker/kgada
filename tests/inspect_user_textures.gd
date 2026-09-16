extends SceneTree

func _init() -> void:
	var dir_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded"
	var files: Array[String] = [
		"media_1789514170471.jpg",
		"media_1789514388126.png",
		"media_1789514507768.png"
	]
	
	for fname in files:
		var full_path: String = dir_path + "/" + fname
		var img: Image = Image.load_from_file(full_path)
		if img == null:
			print("FAILED TO LOAD: ", fname)
		else:
			print("FILE: ", fname, " -> SIZE: ", img.get_width(), "x", img.get_height(), " FORMAT: ", img.get_format())
			var p_corner: Color = img.get_pixel(10, 10)
			var p_center: Color = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
			print("   Corner (10,10): ", p_corner, " Center: ", p_center)
	
	quit()
