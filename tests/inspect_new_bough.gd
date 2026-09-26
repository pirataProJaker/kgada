@tool
extends SceneTree

func _init() -> void:
	var path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790279820297.jpg"
	var img = Image.load_from_file(path)
	if not img:
		print("Failed to load image!")
		quit()
		return
	
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	
	# Cutout: where color is very close to white
	var out = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			var min_c = minf(c.r, minf(c.g, c.b))
			
			# Background is pure white (#FFFFFF)
			var alpha: float = 1.0
			if min_c > 0.95:
				alpha = 0.0
			elif min_c > 0.88:
				alpha = 1.0 - (min_c - 0.88) / 0.07
			
			# Forzar alfa 0 en un margen de 6px en los bordes y divisor para evitar bleed o líneas negras
			var is_border = (x <= 5 or x >= w - 6 or y <= 5 or y >= h - 6)
			var is_divider = (abs(x - 512) <= 5 or abs(y - 512) <= 5)
			
			# Excluir las 4 esquinas de inserción del tallo:
			var is_stem = (x <= 20 and y >= 490 and y <= 512) or \
						  (x >= 512 and x <= 535 and y >= 490 and y <= 512) or \
						  (x <= 20 and y >= 1000) or \
						  (x >= 512 and x <= 535 and y >= 1000)
			
			if (is_border or is_divider) and not is_stem:
				alpha = 0.0
			
			out.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	
	for q in range(4):
		var col = q % 2
		var row = q / 2
		var min_x = col * 512
		var max_x = (col + 1) * 512 - 1
		var min_y = row * 512
		var max_y = (row + 1) * 512 - 1
		print("Quadrant ", q, " bounds: [", min_x, "..", max_x, "] x [", min_y, "..", max_y, "]")
	
	var out_path = "res://assets/vegetation/alnus/alnus_bough_atlas.png"
	out.save_png(out_path)
	print("Saved clean transparent bough atlas to: ", out_path)
	quit()

