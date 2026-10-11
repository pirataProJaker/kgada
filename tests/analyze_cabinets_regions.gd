extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	if img == null:
		quit(1)
		return
	
	var w := img.get_width()
	var h := img.get_height()
	
	# Find exact bounds of granite in top area (y < 90)
	var g_min_x := 999
	var g_max_x := -1
	var g_min_y := 999
	var g_max_y := -1
	
	for y in range(0, 92):
		for x in range(0, w):
			var col: Color = img.get_pixel(x, y)
			# Granite has color around (0.7, 0.65, 0.55) or darker speckled, but NOT pure white (1,1,1) and NOT flat grey (0.5, 0.5, 0.5)
			var is_white: bool = (col.r > 0.98 and col.g > 0.98 and col.b > 0.98)
			var is_flat_grey: bool = (abs(col.r - 0.5) < 0.02 and abs(col.g - 0.5) < 0.02 and abs(col.b - 0.5) < 0.02)
			if not is_white and not is_flat_grey:
				g_min_x = mini(g_min_x, x)
				g_max_x = maxi(g_max_x, x)
				g_min_y = mini(g_min_y, y)
				g_max_y = maxi(g_max_y, y)

	print("Granite bounding box: x=[%d..%d], y=[%d..%d]" % [g_min_x, g_max_x, g_min_y, g_max_y])
	print("In UV coordinates (normalized):")
	print("min: (%f, %f)" % [float(g_min_x) / float(w), float(g_min_y) / float(h)])
	print("max: (%f, %f)" % [float(g_max_x) / float(w), float(g_max_y) / float(h)])
	print("size: (%f, %f)" % [float(g_max_x - g_min_x) / float(w), float(g_max_y - g_min_y) / float(h)])
	
	# Let's check columns 0 to 40 at y=40
	print("\nSample pixels along y=40 from x=0 to 35:")
	for x in range(0, 36):
		var c: Color = img.get_pixel(x, 40)
		print("x=%2d: (%.3f, %.3f, %.3f)" % [x, c.r, c.g, c.b])
		
	# Let's check other areas:
	# Wood area: bottom left (x < 90, y > 90)
	var w_min_x := 999
	var w_max_x := -1
	var w_min_y := 999
	var w_max_y := -1
	for y in range(90, h):
		for x in range(0, 95):
			var col: Color = img.get_pixel(x, y)
			if col.r > 0.75 and col.g > 0.60: # warm wood
				w_min_x = mini(w_min_x, x)
				w_max_x = maxi(w_max_x, x)
				w_min_y = mini(w_min_y, y)
				w_max_y = maxi(w_max_y, y)
	print("\nWood bounding box: x=[%d..%d], y=[%d..%d]" % [w_min_x, w_max_x, w_min_y, w_max_y])
	print("Wood UV: rect = Rect2(%f, %f, %f, %f)" % [
		float(w_min_x)/float(w), float(w_min_y)/float(h),
		float(w_max_x - w_min_x)/float(w), float(w_max_y - w_min_y)/float(h)
	])

	quit(0)
