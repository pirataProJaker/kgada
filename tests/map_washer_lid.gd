@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/washer.png")
	print("--- MAP OF WASHER.PNG ROWS 36..68 ---")
	for y in range(36, 68):
		var line := ""
		for x in range(48, 86):
			var c: Color = img.get_pixel(x, y)
			if c.r < 0.25:
				line += "#"
			elif c.r < 0.8:
				line += "+"
			elif c.r < 0.98:
				line += "-"
			else:
				line += "."
		print("%2d: %s" % [y, line])
	quit(0)
