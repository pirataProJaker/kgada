extends SceneTree

func _init() -> void:
	for name in ["pared_desgastada2.png", "pared_desgastada4.png", "pared_desgastada6.png", "pared_desgastada7.png", "pintura_desgastada.png"]:
		var path = "res://assets/textures/house/" + name
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var w = img.get_width()
		var h = img.get_height()
		print("=== %s (%dx%d) ===" % [name, w, h])
		# Let's check the border 2 pixels on all 4 sides:
		var border_min_l = 1.0
		var border_max_l = 0.0
		for y in range(h):
			for x in range(w):
				if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
					var p = img.get_pixel(x, y)
					var l = (p.r + p.g + p.b) / 3.0
					border_min_l = minf(border_min_l, l)
					border_max_l = maxf(border_max_l, l)
		print("  Outer 2-pixel border: lum min=%.4f (byte %d), max=%.4f (byte %d)" % [border_min_l, int(border_min_l*255), border_max_l, int(border_max_l*255)])
	quit(0)
