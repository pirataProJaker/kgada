@tool
extends SceneTree

func _init() -> void:
	for name in ["washer", "dryer"]:
		var img := Image.load_from_file("res://assets/textures/furniture/%s.png" % name)
		print("==========================================")
		print("DUMP OF %s.png (128x128)" % name)
		print("==========================================")
		
		# Let's inspect rows 30..115 where interesting features are
		for y in range(35, 115, 2):
			var has_dark := false
			var min_dark := 999
			var max_dark := -1
			for x in range(128):
				var p: Color = img.get_pixel(x, y)
				if p.r < 0.4 and p.g < 0.4 and p.b < 0.4:
					has_dark = true
					min_dark = min(min_dark, x)
					max_dark = max(max_dark, x)
			if has_dark:
				print("  y=%3d: dark x in [%3d..%3d], width=%2d" % [y, min_dark, max_dark, max_dark - min_dark + 1])
	quit(0)
