extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/washer.png")
	var w := img.get_width()
	var h := img.get_height()
	print("washer.png %dx%d" % [w, h])
	
	# Where is the enamel/body texture? Rows 88..127 have the white enamel texture!
	# And where is the front door?
	# Let's inspect rows 85..127:
	print("Sample rows 88..127:")
	for y in range(88, 128, 8):
		var c0 := img.get_pixel(10, y)
		var c1 := img.get_pixel(64, y)
		var c2 := img.get_pixel(110, y)
		print("y=%d: c0=(%.2f, %.2f, %.2f) c1=(%.2f, %.2f, %.2f) c2=(%.2f, %.2f, %.2f)" % [
			y, c0.r, c0.g, c0.b, c1.r, c1.g, c1.b, c2.r, c2.g, c2.b
		])
		
	# Let's inspect dryer.png as well:
	var img_d := Image.load_from_file("res://assets/textures/furniture/dryer.png")
	print("\ndryer.png %dx%d" % [img_d.get_width(), img_d.get_height()])
	for y in range(88, 128, 8):
		var c0 := img_d.get_pixel(10, y)
		var c1 := img_d.get_pixel(64, y)
		var c2 := img_d.get_pixel(110, y)
		print("y=%d: c0=(%.2f, %.2f, %.2f) c1=(%.2f, %.2f, %.2f) c2=(%.2f, %.2f, %.2f)" % [
			y, c0.r, c0.g, c0.b, c1.r, c1.g, c1.b, c2.r, c2.g, c2.b
		])
	quit(0)
