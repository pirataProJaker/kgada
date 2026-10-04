extends SceneTree

func _init() -> void:
	var path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/.user_uploaded/media_1790967656197.jpg"
	var src := Image.load_from_file(path)
	if not src:
		print("Error cargando imagen")
		quit(1)
		return
		
	var out_dir := "res://assets/textures/furniture/rugs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	
	# Coordenadas aproximadas de las 5 columnas y 4 filas
	var col_boxes := [
		[12, 196],
		[216, 400],
		[420, 607],
		[625, 810],
		[830, 1011]
	]
	var row_boxes := [
		[36, 163],
		[188, 314],
		[341, 470],
		[497, 631]
	]
	
	var rug_id := 0
	for r in range(4):
		for c in range(5):
			var x0: int = col_boxes[c][0]
			var x1: int = col_boxes[c][1]
			var y0: int = row_boxes[r][0]
			var y1: int = row_boxes[r][1]
			
			# Ajuste fino: buscar bordes donde la luminosidad sea > 0.08
			# Recortar desde x0 hacia adentro
			while x0 < x1:
				var avg := 0.0
				for y in range(y0, y1 + 1):
					var px = src.get_pixel(x0, y)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(y1 - y0 + 1)
				if avg > 0.08:
					break
				x0 += 1
				
			# Recortar desde x1 hacia adentro
			while x1 > x0:
				var avg := 0.0
				for y in range(y0, y1 + 1):
					var px = src.get_pixel(x1, y)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(y1 - y0 + 1)
				if avg > 0.08:
					break
				x1 -= 1
				
			# Recortar desde y0 hacia adentro
			while y0 < y1:
				var avg := 0.0
				for x in range(x0, x1 + 1):
					var px = src.get_pixel(x, y0)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(x1 - x0 + 1)
				if avg > 0.08:
					break
				y0 += 1
				
			# Recortar desde y1 hacia adentro
			while y1 > y0:
				var avg := 0.0
				for x in range(x0, x1 + 1):
					var px = src.get_pixel(x, y1)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(x1 - x0 + 1)
				if avg > 0.08:
					break
				y1 -= 1
				
			# 1px de margen interno para asegurar 0% de fuga de negro
			x0 += 1
			x1 -= 1
			y0 += 1
			y1 -= 1
			
			var rw := x1 - x0 + 1
			var rh := y1 - y0 + 1
			
			var cropped := Image.create(rw, rh, false, src.get_format())
			cropped.blit_rect(src, Rect2i(x0, y0, rw, rh), Vector2i.ZERO)
			
			# Redimensionar a textura de alta definición 512x512 para el atlas
			cropped.convert(Image.FORMAT_RGBA8)
			cropped.resize(512, 512, Image.INTERPOLATE_LANCZOS)
			
			var fname := "rug_%02d.png" % rug_id
			var save_path := out_dir + "/" + fname
			var gsave_path := ProjectSettings.globalize_path(save_path)
			cropped.save_png(gsave_path)
			print("✓ Guardado Rug %02d: %s (crop original: %dx%d)" % [rug_id, fname, rw, rh])
			rug_id += 1
			
	quit(0)
