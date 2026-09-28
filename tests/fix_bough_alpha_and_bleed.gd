extends SceneTree

func _init() -> void:
	var path1 = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527137.png"
	var path2 = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527145.png"

	for idx in range(2):
		var path = path1 if idx == 0 else path2
		var img = Image.load_from_file(path)
		var w = img.get_width()
		var h = img.get_height()
		
		var out_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		
		# Paso 1: Clasificación de Alpha y Des-blanqueo (Un-premultiply)
		for x in range(w):
			for y in range(h):
				var c = img.get_pixel(x, y)
				var max_val = max(c.r, max(c.g, c.b))
				var min_val = min(c.r, min(c.g, c.b))
				var saturation = (max_val - min_val) / max(max_val, 0.001)
				var brightness = (c.r + c.g + c.b) / 3.0
				
				# Fondo blanco:
				var is_white = false
				var alpha = 1.0
				
				# Borde de corte izquierdo (remover fringe blanco en base del tronco):
				if x < 8 and brightness > 0.45 and saturation < 0.15:
					alpha = 0.0
					is_white = true
				elif saturation < 0.04 and brightness > 0.50:
					# Todo pixel desaturado y brillante es fondo blanco o borde difuminado
					if brightness > 0.85:
						alpha = 0.0
						is_white = true
					else:
						# Anti-aliasing suave con des-blanqueo
						var t = (brightness - 0.50) / (0.85 - 0.50)
						alpha = clamp(1.0 - t, 0.0, 1.0)
						if alpha < 0.10:
							alpha = 0.0
							is_white = true
				elif brightness > 0.94 and saturation < 0.08:
					alpha = 0.0
					is_white = true
				elif brightness > 0.82 and saturation < 0.10:
					var t = (brightness - 0.82) / (0.94 - 0.82)
					alpha = clamp(1.0 - t, 0.0, 1.0)
					if alpha < 0.10:
						alpha = 0.0
						is_white = true
				
				var r = c.r
				var g = c.g
				var b = c.b
				
				# Un-premultiply del blanco de fondo para píxeles semi-transparentes:
				if not is_white and alpha < 0.99 and alpha > 0.05:
					r = clamp((r - (1.0 - alpha)) / alpha, 0.0, 1.0)
					g = clamp((g - (1.0 - alpha)) / alpha, 0.0, 1.0)
					b = clamp((b - (1.0 - alpha)) / alpha, 0.0, 1.0)
				
				if is_white:
					# IMPORTANTE: No dejar (1, 1, 1, 0) porque el filtrado bilinear genera halo blanco.
					# Inicializar con color neutro verde/corteza
					out_img.set_pixel(x, y, Color(0.22, 0.32, 0.16, 0.0))
				else:
					out_img.set_pixel(x, y, Color(r, g, b, alpha))
		
		# Paso 2: Alpha Dilation / Color Bleed (8 pasadas de sangrado de color)
		# Extiende el color RGB auténtico de las hojas y la corteza hacia los píxeles transparentes adyacentes.
		# Esto garantiza que al generar Mipmaps, el color promediado sea 100% verde natural y 0% halo blanco.
		print("Aplicando Color Bleed a Imagen %d..." % (idx + 1))
		for pass_idx in range(6):
			var temp_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
			temp_img.copy_from(out_img)
			
			for x in range(w):
				for y in range(h):
					var c = out_img.get_pixel(x, y)
					if c.a < 0.05:
						# Buscar vecinos opacos
						var sum_r = 0.0
						var sum_g = 0.0
						var sum_b = 0.0
						var count = 0
						
						for dx in [-1, 0, 1]:
							for dy in [-1, 0, 1]:
								if dx == 0 and dy == 0: continue
								var nx = x + dx
								var ny = y + dy
								if nx >= 0 and nx < w and ny >= 0 and ny < h:
									var nc = out_img.get_pixel(nx, ny)
									if nc.a > 0.10:
										sum_r += nc.r
										sum_g += nc.g
										sum_b += nc.b
										count += 1
						
						if count > 0:
							temp_img.set_pixel(x, y, Color(sum_r / count, sum_g / count, sum_b / count, 0.0))
			out_img = temp_img
		
		var save_path = "res://assets/vegetation/alnus/alnus_full_bough_%d.png" % (idx + 1)
		out_img.save_png(save_path)
		print("✓ Guardado con Color Bleed: %s" % save_path)
	
	quit(0)
