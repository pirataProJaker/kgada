extends SceneTree

func _init() -> void:
	var path1 = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527137.png"
	var img = Image.load_from_file(path1)
	print("Format: ", img.get_format())
	print("Pixel at (0, 0): ", img.get_pixel(0, 0))
	print("Pixel at (500, 10): ", img.get_pixel(500, 10))
	print("Pixel at (10, 300): ", img.get_pixel(10, 300))
	
	# Check corners
	for p in [Vector2i(0, 0), Vector2i(1023, 0), Vector2i(0, 340), Vector2i(1023, 340)]:
		print("Corner %s: %s" % [p, img.get_pixelv(p)])
	quit(0)
