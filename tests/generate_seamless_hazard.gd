extends SceneTree

func _init() -> void:
	var size := 256
	var cycles := 4 # 4 franjas completas de amarillo y 4 de negro
	var period := float(size) / float(cycles) # Exactamente 64.0 pixeles

	var new_img := Image.create(size, size, false, Image.FORMAT_RGBA8)

	# Ruido seamless periódico usando FastNoiseLite si está disponible o senos/cosenos harmónicos
	var noise_gen := FastNoiseLite.new()
	noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_gen.frequency = 0.04
	noise_gen.seed = 12345

	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	# Paleta exacta de la textura militar PSX original
	var col_yellow_clean := Color(0.82, 0.63, 0.12, 1.0)
	var col_yellow_dark := Color(0.68, 0.50, 0.08, 1.0)
	var col_black_clean := Color(0.18, 0.19, 0.20, 1.0)
	var col_black_worn := Color(0.24, 0.25, 0.26, 1.0)

	for y in range(size):
		for x in range(size):
			# Ángulo exacto de 45° periódico continuo
			var diag := float((x + y) % int(period))
			var phase := diag / period # 0.0 a 1.0

			# Muestreo de ruido periódico toroidal (seamless 256x256)
			# Para que el ruido sea seamless en un toroide:
			var angle_x := float(x) / float(size) * TAU
			var angle_y := float(y) / float(size) * TAU
			var nx := cos(angle_x) * 40.0
			var ny := sin(angle_x) * 40.0
			var nz := cos(angle_y) * 40.0
			var nw := sin(angle_y) * 40.0
			var torus_noise := noise_gen.get_noise_2d(nx + nz * 0.5, ny + nw * 0.5)

			var is_yellow := phase < 0.5

			var col: Color
			if is_yellow:
				# Variación de desgaste en el amarillo vial
				var blend := clampf(torus_noise * 1.5 + 0.5, 0.0, 1.0)
				col = col_yellow_clean.lerp(col_yellow_dark, blend)
				# Descascarillado / motas de asfalto expuesto (weathering)
				if (rng.randf() < 0.04 and torus_noise < -0.15) or (rng.randf() < 0.015):
					col = col_black_clean.lerp(col, 0.25)
			else:
				# Variación en el asfalto oscuro
				var blend := clampf(torus_noise * 1.2 + 0.5, 0.0, 1.0)
				col = col_black_clean.lerp(col_black_worn, blend)
				# Motas de polvo/grava en el asfalto
				if rng.randf() < 0.03 and torus_noise > 0.1:
					col = col.lerp(Color(0.38, 0.38, 0.35), 0.4)

			# Micrograno de cemento / asfalto PSX
			var grit := (rng.randf() - 0.5) * 0.06
			col.r = clampf(col.r + grit, 0.0, 1.0)
			col.g = clampf(col.g + grit, 0.0, 1.0)
			col.b = clampf(col.b + grit, 0.0, 1.0)
			col.a = 1.0

			new_img.set_pixel(x, y, col)

	# Guardar la textura oficial en assets
	new_img.save_png("res://assets/textures/military/military_tile_32_r3_c7.png")
	print("✓ Textura oficial guardada: military_tile_32_r3_c7.png (256x256 Seamless)")

	# Generar imagen de cuadrícula 4x4 (1024x1024) para verificación
	var test_grid := Image.create(size * 4, size * 4, false, Image.FORMAT_RGBA8)
	for gy in range(4):
		for gx in range(4):
			test_grid.blit_rect(new_img, Rect2i(0, 0, size, size), Vector2i(gx * size, gy * size))

	test_grid.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/hazard_stripes_4x4_seamless.png")
	print("✓ Imagen de prueba 4x4 guardada: hazard_stripes_4x4_seamless.png")

	quit(0)
