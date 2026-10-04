extends SceneTree

# Algoritmo de filtrado paso-alto (High-Pass / Equalización de Iluminación) y Seamless Avanzado
# 1. Elimina gradientes de luz/sombra globales (aplanado de iluminación).
# 2. Desplaza toroidalmente en W/2 y H/2.
# 3. Mezcla con máscara Hermite suave multidireccional para fundir los bordes con los opuestos.

func flatten_and_make_seamless(src_img: Image) -> Image:
	var w := src_img.get_width()
	var h := src_img.get_height()
	
	# Asegurar formato RGBA8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.blit_rect(src_img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	
	# --- PASO 1: CALCULAR COLOR MEDIO GLOBAL Y MAPA DE ILUMINACIÓN DE BAJA FRECUENCIA ---
	var sum_r: float = 0.0
	var sum_g: float = 0.0
	var sum_b: float = 0.0
	var total_pixels: float = float(w * h)
	
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			sum_r += c.r
			sum_g += c.g
			sum_b += c.b
			
	var mean_col := Color(sum_r / total_pixels, sum_g / total_pixels, sum_b / total_pixels, 1.0)
	
	# Desenfocador de caja toroidal para estimar iluminación de baja frecuencia
	var radius := 16
	var blur_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for y in range(h):
		for x in range(w):
			var br: float = 0.0
			var bg: float = 0.0
			var bb: float = 0.0
			var count: int = 0
			# Muestreo con paso para eficiencia
			for dy in range(-radius, radius + 1, 3):
				var sy = (y + dy + h * 10) % h
				for dx in range(-radius, radius + 1, 3):
					var sx = (x + dx + w * 10) % w
					var pc := img.get_pixel(sx, sy)
					br += pc.r
					bg += pc.g
					bb += pc.b
					count += 1
			blur_img.set_pixel(x, y, Color(br / float(count), bg / float(count), bb / float(count), 1.0))
			
	# Aplanado de iluminación (High-Pass): Restar blur y sumar media
	var flat_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var orig_c := img.get_pixel(x, y)
			var blur_c := blur_img.get_pixel(x, y)
			var r := clampf(orig_c.r - blur_c.r + mean_col.r, 0.0, 1.0)
			var g := clampf(orig_c.g - blur_c.g + mean_col.g, 0.0, 1.0)
			var b := clampf(orig_c.b - blur_c.b + mean_col.b, 0.0, 1.0)
			flat_img.set_pixel(x, y, Color(r, g, b, 1.0))

	# --- PASO 2: DESPLAZAMIENTO TOROIDAL (Wrap offset W/2, H/2) ---
	var half_w := w / 2
	var half_h := h / 2
	var shifted := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var sx = (x + half_w) % w
			var sy = (y + half_h) % h
			shifted.set_pixel(x, y, flat_img.get_pixel(sx, sy))

	# --- PASO 3: MEZCLA HERMITE SUAVE ENTRE EL CENTRO Y LOS BORDES ---
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var ny := absf(float(y - half_h)) / float(half_h) # 0 en centro, 1 en bordes
		for x in range(w):
			var nx := absf(float(x - half_w)) / float(half_w)
			
			# Distancia elíptica suave al centro
			var d := sqrt(nx * nx * 0.5 + ny * ny * 0.5)
			# Curva de transición suave (Smoothstep) de 0.25 a 0.75
			var t := clampf((d - 0.25) / 0.50, 0.0, 1.0)
			var weight := t * t * (3.0 - 2.0 * t) # Hermite smoothstep
			
			var c_flat := flat_img.get_pixel(x, y)
			var c_shift := shifted.get_pixel(x, y)
			
			out.set_pixel(x, y, c_flat.lerp(c_shift, weight))
			
	return out

func _init() -> void:
	var textures := [
		"pared_amarilla_ext",
		"pared_azul_ext",
		"pared_blanca_ext",
		"pared_cremita_ext",
		"pared_gris_ext"
	]
	
	for tex_name in textures:
		var backup_path: String = "res://assets/textures/house/" + tex_name + "_original.png"
		var path: String = "res://assets/textures/house/" + tex_name + ".png"
		
		var src_img := Image.load_from_file(ProjectSettings.globalize_path(backup_path))
		if not src_img or src_img.is_empty():
			src_img = Image.load_from_file(ProjectSettings.globalize_path(path))
			
		if src_img:
			var res := flatten_and_make_seamless(src_img)
			res.save_png(ProjectSettings.globalize_path(path))
			var s_path: String = "res://assets/textures/house/" + tex_name + "_seamless.png"
			res.save_png(ProjectSettings.globalize_path(s_path))
			print("✓ Procesada con High-Pass y Seamless continuo: ", tex_name)
			
	quit(0)
