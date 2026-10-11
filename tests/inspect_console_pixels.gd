@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/washer.png")
	print("--- WASHER CONSOLE PIXELS ---")
	for y in range(24, 38):
		var row := ""
		for x in range(48, 86):
			var p: Color = img.get_pixel(x, y)
			if p.r > 0.9 and p.g > 0.9 and p.b > 0.9:
				row += "."
			elif p.b > 0.8 and p.r < 0.2:
				row += "B"
			elif p.r < 0.3 and p.g < 0.3 and p.b < 0.3:
				row += "#"
			else:
				row += "x"
		print("y=%2d: %s" % [y, row])
	quit(0)
