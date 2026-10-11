extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	var w := img.get_width()
	var h := img.get_height()
	
	for y in range(0, 90, 5):
		var min_non_white := -1
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			if not (c.r > 0.98 and c.g > 0.98 and c.b > 0.98):
				min_non_white = x
				break
		print("y=%2d: first non-white x = %d" % [y, min_non_white])
		
	# Now let's check the right boundary of the granite:
	for y in range(10, 80, 10):
		var max_granite_x := -1
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			# Granite has color variation; the right area is flat grey (0.5)
			if abs(c.r - 0.5) < 0.02 and abs(c.g - 0.5) < 0.02 and abs(c.b - 0.5) < 0.02:
				max_granite_x = x
				break
		print("y=%2d: grey starts at x = %d" % [y, max_granite_x])

	quit(0)
