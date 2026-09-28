extends SceneTree

func _init():
	for idx in [1, 2]:
		var img = Image.load_from_file("res://assets/vegetation/alnus/alnus_full_bough_%d.png" % idx)
		var w = img.get_width()
		var h = img.get_height()
		print("Image ", idx, ": ", w, "x", h)
		
		var min_x = w
		var max_x = 0
		var min_y = h
		var max_y = 0
		
		for x in range(w):
			for y in range(h):
				var a = img.get_pixel(x, y).a
				if a > 0.3:
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y
		
		print("  BBox: x=[%d, %d], y=[%d, %d]" % [min_x, max_x, min_y, max_y])
		
		var sum_y = 0.0
		var count = 0
		for x in range(min_x, min_x + 15):
			for y in range(min_y, max_y + 1):
				if img.get_pixel(x, y).a > 0.5:
					sum_y += y
					count += 1
		var avg_base_y = sum_y / max(count, 1)
		print("  Leftmost base center Y: ", avg_base_y, " (rel y: ", avg_base_y / h, ", rel x: ", float(min_x) / w, ")")
		
		var sum_tip_y = 0.0
		var tip_count = 0
		for x in range(max_x - 20, max_x + 1):
			for y in range(min_y, max_y + 1):
				if img.get_pixel(x, y).a > 0.5:
					sum_tip_y += y
					tip_count += 1
		var avg_tip_y = sum_tip_y / max(tip_count, 1)
		print("  Rightmost tip center Y: ", avg_tip_y, " (rel y: ", avg_tip_y / h, ", rel x: ", float(max_x) / w, ")")
	quit(0)
