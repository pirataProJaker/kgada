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
		var w: int = img.get_width()
		var h: int = img.get_height()
		
		var min_x: int = w
		var max_x: int = 0
		var min_y: int = h
		var max_y: int = 0
		
		for y in range(h):
			for x in range(w):
				var p: Color = img.get_pixel(x, y)
				var lum: float = maxf(p.r, maxf(p.g, p.b))
				if lum > 0.05:
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y
		
		print("FILE: ", fname, " (", w, "x", h, ")")
		print("   BBox: X=[", min_x, ", ", max_x, "] (span ", max_x - min_x, "), Y=[", min_y, ", ", max_y, "] (span ", max_y - min_y, ")")
	
	quit()
