@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/dryer.png")
	print("--- HEX COLORS OF DRYER CONSOLE ROWS 26..35 ---")
	for y in range(26, 36):
		var line := "y=%2d: " % y
		for x in range(49, 85, 2):
			var c: Color = img.get_pixel(x, y)
			line += "%02X%02X " % [int(c.r * 255), int(c.g * 255)]
		print(line)
	quit(0)
