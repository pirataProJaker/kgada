extends SceneTree

func _init() -> void:
	var ct := Image.new()
	ct.load("res://assets/textures/furniture/coffee_table.png")
	
	# Let's inspect the drawer frame in bottom-left:
	# Check where the outer border of the framed panel is:
	var frame_min := Vector2i(128, 128)
	var frame_max := Vector2i(0, 0)
	for y in range(60, 128):
		for x in range(0, 95):
			var c = ct.get_pixel(x, y)
			# Look for the bright or distinct border
			if c.r > 0.4:
				frame_min.x = min(frame_min.x, x)
				frame_min.y = min(frame_min.y, y)
				frame_max.x = max(frame_max.x, x)
				frame_max.y = max(frame_max.y, y)
	print("Drawer frame region: ", frame_min, " to ", frame_max)

	# Check the tabletop plank region in top-left:
	var table_min := Vector2i(128, 128)
	var table_max := Vector2i(0, 0)
	for y in range(0, 80):
		for x in range(0, 95):
			var c = ct.get_pixel(x, y)
			if c.r > 0.4:
				table_min.x = min(table_min.x, x)
				table_min.y = min(table_min.y, y)
				table_max.x = max(table_max.x, x)
				table_max.y = max(table_max.y, y)
	print("Tabletop plank region: ", table_min, " to ", table_max)

	# Check the right side (legs / side panels):
	print("Right side (X: 88..127):")
	for y in range(0, 128, 16):
		print("  Y=%d: c(92)=%s, c(110)=%s, c(124)=%s" % [y, str(ct.get_pixel(92, y)), str(ct.get_pixel(110, y)), str(ct.get_pixel(124, y))])

	quit(0)
