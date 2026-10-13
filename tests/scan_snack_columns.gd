extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/snack_bags_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()
	var h: int = img.get_height()

	var row_y := [
		Vector2i(13, 172),
		Vector2i(184, 336),
		Vector2i(349, 502),
		Vector2i(516, 667)
	]

	for r_idx in range(row_y.size()):
		var ry: Vector2i = row_y[r_idx]
		# Find horizontal columns with content in this row
		var col_has_content: Array[bool] = []
		for x in range(w):
			var has_c := false
			for y in range(ry.x, ry.y + 1):
				var c: Color = img.get_pixel(x, y)
				if c.r > 0.04 or c.g > 0.04 or c.b > 0.04:
					has_c = true
					break
			col_has_content.append(has_c)

		var packs := []
		var in_p := false
		var p_start := 0
		var p_gap := 0
		for x in range(w):
			if col_has_content[x]:
				if not in_p:
					in_p = true
					p_start = x
				p_gap = 0
			else:
				if in_p:
					p_gap += 1
					if p_gap >= 4 or x == w - 1:
						in_p = false
						packs.append(Vector2i(p_start, x - p_gap))

		print("\n=== Row #%d has %d bags ===" % [r_idx, packs.size()])
		for p_idx in range(packs.size()):
			var px: Vector2i = packs[p_idx]
			
			# Inside [px.x, px.y], find the vertical gutter between front bag and lateral strip
			# Front bag is wide (~140-150 px), lateral strip is narrow (~25-35 px) on the right
			var col_brightness: Array[float] = []
			for x in range(px.x, px.y + 1):
				var sum_b: float = 0.0
				for y in range(ry.x, ry.y + 1):
					var c: Color = img.get_pixel(x, y)
					sum_b += c.get_luminance()
				col_brightness.append(sum_b / float(ry.y - ry.x + 1))
			
			# Find the valley of minimum brightness between front and side (around 25..45 pixels before the end)
			var min_v := 999.0
			var best_split := col_brightness.size() - 32
			for i in range(col_brightness.size() - 48, col_brightness.size() - 18):
				if col_brightness[i] < min_v:
					min_v = col_brightness[i]
					best_split = i
			
			var fx_start: int = px.x
			var fx_end: int = px.x + best_split
			var sx_start: int = fx_end + 1
			var sx_end: int = px.y

			# Trim black gap at split
			while fx_end > fx_start and col_brightness[fx_end - px.x] < 0.04:
				fx_end -= 1
			while sx_start < sx_end and col_brightness[sx_start - px.x] < 0.04:
				sx_start += 1
			
			print("  Bag #%d: Total X=[%d..%d](W=%d) -> Front=[%d..%d](W=%d) Side=[%d..%d](W=%d)" % [
				p_idx, px.x, px.y, px.y - px.x + 1,
				fx_start, fx_end, fx_end - fx_start + 1,
				sx_start, sx_end, sx_end - sx_start + 1
			])

	quit(0)
