extends SceneTree

func _init() -> void:
	var path: String = "res://assets/textures/furniture/snack_bags_atlas.jpg"
	var img: Image = Image.load_from_file(path)

	print("--- Row 0 Bag 0 (Tostik's) X=160..176 scan at Y=90 ---")
	for x in range(160, 176):
		var c: Color = img.get_pixel(x, 90)
		print("X=%3d: (R=%.3f, G=%.3f, B=%.3f, Lum=%.3f)" % [x, c.r, c.g, c.b, c.get_luminance()])

	quit(0)
