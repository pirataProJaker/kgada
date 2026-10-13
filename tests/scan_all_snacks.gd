extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/snack_bags_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	if not img:
		print("ERROR: Could not load ", path)
		quit(1)
		return

	var w: int = img.get_width()
	var h: int = img.get_height()
	print("Snack atlas image loaded: %dx%d" % [w, h])

	# Scan horizontal luminance to detect row gaps
	print("--- Scanning horizontal rows ---")
	var row_has_content: Array[bool] = []
	for y in range(h):
		var sum_lum: float = 0.0
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			sum_lum += c.get_luminance()
		var avg_lum := sum_lum / float(w)
		row_has_content.append(avg_lum > 0.04)

	var rows := []
	var in_r := false
	var r_start := 0
	var r_gap := 0
	for y in range(h):
		if row_has_content[y]:
			if not in_r:
				in_r = true
				r_start = y
			r_gap = 0
		else:
			if in_r:
				r_gap += 1
				if r_gap >= 5 or y == h - 1:
					in_r = false
					rows.append(Vector2i(r_start, y - r_gap))

	print("Found %d rows:" % rows.size())
	for i in range(rows.size()):
		var r: Vector2i = rows[i]
		print("  Row #%d: Y=[%d..%d] (H=%d)" % [i, r.x, r.y, r.y - r.x + 1])

	quit(0)
