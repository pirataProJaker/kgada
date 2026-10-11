extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/washer.png")
	var w := img.get_width()
	var h := img.get_height()
	print("washer.png %dx%d" % [w, h])
	
	for y in range(0, h, 8):
		var line := ""
		for x in range(0, w, 4):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.95 and c.g > 0.95 and c.b > 0.95:
				line += "." # white
			elif c.r < 0.2 and c.g < 0.2 and c.b < 0.2:
				line += "#" # dark
			elif abs(c.r - 0.5) < 0.05:
				line += "-" # grey
			else:
				line += "o"
		print("%3d: %s" % [y, line])
	quit(0)
