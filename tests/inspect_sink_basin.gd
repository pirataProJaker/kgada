@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	print("cabinets.png: ", img.get_size())
	# Let's inspect sink_basin region Rect2(0.64063, 0.62500, 0.35547, 0.36719)
	# In pixels: x from 0.64063*256 = 164 to 164 + 91 = 255.
	# y from 0.625*256 = 160 to 160 + 94 = 254.
	print("Sampling sink basin area around (164..255, 160..254):")
	for y in range(160, 255, 16):
		var row_str := "y=%3d: " % y
		for x in range(164, 255, 12):
			var col: Color = img.get_pixel(x, y)
			row_str += "(%.2f,%.2f,%.2f) " % [col.r, col.g, col.b]
		print(row_str)
	quit(0)
