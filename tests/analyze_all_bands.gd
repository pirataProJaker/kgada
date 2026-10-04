extends SceneTree

func _init() -> void:
	var files = [
		"pared_desgastada2.png",
		"pared_desgastada3.png",
		"pared_desgastada4.png",
		"pared_desgastada5.png",
		"pared_desgastada6.png",
		"pared_desgastada7.png",
		"pintura_desgastada.png"
	]
	
	for file_name in files:
		var path = "res://assets/textures/house/" + file_name
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var w = img.get_width()
		var h = img.get_height()
		
		# Let's count pixels by luminance bands:
		# < 0.50 (dark cracks & deep shadows)
		# 0.50 - 0.85 (concrete, plaster, shadows)
		# 0.85 - 0.95 (light grey paint / flake)
		# 0.95 - 0.985 (gris casi blanco)
		# >= 0.985 (pure/near-pure white)
		var c_dark = 0
		var c_mid = 0
		var c_light = 0
		var c_almost_white = 0
		var c_white = 0
		
		for y in range(h):
			for x in range(w):
				var p = img.get_pixel(x, y)
				var l = (p.r + p.g + p.b) / 3.0
				if l < 0.50:
					c_dark += 1
				elif l < 0.85:
					c_mid += 1
				elif l < 0.95:
					c_light += 1
				elif l < 0.985:
					c_almost_white += 1
				else:
					c_white += 1
					
		print("%s (%dx%d = %d px):" % [file_name, w, h, w*h])
		print("  Dark (<0.50): %d (%.1f%%)" % [c_dark, c_dark * 100.0 / (w*h)])
		print("  Mid (0.50-0.85): %d (%.1f%%)" % [c_mid, c_mid * 100.0 / (w*h)])
		print("  Light (0.85-0.95): %d (%.1f%%)" % [c_light, c_light * 100.0 / (w*h)])
		print("  Gris casi blanco (0.95-0.985): %d (%.1f%%)" % [c_almost_white, c_almost_white * 100.0 / (w*h)])
		print("  White (>=0.985): %d (%.1f%%)" % [c_white, c_white * 100.0 / (w*h)])

	quit(0)
