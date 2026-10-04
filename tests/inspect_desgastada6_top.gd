extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada6.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	print("Size of desgastada6: %dx%d" % [w, h])
	
	# Let's inspect along rows from top (y=0 to y=50) to see what the values are
	for y in range(0, 50, 5):
		var min_l = 1.0
		var max_l = 0.0
		var min_x = -1
		for x in range(w):
			var p = img.get_pixel(x, y)
			var l = (p.r + p.g + p.b) / 3.0
			if l < min_l:
				min_l = l
				min_x = x
			if l > max_l:
				max_l = l
		print("y=%2d: min_lum=%.3f at x=%d, max_lum=%.3f" % [y, min_l, min_x, max_l])
		
	quit(0)
