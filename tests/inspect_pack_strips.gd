extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()
	var h: int = img.get_height()

	var pack_ranges_r0 := [
		Vector2i(11, 106),
		Vector2i(123, 217),
		Vector2i(235, 328),
		Vector2i(343, 442),
		Vector2i(462, 555),
		Vector2i(573, 666),
		Vector2i(686, 784),
		Vector2i(803, 896),
		Vector2i(918, 1010)
	]

	var pack_ranges_r1 := [
		Vector2i(12, 106),
		Vector2i(127, 218),
		Vector2i(235, 328),
		Vector2i(346, 440),
		Vector2i(459, 552),
		Vector2i(572, 666),
		Vector2i(684, 781),
		Vector2i(802, 894),
		Vector2i(915, 1008)
	]

	# Let's inspect Pack 0 in Row 0
	for r_idx in range(2):
		var p_ranges = pack_ranges_r0 if r_idx == 0 else pack_ranges_r1
		var y_min = 40 if r_idx == 0 else 355
		var y_max = 270 if r_idx == 0 else 590
		print("\n=== ROW ", r_idx, " DETAILED STRIP SCAN ===")
		for p_idx in range(p_ranges.size()):
			var p_range: Vector2i = p_ranges[p_idx]
			# Find Y bounds of this pack
			var actual_y_min: int = y_max
			var actual_y_max: int = y_min
			for y in range(y_min - 10, y_max + 10):
				for x in range(p_range.x, p_range.y + 1):
					var c: Color = img.get_pixel(x, y)
					if c.r > 0.05 or c.g > 0.05 or c.b > 0.05:
						actual_y_min = mini(actual_y_min, y)
						actual_y_max = maxi(actual_y_max, y)
			
			# Inside [p_range.x, p_range.y], there are 3 strips separated by black columns
			var strip_cols: Array[bool] = []
			for x in range(p_range.x, p_range.y + 1):
				var has_c := false
				for y in range(actual_y_min, actual_y_max + 1):
					var c: Color = img.get_pixel(x, y)
					if c.r > 0.05 or c.g > 0.05 or c.b > 0.05:
						has_c = true
						break
				strip_cols.append(has_c)
			
			# Detect strips
			var strips := []
			var in_s := false
			var s_start := 0
			var s_black := 0
			for i in range(strip_cols.size()):
				var x_real = p_range.x + i
				if strip_cols[i]:
					if not in_s:
						in_s = true
						s_start = x_real
					s_black = 0
				else:
					if in_s:
						s_black += 1
						if s_black >= 2 or i == strip_cols.size() - 1:
							in_s = false
							strips.append(Vector2i(s_start, x_real - s_black))
			if in_s:
				strips.append(Vector2i(s_start, p_range.y))
			
			print("Pack ", p_idx, " Y=[", actual_y_min, "..", actual_y_max, "] (H=", actual_y_max - actual_y_min + 1, ") Strips count: ", strips.size())
			for s_i in range(strips.size()):
				var s: Vector2i = strips[s_i]
				print("    Strip ", s_i, ": X=[", s.x, "..", s.y, "] (W=", s.y - s.x + 1, ")")

	quit(0)
