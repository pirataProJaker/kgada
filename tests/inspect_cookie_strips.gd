extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()
	var h: int = img.get_height()

	# Row 0 cookie wrappers: Y around [35..275]
	# Row 1 cookie wrappers: Y around [350..595]
	var row_y := [
		Vector2i(35, 275),
		Vector2i(350, 595)
	]

	# Let's inspect column X regions for the 10 packages in each row:
	# Each pack occupies roughly 100 pixels in X.
	# Let's scan each 1/10th of the image:
	for r in range(2):
		var yr: Vector2i = row_y[r]
		print("=== ROW ", r, " (Y in [", yr.x, "..", yr.y, "]) ===")
		for p in range(10):
			var x_start := int(float(p) * (float(w) / 10.0))
			var x_end := int(float(p + 1) * (float(w) / 10.0))

			# Scan X profile in this column to find the 3 strips (Frente, Atras, Lateral)
			# Find spans of non-black pixels
			var inside_strip := false
			var strip_start := 0
			var strips := []

			for x in range(x_start, x_end):
				# check column luminance in y range
				var has_pixel := false
				for y in range(yr.x, yr.y):
					var c: Color = img.get_pixel(x, y)
					if c.r > 0.04 or c.g > 0.04 or c.b > 0.04:
						has_pixel = true
						break

				if has_pixel and not inside_strip:
					inside_strip = true
					strip_start = x
				elif not has_pixel and inside_strip:
					inside_strip = false
					strips.append(Vector2i(strip_start, x - 1))

			if inside_strip:
				strips.append(Vector2i(strip_start, x_end - 1))

			# For each strip, measure exact Y range
			var strip_data := []
			for s in strips:
				var min_y := 9999
				var max_y := -1
				for y in range(yr.x, yr.y):
					for x in range(s.x, s.y + 1):
						var c: Color = img.get_pixel(x, y)
						if c.r > 0.04 or c.g > 0.04 or c.b > 0.04:
							if y < min_y: min_y = y
							if y > max_y: max_y = y
				strip_data.append({
					"x": s.x, "w": s.y - s.x + 1,
					"y": min_y, "h": max_y - min_y + 1
				})

			var line := "Pack [" + str(r) + "," + str(p) + "]: "
			for i in range(strip_data.size()):
				var sd = strip_data[i]
				var tag := "STRIP" + str(i)
				if i == 0: tag = "FRENTE"
				elif i == 1: tag = "ATRAS"
				elif i == 2: tag = "LATERAL"
				line += tag + "=[x=" + str(sd["x"]) + ",w=" + str(sd["w"]) + ",y=" + str(sd["y"]) + ",h=" + str(sd["h"]) + "] "
			print(line)

	quit(0)
