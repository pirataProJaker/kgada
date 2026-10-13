extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()
	var h: int = img.get_height()

	var pack_x_r0 := [
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

	var pack_x_r1 := [
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

	for r in range(2):
		var y_min: int = 34 if r == 0 else 345
		var y_max: int = 275 if r == 0 else 599
		var packs = pack_x_r0 if r == 0 else pack_x_r1
		print("\n--- ROW ", r, " ---")
		for p_idx in range(packs.size()):
			var px: Vector2i = packs[p_idx]
			# Find average column intensity in [y_min, y_max] to spot the vertical black gutters inside the pack
			var col_brightness: Array[float] = []
			for x in range(px.x, px.y + 1):
				var sum_b: float = 0.0
				for y in range(y_min, y_max + 1):
					var c: Color = img.get_pixel(x, y)
					sum_b += (c.r + c.g + c.b) / 3.0
				col_brightness.append(sum_b / float(y_max - y_min + 1))
			
			# Find the two valleys of minimum brightness between front & back, and between back & side
			# Front is around offset 35..48, Side is around offset px.y - px.x - 22 .. px.y - px.x - 14
			var best_v1 := 40
			var min_v1 := 999.0
			for i in range(36, mini(48, col_brightness.size() - 25)):
				if col_brightness[i] < min_v1:
					min_v1 = col_brightness[i]
					best_v1 = i
			
			var best_v2 := col_brightness.size() - 19
			var min_v2 := 999.0
			for i in range(mini(col_brightness.size() - 24, best_v1 + 25), col_brightness.size() - 12):
				if col_brightness[i] < min_v2:
					min_v2 = col_brightness[i]
					best_v2 = i

			var x_frente_end = px.x + best_v1
			var x_atras_start = x_frente_end + 1
			# trim black gutter at v1
			while x_frente_end > px.x and col_brightness[x_frente_end - px.x] < 0.05:
				x_frente_end -= 1
			while x_atras_start < px.y and col_brightness[x_atras_start - px.x] < 0.05:
				x_atras_start += 1
			
			var x_atras_end = px.x + best_v2
			var x_lat_start = x_atras_end + 1
			while x_atras_end > x_atras_start and col_brightness[x_atras_end - px.x] < 0.05:
				x_atras_end -= 1
			while x_lat_start < px.y and col_brightness[x_lat_start - px.x] < 0.05:
				x_lat_start += 1
			
			print("Pack %d: Frente=[%d..%d](w=%d) Atras=[%d..%d](w=%d) Lateral=[%d..%d](w=%d)" % [
				p_idx, px.x, x_frente_end, x_frente_end - px.x + 1,
				x_atras_start, x_atras_end, x_atras_end - x_atras_start + 1,
				x_lat_start, px.y, px.y - x_lat_start + 1
			])

	quit(0)
