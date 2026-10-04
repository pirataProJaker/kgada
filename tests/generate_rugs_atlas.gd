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

	# Dimensiones fijas perfectamente rectangulares para cada celda
	const CELL_W := 512
	const CELL_H := 350

	# Atlas maestro: 5 columnas x 4 filas = 2560 x 1400 px
	var master_atlas := Image.create(CELL_W * 5, CELL_H * 4, false, Image.FORMAT_RGBA8)
	master_atlas.fill(Color(0, 0, 0, 1))

	var rug_id := 0
	for r in range(4):
		for c in range(5):
			var x0: int = col_boxes[c][0]
			var x1: int = col_boxes[c][1]
			var y0: int = row_boxes[r][0]
			var y1: int = row_boxes[r][1]

			# Ajuste fino: buscar bordes donde la luminosidad sea > 0.08
			while x0 < x1:
				var avg := 0.0
				for y in range(y0, y1 + 1):
					var px = src.get_pixel(x0, y)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(y1 - y0 + 1)
				if avg > 0.08:
					break
				x0 += 1

			while x1 > x0:
				var avg := 0.0
				for y in range(y0, y1 + 1):
					var px = src.get_pixel(x1, y)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(y1 - y0 + 1)
				if avg > 0.08:
					break
				x1 -= 1

			while y0 < y1:
				var avg := 0.0
				for x in range(x0, x1 + 1):
					var px = src.get_pixel(x, y0)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(x1 - x0 + 1)
				if avg > 0.08:
					break
				y0 += 1

			while y1 > y0:
				var avg := 0.0
				for x in range(x0, x1 + 1):
					var px = src.get_pixel(x, y1)
					avg += (px.r + px.g + px.b) / 3.0
				avg /= float(x1 - x0 + 1)
				if avg > 0.08:
					break
				y1 -= 1

			# Margen de seguridad interior de 1px
			x0 += 1
			x1 -= 1
			y0 += 1
			y1 -= 1

			var rw := x1 - x0 + 1
			var rh := y1 - y0 + 1

			var cropped := Image.create(rw, rh, false, src.get_format())
			cropped.blit_rect(src, Rect2i(x0, y0, rw, rh), Vector2i.ZERO)

			# Redimensionar a RECTÁNGULO EXACTO (512 x 350) preservando la relación de aspecto 1.46
			cropped.convert(Image.FORMAT_RGBA8)
			cropped.resize(CELL_W, CELL_H, Image.INTERPOLATE_LANCZOS)

			# Guardar imagen individual rectangular
			var fname := "rug_%02d.png" % rug_id
			var save_path := out_dir + "/" + fname
			cropped.save_png(ProjectSettings.globalize_path(save_path))

			# Pegar en la posición correspondiente del Atlas Maestro (c * CELL_W, r * CELL_H)
			master_atlas.blit_rect(cropped, Rect2i(0, 0, CELL_W, CELL_H), Vector2i(c * CELL_W, r * CELL_H))

			print("✓ Rug %02d [%d,%d]: Guardado %dx%d (original: %dx%d, ratio=%.3f)" % [
				rug_id, c, r, CELL_W, CELL_H, rw, rh, float(rw) / float(rh)
			])
			rug_id += 1

	var master_path := "res://assets/textures/furniture/rugs_master_atlas.png"
	master_atlas.save_png(ProjectSettings.globalize_path(master_path))
	print("=======================================================")
	print("✓ ATLAS MAESTRO DE ALFOMBRAS CREADO EXITOSAMENTE: %s (%dx%d)" % [
		master_path, master_atlas.get_width(), master_atlas.get_height()
	])
	print("=======================================================")

	quit(0)
