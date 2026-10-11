@tool
extends SceneTree

func _init() -> void:
	for name in ["washer", "dryer"]:
		var path := "res://assets/textures/furniture/%s.png" % name
		var img := Image.load_from_file(path)
		print("========================================")
		print("ANALISIS PIXEL A PIXEL: ", name, ".png (", img.get_size(), ")")
		print("========================================")
		
		# Console: X around 40..90, Y around 20..40
		# Find console bounds
		print("Buscando pixeles no blancos en Y=20..38:")
		for y in range(20, 38):
			var xs := []
			for x in range(0, 128):
				var px: Color = img.get_pixel(x, y)
				if px.r < 0.9 or px.g < 0.9 or px.b < 0.9:
					xs.append(x)
			if not xs.is_empty():
				print("  y=%2d: min_x=%2d, max_x=%2d (width=%2d)" % [y, xs[0], xs[-1], xs[-1] - xs[0] + 1])
		
		# Door / Lid:
		print("Buscando recuadros negros (puerta/tapa) en Y=35..115:")
		for y in range(35, 115):
			var xs := []
			for x in range(0, 128):
				var px: Color = img.get_pixel(x, y)
				# Check for black or dark outline (border of door)
				if px.r < 0.3 and px.g < 0.3 and px.b < 0.3:
					xs.append(x)
			if not xs.is_empty():
				print("  y=%2d: min_x=%2d, max_x=%2d (width=%2d) [count=%2d]" % [y, xs[0], xs[-1], xs[-1] - xs[0] + 1, xs.size()])

	quit(0)
