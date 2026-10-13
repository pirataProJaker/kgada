extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)

	print("--- Row 0 Pack 1 (Chocolate) Top Y scan ---")
	for y in range(18, 45):
		var sum_lum: float = 0.0
		var num_pixels: int = 0
		for x in range(125, 215):
			var c: Color = img.get_pixel(x, y)
			sum_lum += c.get_luminance()
			num_pixels += 1
		var avg_lum := sum_lum / float(num_pixels)
		print("Y=%3d: avg_lum=%.3f" % [y, avg_lum])

	print("--- Row 1 Pack 1 (Chispas) Top Y scan ---")
	for y in range(330, 360):
		var sum_lum: float = 0.0
		var num_pixels: int = 0
		for x in range(128, 216):
			var c: Color = img.get_pixel(x, y)
			sum_lum += c.get_luminance()
			num_pixels += 1
		var avg_lum := sum_lum / float(num_pixels)
		print("Y=%3d: avg_lum=%.3f" % [y, avg_lum])

	quit(0)
