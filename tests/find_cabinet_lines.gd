extends SceneTree

func _init() -> void:
	var c := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/cabinets.png"))

	print("--- BORDES EN CABINETS.PNG ---")
	for y in range(90, 256):
		var min_b := 1.0
		var min_x := -1
		for x in range(89, 160):
			var lum := c.get_pixel(x, y).get_luminance()
			if lum < min_b:
				min_b = lum
				min_x = x
		if min_b < 0.25:
			print("Borde horizontal en Y=", y, " (min lum=", snappedf(min_b, 0.01), " en X=", min_x, ")")

	quit(0)
