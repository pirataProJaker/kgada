extends SceneTree

func _init() -> void:
	var dir_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded"
	var files: Array[String] = [
		"media_1789516456991.jpg",
		"media_1789516457251.jpg",
		"media_1789516457298.jpg"
	]
	
	for fname in files:
		var full_path: String = dir_path + "/" + fname
		var img: Image = Image.load_from_file(full_path)
		if img != null:
			print("FILE: ", fname, " -> SIZE: ", img.get_width(), "x", img.get_height())
			# Calculate average luminance to identify birch (which is mostly white/high lum)
			var sum_lum: float = 0.0
			for y in range(0, img.get_height(), 10):
				for x in range(0, img.get_width(), 10):
					var p: Color = img.get_pixel(x, y)
					sum_lum += (p.r + p.g + p.b) / 3.0
			var avg_lum: float = sum_lum / float((img.get_height() / 10) * (img.get_width() / 10))
			print("   Avg luminance: ", avg_lum)
	
	quit()
