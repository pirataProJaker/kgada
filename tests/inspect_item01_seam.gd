extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)

	# Inspect Item 01: X=11..106, Y=35..275
	print("--- Scanning Item 01 X profile (Y=150) ---")
	for x in range(11, 107):
		var c: Color = img.get_pixel(x, 150)
		if x % 5 == 0:
			print("X=", x, " col=(", snappedf(c.r, 0.01), ",", snappedf(c.g, 0.01), ",", snappedf(c.b, 0.01), ") lum=", snappedf(c.get_luminance(), 0.01))

	# Let's find the vertical seam between Frente and Atras in Item 01
	var min_lum := 999.0
	var min_x := -1
	for x in range(35, 65):
		var sum_l := 0.0
		for y in range(40, 260):
			sum_l += img.get_pixel(x, y).get_luminance()
		var avg_l := sum_l / 220.0
		if avg_l < min_lum:
			min_lum = avg_l
			min_x = x
	print("Dark seam between Frente and Atras near X=", min_x, " lum=", min_lum)

	quit(0)
