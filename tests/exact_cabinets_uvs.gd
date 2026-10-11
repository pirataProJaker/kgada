extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	var w := img.get_width()
	var h := img.get_height()
	print("cabinets.png %dx%d" % [w, h])
	
	# 1. Granite:
	# Starts at x=20, ends at x=164. y starts at 1, ends at 88.
	print("Granite:")
	print("  x: [21..163], y: [2..86]")
	print("  UV Rect2: Rect2(%.5f, %.5f, %.5f, %.5f)" % [
		21.0 / 256.0, 2.0 / 256.0, (163.0 - 21.0) / 256.0, (86.0 - 2.0) / 256.0
	])
	
	# 2. Wood side:
	# x: [2..86], y: [92..253]
	print("Wood side:")
	print("  x: [2..86], y: [92..253]")
	print("  UV Rect2: Rect2(%.5f, %.5f, %.5f, %.5f)" % [
		2.0 / 256.0, 92.0 / 256.0, (86.0 - 2.0) / 256.0, (253.0 - 92.0) / 256.0
	])
	
	# 3. Drawer:
	# x: [92..156], y: [94..116]
	print("Drawer:")
	print("  x: [92..156], y: [94..116]")
	print("  UV Rect2: Rect2(%.5f, %.5f, %.5f, %.5f)" % [
		92.0 / 256.0, 94.0 / 256.0, (156.0 - 92.0) / 256.0, (116.0 - 94.0) / 256.0
	])
	
	# 4. Door front:
	# x: [92..156], y: [122..214]
	print("Door front:")
	print("  x: [92..156], y: [122..214]")
	print("  UV Rect2: Rect2(%.5f, %.5f, %.5f, %.5f)" % [
		92.0 / 256.0, 122.0 / 256.0, (156.0 - 92.0) / 256.0, (214.0 - 122.0) / 256.0
	])
	
	# 5. Kickplate:
	# x: [92..156], y: [220..253]
	print("Kickplate:")
	print("  x: [92..156], y: [220..253]")
	print("  UV Rect2: Rect2(%.5f, %.5f, %.5f, %.5f)" % [
		92.0 / 256.0, 220.0 / 256.0, (156.0 - 92.0) / 256.0, (253.0 - 220.0) / 256.0
	])

	# 6. Sink Rim & Basin:
	# Let's inspect the exact box of the sink in columns 164..255 and rows 100..255
	var sink_min_x := 999
	var sink_max_x := -1
	var sink_min_y := 999
	var sink_max_y := -1
	for y in range(160, 255):
		for x in range(164, 256):
			var c: Color = img.get_pixel(x, y)
			if not (c.r > 0.98 and c.g > 0.98 and c.b > 0.98): # non white
				sink_min_x = mini(sink_min_x, x)
				sink_max_x = maxi(sink_max_x, x)
				sink_min_y = mini(sink_min_y, y)
				sink_max_y = maxi(sink_max_y, y)
	print("Sink basin:")
	print("  x: [%d..%d], y: [%d..%d]" % [sink_min_x, sink_max_x, sink_min_y, sink_max_y])
	print("  UV Rect2: Rect2(%.5f, %.5f, %.5f, %.5f)" % [
		float(sink_min_x) / 256.0, float(sink_min_y) / 256.0,
		float(sink_max_x - sink_min_x) / 256.0, float(sink_max_y - sink_min_y) / 256.0
	])

	quit(0)
