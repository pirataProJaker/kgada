extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	
	for y in range(85, 120, 3):
		var min_l = 1.0
		var min_x = -1
		for x in range(90, w):
			var p = img.get_pixel(x, y)
			var l = (p.r + p.g + p.b) / 3.0
			if l < min_l:
				min_l = l
				min_x = x
		print("y=%2d: min_lum=%.3f at x=%d (byte %d)" % [y, min_l, min_x, int(min_l*255)])
		
	quit(0)
