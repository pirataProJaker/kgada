extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/snack_bags_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()
	var h: int = img.get_height()

	var rows_y := [
		Vector2i(13, 172),
		Vector2i(184, 336),
		Vector2i(349, 502),
		Vector2i(516, 667)
	]

	var col_x_approx := [
		Vector2i(19, 200),
		Vector2i(224, 398),
		Vector2i(424, 599),
		Vector2i(625, 800),
		Vector2i(825, 1004)
	]

	for r_idx in range(4):
		var ry: Vector2i = rows_y[r_idx]
		print("\n--- Scanning Row %d (Y=[%d..%d]) ---" % [r_idx, ry.x, ry.y])
		for c_idx in range(5):
			var cx_approx: Vector2i = col_x_approx[c_idx]

			# Find exact X bounds
			var actual_x_min := cx_approx.y
			var actual_x_max := cx_approx.x
			var actual_y_min := ry.y
			var actual_y_max := ry.x

			for y in range(ry.x - 4, ry.y + 5):
				for x in range(cx_approx.x - 6, cx_approx.y + 6):
					if x >= 0 and x < w and y >= 0 and y < h:
						var c: Color = img.get_pixel(x, y)
						if c.r > 0.04 or c.g > 0.04 or c.b > 0.04:
							actual_x_min = mini(actual_x_min, x)
							actual_x_max = maxi(actual_x_max, x)
							actual_y_min = mini(actual_y_min, y)
							actual_y_max = maxi(actual_y_max, y)

			# Now find split point between front bag and lateral strip
			# Inside [actual_x_min, actual_x_max], look for vertical seam
			var best_split := actual_x_max - 30
			var min_lum := 999.0
			for x in range(actual_x_max - 44, actual_x_max - 18):
				var sum_l: float = 0.0
				for y in range(actual_y_min, actual_y_max + 1):
					sum_l += img.get_pixel(x, y).get_luminance()
				var avg_l := sum_l / float(actual_y_max - actual_y_min + 1)
				if avg_l < min_lum:
					min_lum = avg_l
					best_split = x

			var fx_start := actual_x_min
			var fx_end := best_split
			var sx_start := best_split + 1
			var sx_end := actual_x_max

			print("  Bag [%d, %d]: Y=[%d..%d](H=%d) Front=[%d..%d](W=%d) Side=[%d..%d](W=%d)" % [
				r_idx, c_idx,
				actual_y_min, actual_y_max, actual_y_max - actual_y_min + 1,
				fx_start, fx_end, fx_end - fx_start + 1,
				sx_start, sx_end, sx_end - sx_start + 1
			])

	quit(0)
