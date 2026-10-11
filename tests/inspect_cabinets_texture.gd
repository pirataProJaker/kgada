extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	if img == null:
		print("ERROR: Could not load cabinets.png")
		quit(1)
		return
	
	print("cabinets.png dimensions: ", img.get_size())
	var w := img.get_width()
	var h := img.get_height()
	
	# Sample horizontal line across row y = 20 (countertop)
	print("Sampling row y=20 across x from 0 to ", w - 1)
	for x in range(0, w, 16):
		var col: Color = img.get_pixel(x, 20)
		print("x=%d, y=20 -> col=(%.2f, %.2f, %.2f, %.2f)" % [x, col.r, col.g, col.b, col.a])
	
	# Sample horizontal line across row y = 60
	print("Sampling row y=60 across x from 0 to ", w - 1)
	for x in range(0, w, 16):
		var col: Color = img.get_pixel(x, 60)
		print("x=%d, y=60 -> col=(%.2f, %.2f, %.2f, %.2f)" % [x, col.r, col.g, col.b, col.a])
		
	# Sample column x = 20 down y from 0 to h-1
	print("Sampling col x=20 down y from 0 to ", h - 1)
	for y in range(0, h, 16):
		var col: Color = img.get_pixel(20, y)
		print("x=20, y=%d -> col=(%.2f, %.2f, %.2f, %.2f)" % [y, col.r, col.g, col.b, col.a])

	quit(0)
