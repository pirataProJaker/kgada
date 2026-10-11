extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	var w := img.get_width()
	var h := img.get_height()
	
	# Let's inspect rows 0 to 90 at intervals of 10
	print("Inspecting rows 0..90:")
	for y in range(0, 90, 10):
		var line := ""
		for x in range(0, w, 4):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.95 and c.g > 0.95 and c.b > 0.95:
				line += "." # white
			elif abs(c.r - 0.5) < 0.03 and abs(c.g - 0.5) < 0.03 and abs(c.b - 0.5) < 0.03:
				line += "-" # flat grey
			elif c.r > 0.8 and c.g > 0.6:
				line += "W" # wood
			else:
				line += "G" # granite/textured
		print("%2d: %s" % [y, line])
	quit(0)
