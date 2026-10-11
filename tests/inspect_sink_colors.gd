extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	print("Checking sink pixels in cabinets.png (x=164..255, y=160..254):")
	for y in range(165, 235, 10):
		var line := ""
		for x in range(165, 255, 6):
			var c: Color = img.get_pixel(x, y)
			line += "(%.1f,%.1f,%.1f) " % [c.r, c.g, c.b]
		print("y=%d: %s" % [y, line])
	quit(0)
