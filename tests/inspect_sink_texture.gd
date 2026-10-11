extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	var w := img.get_width()
	var h := img.get_height()
	
	print("Inspecting sink area (x=160..255, y=90..255):")
	for y in range(95, 255, 12):
		var line := ""
		for x in range(160, 256, 4):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.95 and c.g > 0.95 and c.b > 0.95:
				line += ".."
			elif c.r < 0.2 and c.g < 0.2 and c.b < 0.2:
				line += "##"
			elif abs(c.r - 0.5) < 0.03 and abs(c.g - 0.5) < 0.03:
				line += "--"
			elif c.r > 0.6:
				line += "++"
			else:
				line += "xx"
		print("y=%3d: %s" % [y, line])
	quit(0)
