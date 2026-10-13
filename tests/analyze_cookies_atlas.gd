extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	if not img:
		print("ERROR: could not load image")
		quit(1)
		return

	var w: int = img.get_width()
	var h: int = img.get_height()
	print("Cookie atlas size: ", w, "x", h, " format: ", img.get_format())

	# Horizontal scan for row separation
	print("--- Horizontal scan (Y rows) ---")
	for y in range(0, h, 10):
		var sum_lum: float = 0.0
		for x in range(w):
			sum_lum += img.get_pixel(x, y).get_luminance()
		var avg := sum_lum / float(w)
		if avg < 0.05:
			print("Dark line Y=", y, " avg_lum=", avg)

	quit(0)
