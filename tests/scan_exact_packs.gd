extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()
	var h: int = img.get_height()

	var pack_names_r0 := [
		"clasicas",     # 01
		"chocolate",    # 02
		"vainilla",     # 03
		"fresa",        # 04
		"crema",        # 05
		"limon",        # 06
		"arandano",     # 07
		"naranja",      # 09
		"frutos_rojos"  # 10
	]

	var pack_names_r1 := [
		"platano",      # 11
		"chispas",      # 12
		"integrales",   # 13
		"doble_choco",  # 14
		"menta",        # 15
		"canela",       # 16
		"avena",        # 17
		"festival",     # 18
		"cookies_cream" # 20
	]

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
		var y_search_min: int = 25 if r == 0 else 335
		var y_search_max: int = 285 if r == 0 else 610
		var packs = pack_x_r0 if r == 0 else pack_x_r1
		var names = pack_names_r0 if r == 0 else pack_names_r1

		print("\n=== Scanning Row %d ===" % r)
		for p_idx in range(packs.size()):
			var px: Vector2i = packs[p_idx]
			var pname: String = names[p_idx]

			# Find exact Y top and bottom
			var min_y := 999
			var max_y := -1
			for y in range(y_search_min, y_search_max):
				for x in range(px.x, px.y + 1):
					var c: Color = img.get_pixel(x, y)
					if c.r > 0.05 or c.g > 0.05 or c.b > 0.05:
						min_y = mini(min_y, y)
						max_y = maxi(max_y, y)
			
			print("Pack %d (%s): X=[%d..%d] Y=[%d..%d] H=%d" % [p_idx, pname, px.x, px.y, min_y, max_y, max_y - min_y + 1])

	quit(0)
