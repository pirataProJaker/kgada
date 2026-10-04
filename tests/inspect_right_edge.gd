extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Let's inspect the perimeter of the right flap:
	# It goes from top (x=120..155, y=30..60) to bottom (y=80..110)
	print("Checking right edge of desgastada4:")
	for y in range(40, 90, 5):
		var min_l = 1.0
		var min_x = -1
		for x in range(120, w):
			var p = img.get_pixel(x, y)
			var l = (p.r + p.g + p.b) / 3.0
			if l < min_l:
				min_l = l
				min_x = x
		print("y=%2d: min_lum=%.3f at x=%d (byte %d)" % [y, min_l, min_x, int(min_l*255)])
		
	quit(0)
