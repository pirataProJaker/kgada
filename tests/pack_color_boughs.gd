@tool
extends SceneTree

func _init() -> void:
	var files = [
		"C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790366950121.png",
		"C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790366950208.png",
		"C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790366950303.png",
		"C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790366950344.png"
	]
	
	var quad_size = 1024
	var atlas_size = quad_size * 2 # 2048 x 2048
	var atlas = Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	
	for i in range(4):
		var img = Image.load_from_file(files[i])
		if not img:
			printerr("Failed to load: ", files[i])
			quit(1)
			return
		
		img.convert(Image.FORMAT_RGBA8)
		var w = img.get_width()
		var h = img.get_height()
		
		# 1. Defringe: eliminar píxeles blancos del fondo residual que tenían alpha > 0
		for y in range(h):
			for x in range(w):
				var c = img.get_pixel(x, y)
				var min_rgb = minf(c.r, minf(c.g, c.b))
				
				# Píxeles que son claramente blanco del fondo
				if min_rgb > 0.88:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				# Píxeles de halo blanco de transición
				elif min_rgb > 0.72 and c.a < 0.90:
					var new_a = c.a * clamp(1.0 - (min_rgb - 0.72) / 0.16, 0.0, 1.0)
					if new_a < 0.10:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
					else:
						img.set_pixel(x, y, Color(c.r, c.g, c.b, new_a))
		
		# 2. Reescalado de alta calidad a 1024x1024
		img.resize(quad_size, quad_size, Image.INTERPOLATE_LANCZOS)
		
		# 3. Dilatación de color RGB en los bordes transparentes (edge color bleeding)
		# Reemplaza cualquier halo claro restante con el color verde/madera del vecino interior
		var dilated = img.duplicate()
		for pass_idx in range(3):
			for y in range(quad_size):
				for x in range(quad_size):
					var c = dilated.get_pixel(x, y)
					var min_rgb = minf(c.r, minf(c.g, c.b))
					# Si es transparente o es un borde blanquecino residual
					if c.a < 0.35 or (min_rgb > 0.70 and c.a < 0.85):
						var sum_rgb = Vector3.ZERO
						var count = 0
						for dy in [-1, 0, 1]:
							for dx in [-1, 0, 1]:
								var nx = x + dx
								var ny = y + dy
								if nx >= 0 and nx < quad_size and ny >= 0 and ny < quad_size:
									var nc = dilated.get_pixel(nx, ny)
									var n_min = minf(nc.r, minf(nc.g, nc.b))
									if nc.a > 0.60 and n_min < 0.65:
										sum_rgb += Vector3(nc.r, nc.g, nc.b)
										count += 1
						if count > 0:
							var avg = sum_rgb / float(count)
							var out_a = c.a if c.a >= 0.35 else 0.0
							img.set_pixel(x, y, Color(avg.x, avg.y, avg.z, out_a))
			dilated = img.duplicate()
		
		var col = i % 2
		var row = i / 2
		var ox = col * quad_size
		var oy = row * quad_size
		
		atlas.blit_rect(img, Rect2i(0, 0, quad_size, quad_size), Vector2i(ox, oy))
		print("Quadrant ", i, " defringed and blitted at (", ox, ", ", oy, ")")
	
	var out_path = "res://assets/vegetation/alnus/alnus_bough_atlas.png"
	var global_out = ProjectSettings.globalize_path(out_path)
	atlas.save_png(global_out)
	print("✓ Atlas 2048x2048 defringed guardado en: ", out_path)
	
	atlas.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/color_bough_atlas_preview.png")
	quit(0)
