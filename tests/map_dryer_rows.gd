@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/dryer.png")
	print("--- MAP OF DRYER.PNG ROWS 25..45, COLS 48..86 ---")
	for y in range(25, 45):
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
