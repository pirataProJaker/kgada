extends SceneTree

func _init() -> void:
	var img = Image.load_from_file("assets/textures/furniture/furniture_props_atlas.png")
	var step_y = 16
	var step_x = 16
	for y in range(0, img.get_height(), step_y):
		var line = ""
		var has_content = false
		for x in range(0, img.get_width(), step_x):
			var px = img.get_pixel(x, y)
			if px.r > 0.05 or px.g > 0.05 or px.b > 0.05:
				line += "#"
				has_content = true
			else:
				line += "."
		if has_content or y % 64 == 0:
			print("Y=%3d: %s" % [y, line])
	quit(0)
