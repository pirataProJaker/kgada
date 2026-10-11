extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	var w := img.get_width()
	var h := img.get_height()
	
	# Let's inspect the entire image in 16x16 blocks
	# and output the dominant feature in each block:
	# Columns: 0 to 15 (each 16 pixels wide)
	# Rows: 0 to 15 (each 16 pixels high)
	print("Grid of 16x16 blocks in cabinets.png (256x256):")
	print("      c0  c1  c2  c3  c4  c5  c6  c7  c8  c9  c10 c11 c12 c13 c14 c15")
	for by in range(16):
		var row_str := "r%2d: " % by
		for bx in range(16):
			var x := bx * 16 + 8
			var y := by * 16 + 8
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.95 and c.g > 0.95 and c.b > 0.95:
				row_str += " .  " # white
			elif abs(c.r - 0.5) < 0.03 and abs(c.g - 0.5) < 0.03 and abs(c.b - 0.5) < 0.03:
				row_str += "gry " # grey
			elif c.r > 0.75 and c.g > 0.60 and c.b < 0.60:
				row_str += "wod " # wood
			elif c.r > 0.6 and c.g > 0.55 and c.b > 0.45:
				row_str += "grn " # granite
			elif c.r < 0.2 and c.g < 0.2 and c.b < 0.2:
				row_str += "drk " # dark
			else:
				row_str += "oth "
		print(row_str)
		
	# Let's inspect the drawer (y between 90 and 120, x between 85 and 165)
	# and door (y between 115 and 220, x between 85 and 165)
	print("\nInspecting columns around x=88..165 at y=100 (drawer):")
	for x in range(80, 170, 4):
		var c := img.get_pixel(x, 105)
		print("x=%d: (%.2f, %.2f, %.2f)" % [x, c.r, c.g, c.b])

	print("\nInspecting columns around x=88..165 at y=160 (door):")
	for x in range(80, 170, 4):
		var c := img.get_pixel(x, 160)
		print("x=%d: (%.2f, %.2f, %.2f)" % [x, c.r, c.g, c.b])

	print("\nInspecting rows around y=90..255 at x=125 (vertical slice of drawer & door):")
	for y in range(85, 256, 5):
		var c := img.get_pixel(125, y)
		print("y=%d: (%.2f, %.2f, %.2f)" % [y, c.r, c.g, c.b])

	quit(0)
