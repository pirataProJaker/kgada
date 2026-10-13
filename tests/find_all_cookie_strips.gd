extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()

	for r in [0, 1]:
		var y_min: int = 35 if r == 0 else 350
		var y_max: int = 275 if r == 0 else 595

		print("==================== ROW ", r, " ====================")
		var inside := false
		var start_x := 0
		var strips := []

		for x in range(w):
			var has_content := false
			for y in range(y_min, y_max):
				var c: Color = img.get_pixel(x, y)
				if c.r > 0.04 or c.g > 0.04 or c.b > 0.04:
					has_content = true
					break

			if has_content and not inside:
				inside = true
				start_x = x
			elif not has_content and inside:
				inside = false
				strips.append(Vector2i(start_x, x - 1))

		if inside:
			strips.append(Vector2i(start_x, w - 1))

		print("Found ", strips.size(), " strips in row ", r, ":")
		for i in range(strips.size()):
			var s: Vector2i = strips[i]
			var sw: int = s.y - s.x + 1
			print("  Strip #", i, ": X=[", s.x, "..", s.y, "] (w=", sw, ")")

	quit(0)
