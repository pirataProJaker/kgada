extends SceneTree

func _init() -> void:
	var user_dir := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded"
	var out_dir := "res://assets/textures/foliage"
	
	print("--- PROCESANDO TEXTURAS DE FOLLAJE CON COLOR BLEED Y ANTI-RUIDO ---")
	
	# 1. Broadleaf (Roble)
	process_image(
		user_dir + "/media_1789514170471.jpg",
		out_dir + "/leaf_broadleaf_cluster.png",
		Rect2i(160, 10, 706, 998),
		false,
		0.07, 0.12, 0.92, 0.88
	)
	
	# 2. Pine (Pino Boreal)
	process_image(
		user_dir + "/media_1789514388126.png",
		out_dir + "/leaf_pine_cluster.png",
		Rect2i(15, 25, 523, 515),
		false,
		0.08, 0.14, 0.90, 0.85
	)
	
	# 3. Willow (Sauce Lloron - invertido verticalmente)
	process_image(
		user_dir + "/media_1789514507768.png",
		out_dir + "/leaf_willow_cluster.png",
		Rect2i(250, 0, 534, 555),
		true,
		0.07, 0.12, 0.92, 0.88
	)
	
	print("--- PROCESAMIENTO COMPLETADO EXITOSAMENTE ---")
	quit()


func process_image(
	in_path: String,
	out_path: String,
	crop_box: Rect2i,
	flip_y: bool,
	cut_thresh: float,
	ramp_range: float,
	gamma: float,
	gain: float
) -> void:
	var src := Image.load_from_file(in_path)
	if src == null:
		printerr("No se pudo cargar: ", in_path)
		return
	
	var target_size := 512
	var dest := Image.create(target_size, target_size, false, Image.FORMAT_RGBA8)
	dest.fill(Color(0, 0, 0, 0))
	
	var crop_w := crop_box.size.x
	var crop_h := crop_box.size.y
	var scale_factor := float(target_size - 24) / float(maxf(crop_w, crop_h))
	var scaled_w := int(float(crop_w) * scale_factor)
	var scaled_h := int(float(crop_h) * scale_factor)
	var offset_x := (target_size - scaled_w) / 2
	var offset_y := target_size - scaled_h - 4
	
	for dy in range(scaled_h):
		var eff_dy := (scaled_h - 1 - dy) if flip_y else dy
		var src_y := crop_box.position.y + int(float(eff_dy) / scale_factor)
		var out_y := offset_y + dy
		if out_y < 0 or out_y >= target_size:
			continue
		
		for dx in range(scaled_w):
			var src_x := crop_box.position.x + int(float(dx) / scale_factor)
			var out_x := offset_x + dx
			if out_x < 0 or out_x >= target_size:
				continue
			
			var p := src.get_pixel(src_x, src_y)
			var lum := maxf(p.r, maxf(p.g, p.b))
			
			if lum < cut_thresh:
				continue
			
			var alpha := clampf((lum - cut_thresh) / ramp_range, 0.0, 1.0)
			# Suavizado de corte
			alpha = smoothstep(0.0, 1.0, alpha)
			
			# Correccion de borde oscuro
			var val := clampf(lum / maxf(alpha, 0.35), 0.0, 1.0)
			# Curva de brillo tonal equilibrada (sin quemarse a blanco puro)
			val = pow(val, gamma) * gain
			val = clampf(val, 0.0, 0.95)
			
			dest.set_pixel(out_x, out_y, Color(val, val, val, alpha))
	
	# Color Bleed / Dilation de 3 pasadas para bordes transparentes
	# Evita que el mipmapping mezcle las hojas con halos negros
	_apply_color_bleed(dest, 4)
	
	dest.save_png(out_path)
	print("Guardado con Color Bleed: ", out_path)


func _apply_color_bleed(img: Image, passes: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	
	for p in range(passes):
		var copy := Image.new()
		copy.copy_from(img)
		
		for y in range(h):
			for x in range(w):
				var col := copy.get_pixel(x, y)
				if col.a <= 0.01:
					# Buscar vecinos con alfa para heredar su color
					var sum_r := 0.0
					var count := 0
					for dy: int in [-1, 0, 1]:
						var ny: int = y + dy
						if ny < 0 or ny >= h: continue
						for dx: int in [-1, 0, 1]:
							var nx: int = x + dx
							if nx < 0 or nx >= w: continue
							if dx == 0 and dy == 0: continue
							var n_col: Color = copy.get_pixel(nx, ny)
							if n_col.a > 0.05:
								sum_r += n_col.r
								count += 1
					
					if count > 0:
						var avg_val := sum_r / float(count)
						img.set_pixel(x, y, Color(avg_val, avg_val, avg_val, 0.0))
