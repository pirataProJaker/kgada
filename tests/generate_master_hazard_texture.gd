extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d"

func _init() -> void:
	print("=================================================================")
	print("=== GENERANDO TEXTURA MASTER SEAMLESS DE FRANJAS DE ADVERTENCIA ===")
	print("=================================================================")

	# Vamos a generar 2 variantes para que el usuario pueda comparar:
	# Variante 1: 2 franjas anchas (cycles = 2, franjas gruesas tácticas tipo base militar/hangar)
	# Variante 2: 3 franjas medianas (cycles = 3, franjas estándar viales)
	
	var tex_2cycles := _build_hazard_texture(256, 2, "hazard_stripes_2cycles")
	var tex_3cycles := _build_hazard_texture(384, 3, "hazard_stripes_3cycles") # 384 divisible por 3 (128 px c/u) y luego resize a 256
	tex_3cycles.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	
	# Guardar en assets principales (la variante de 2 ciclos, que es la proporción original militar)
	tex_2cycles.save_png("res://assets/textures/military/military_tile_32_r3_c7.png")
	tex_2cycles.save_png("res://assets/textures/military/military_tile_07_r0_c6.png")
	tex_2cycles.save_png(ARTIFACT_DIR + "/master_hazard_tile_256.png")
	
	# Generar visualizaciones de cuadrícula 6x3 (el tamaño exacto del portón de la base: 6m de ancho x 3m de fondo)
	_render_road_preview(tex_2cycles, 6, 3, ARTIFACT_DIR + "/hazard_road_6x3_variant_2cycles.png", "2 Franjas Gruesas Tácticas")
	_render_road_preview(tex_3cycles, 6, 3, ARTIFACT_DIR + "/hazard_road_6x3_variant_3cycles.png", "3 Franjas Medianas")
	
	# Generar también una cuadrícula grande 4x4
	_render_road_preview(tex_2cycles, 4, 4, ARTIFACT_DIR + "/hazard_floor_4x4_master.png", "Cuadrícula 4x4")

	print("✓ Texturas master y pruebas de cuadrícula generadas con éxito.")
	quit(0)

func _build_hazard_texture(size: int, cycles: int, debug_name: String) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var period := float(size) / float(cycles)
	
	# Ruido Simplex para envejecimiento, descascarillado y grano de asfalto
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.seed = 98765
	
	var fine_noise := FastNoiseLite.new()
	fine_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	fine_noise.frequency = 0.12
	fine_noise.seed = 43210

	var rng := RandomNumberGenerator.new()
	rng.seed = 112233

	# Colores militares PSX calibrados de la hoja original
	var col_yellow_base := Color(0.78, 0.58, 0.10, 1.0)
	var col_yellow_light := Color(0.85, 0.65, 0.14, 1.0)
	var col_yellow_dark := Color(0.60, 0.44, 0.06, 1.0)
	
	var col_asphalt_base := Color(0.20, 0.21, 0.22, 1.0)
	var col_asphalt_light := Color(0.26, 0.27, 0.28, 1.0)
	var col_asphalt_dark := Color(0.14, 0.15, 0.16, 1.0)

	for y in range(size):
		for x in range(size):
			# Muestreo toroidal 4D para ruido 100% periódico (sin cortes en las costuras)
			var angle_x := (float(x) / float(size)) * TAU
			var angle_y := (float(y) / float(size)) * TAU
			
			var cos_x := cos(angle_x) * 35.0
			var sin_x := sin(angle_x) * 35.0
			var cos_y := cos(angle_y) * 35.0
			var sin_y := sin(angle_y) * 35.0
			
			var n_coarse := noise.get_noise_2d(cos_x + cos_y * 0.5, sin_x + sin_y * 0.5)
			var n_fine := fine_noise.get_noise_2d(cos_x * 2.0 + sin_y, sin_x * 2.0 + cos_y)
			
			# Coordenada diagonal periódica continua a 45°
			# En 45°: t = x + y. Al wrap en x=size o y=size, (t + size) mod period = t mod period
			# porque size es múltiplo exacto de period!
			var t := float((x + y) % int(round(period)))
			var norm_t := t / period # 0.0 a 1.0
			
			# Suavizado en los bordes para stencil realista (evitar serrucho aliasing)
			var edge_softness := 0.025
			var mask := 0.0
			
			# Franja amarilla ocupa el 50% del periodo (0.0 a 0.5)
			# Con ligera perturbación de borde de plantilla stencil
			var edge_dist := absf(norm_t - 0.25)
			if norm_t < 0.5:
				var d1 := norm_t
				var d2 := 0.5 - norm_t
				var min_d := minf(d1, d2)
				mask = clampf(min_d / edge_softness, 0.0, 1.0)
			else:
				mask = 0.0

			var col: Color
			if mask > 0.0:
				# Tono base amarillo con gradiente de suciedad y desgaste
				var y_tone := col_yellow_base.lerp(col_yellow_light, clampf(n_coarse * 1.5, 0.0, 1.0))
				y_tone = y_tone.lerp(col_yellow_dark, clampf(-n_coarse * 1.2, 0.0, 1.0))
				
				# Descascarillado natural de la pintura vial
				if n_fine > 0.28:
					y_tone = y_tone.lerp(col_asphalt_base, clampf((n_fine - 0.28) * 3.5, 0.0, 0.85))
					
				# Mezcla con el asfalto del fondo en los bordes de plantilla
				var bg_asphalt := col_asphalt_base.lerp(col_asphalt_light, clampf(n_coarse, 0.0, 1.0))
				col = bg_asphalt.lerp(y_tone, mask)
			else:
				# Asfalto táctico oscuro con grano y árido
				col = col_asphalt_base.lerp(col_asphalt_light, clampf(n_coarse * 1.2 + 0.2, 0.0, 1.0))
				col = col.lerp(col_asphalt_dark, clampf(-n_coarse * 1.2, 0.0, 1.0))
				if n_fine > 0.35:
					col = col.lerp(Color(0.32, 0.33, 0.32), 0.35)

			# Grano micro-texturizado de asfalto PSX (dither sutil)
			var grain := (n_fine * 0.04)
			col.r = clampf(col.r + grain, 0.0, 1.0)
			col.g = clampf(col.g + grain, 0.0, 1.0)
			col.b = clampf(col.b + grain, 0.0, 1.0)
			col.a = 1.0

			img.set_pixel(x, y, col)
			
	return img

func _render_road_preview(tile: Image, cols: int, rows: int, out_path: String, title: String) -> void:
	var tw := tile.get_width()
	var th := tile.get_height()
	var canvas := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGBA8)
	
	for r in range(rows):
		for c in range(cols):
			canvas.blit_rect(tile, Rect2i(0, 0, tw, th), Vector2i(c * tw, r * th))
			
	canvas.save_png(out_path)
	print("✓ Vista previa guardada (%s): %s" % [title, out_path])
