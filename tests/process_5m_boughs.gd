@tool
extends SceneTree

func _init() -> void:
	var path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790292662399.jpg"
	var img = Image.load_from_file(path)
	if not img:
		printerr("Failed to load image: ", path)
		quit(1)
		return
	
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	print("Processing 5m bough atlas: ", w, "x", h)
	
	var out = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Quadrant 1 (top-right) needs a horizontal shift of ~125px to the left
	# so that its thick stem begins at the bottom-left corner (x~15, y~485) just like Q0, Q2, and Q3.
	var q1_shift_x = 125
	
	for y in range(h):
		for x in range(w):
			var src_x = x
			var src_y = y
			
			# Apply shift only inside Quadrant 1 (x: 512..1023, y: 0..511)
			if x >= 512 and y < 512:
				src_x = mini(x + q1_shift_x, 1023)
			
			var c = img.get_pixel(src_x, src_y)
			var min_c = minf(c.r, minf(c.g, c.b))
			
			# White background extraction with smooth anti-aliased threshold
			var alpha: float = 1.0
			if min_c > 0.94:
				alpha = 0.0
			elif min_c > 0.86:
				alpha = 1.0 - (min_c - 0.86) / 0.08
			
			# Margen de seguridad en bordes exteriores y divisores centrales
			var is_border = (x <= 4 or x >= w - 5 or y <= 4 or y >= h - 5)
			var is_divider = (abs(x - 512) <= 4 or abs(y - 512) <= 4)
			
			# Proteger el punto de entrada del tallo leñoso en la esquina inferior izquierda de CADA cuadrante:
			# Q0: x: 0..40, y: 460..512
			# Q1: x: 512..555, y: 460..512 (gracias al shift!)
			# Q2: x: 0..40, y: 960..1023
			# Q3: x: 512..555, y: 960..1023
			var is_stem = (x <= 40 and y >= 460 and y <= 512) or \
						  (x >= 512 and x <= 555 and y >= 460 and y <= 512) or \
						  (x <= 40 and y >= 960) or \
						  (x >= 512 and x <= 555 and y >= 960)
			
			if (is_border or is_divider) and not is_stem:
				alpha = 0.0
			
			out.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	
	var out_path = "res://assets/vegetation/alnus/alnus_bough_atlas.png"
	var global_out = ProjectSettings.globalize_path(out_path)
	out.save_png(global_out)
	print("✓ Atlas de ramas de 5m perfectamente calibrado y guardado en: ", out_path)
	quit(0)
