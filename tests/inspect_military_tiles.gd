extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://assets/textures/military")
	if dir == null:
		print("No se pudo abrir res://assets/textures/military")
		quit(1)
		return
	
	dir.list_dir_begin()
	var fname := dir.get_next()
	var files: Array[String] = []
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("military_tile_") and fname.ends_with(".png"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()

	print("Total tiles: ", files.size())
	for f in files:
		var img := Image.load_from_file("res://assets/textures/military/" + f)
		if img == null:
			continue
		var w := img.get_width()
		var h := img.get_height()
		var r_sum := 0.0
		var g_sum := 0.0
		var b_sum := 0.0
		var yellow_pixels := 0
		var dark_pixels := 0
		var count := w * h
		for y in range(h):
			for x in range(w):
				var col := img.get_pixel(x, y)
				r_sum += col.r
				g_sum += col.g
				b_sum += col.b
				if col.r > 0.55 and col.g > 0.45 and col.b < 0.25:
					yellow_pixels += 1
				if col.r < 0.20 and col.g < 0.20 and col.b < 0.20:
					dark_pixels += 1
		var avg_r := r_sum / count
		var avg_g := g_sum / count
		var avg_b := b_sum / count
		var y_pct := float(yellow_pixels) / count
		print("%s | (%dx%d) | RGB: (%.2f, %.2f, %.2f) | Yellow: %.1f%% | Dark: %.1f%%" % [
			f, w, h, avg_r, avg_g, avg_b, y_pct * 100.0, float(dark_pixels) / count * 100.0
		])

	quit(0)
