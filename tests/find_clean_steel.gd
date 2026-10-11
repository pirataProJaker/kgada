@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/washer.png")
	print("Searching for clean grey/steel pixels in washer.png:")
	for y in range(0, 128):
		for x in range(0, 128):
			var p: Color = img.get_pixel(x, y)
			# Look for uniform grey (r == g == b, 0.4 < r < 0.75)
			if abs(p.r - p.g) < 0.02 and abs(p.g - p.b) < 0.02 and p.r > 0.4 and p.r < 0.8:
				# Check a 4x4 block
				var ok := true
				for dy in range(4):
					for dx in range(4):
						if x + dx < 128 and y + dy < 128:
							var q: Color = img.get_pixel(x + dx, y + dy)
							if not (abs(q.r - q.g) < 0.03 and abs(q.g - q.b) < 0.03 and q.r > 0.4 and q.r < 0.8):
								ok = false
				if ok and x % 8 == 0 and y % 4 == 0:
					print("  Clean grey block at (%d, %d), color=(%.2f, %.2f, %.2f)" % [x, y, p.r, p.g, p.b])
	quit(0)
