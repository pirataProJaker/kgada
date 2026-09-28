extends SceneTree

func _init() -> void:
	for idx in [1, 2]:
		var img = Image.load_from_file("res://assets/vegetation/alnus/alnus_full_bough_%d.png" % idx)
		var w = img.get_width()
		var h = img.get_height()
		# Check leftmost edge (x = 0 to 10)
		print("--- Image ", idx, " Leftmost pixels ---")
		for x in range(0, 15):
			var opaque_count = 0
			var avg_r = 0.0
			var avg_g = 0.0
			var avg_b = 0.0
			var y_min = h
			var y_max = 0
			for y in range(h):
				var c = img.get_pixel(x, y)
				if c.a > 0.5:
					opaque_count += 1
					avg_r += c.r
					avg_g += c.g
					avg_b += c.b
					if y < y_min: y_min = y
					if y > y_max: y_max = y
			if opaque_count > 0:
				print("x=%d: %d pixels, y=[%d, %d], rgb=(%.2f, %.2f, %.2f)" % [x, opaque_count, y_min, y_max, avg_r/opaque_count, avg_g/opaque_count, avg_b/opaque_count])
	quit(0)
