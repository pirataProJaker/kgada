extends SceneTree

func make_seamless(src_img: Image, blend_ratio: float = 0.25) -> Image:
	var w := src_img.get_width()
	var h := src_img.get_height()
	
	# Aseguramos formato RGBA8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.blit_rect(src_img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	
	var half_w := w / 2
	var half_h := h / 2
	var blend_w := int(float(w) * blend_ratio)
	var blend_h := int(float(h) * blend_ratio)
	
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# 1. Copiar con desplazamiento de medio ancho y medio alto (Wrap Offset)
	for y in range(h):
		for x in range(w):
			var src_x = (x + half_w) % w
			var src_y = (y + half_h) % h
			out.set_pixel(x, y, img.get_pixel(src_x, src_y))
			
	# 2. Mezclar suavemente la costura vertical en el centro (alrededor de half_w)
	var hw_start := half_w - blend_w / 2
	var hw_end := half_w + blend_w / 2
	for y in range(h):
		for x in range(hw_start, hw_end):
			var t := float(x - hw_start) / float(blend_w)
			# Curva suave hermite (smoothstep)
			var factor := t * t * (3.0 - 2.0 * t)
			
			var c1 = out.get_pixel(x, y)
			# Muestrear el lado opuesto simétrico correspondiente del original
			var orig_left_x = (x - half_w + w) % w
			var orig_right_x = (x + half_w) % w
			var src_y = (y + half_h) % h
			
			var col_a = img.get_pixel(orig_left_x, src_y)
			var col_b = img.get_pixel(orig_right_x, src_y)
			var blended = col_a.lerp(col_b, factor)
			out.set_pixel(x, y, blended)
			
	# 3. Mezclar suavemente la costura horizontal en el centro (alrededor de half_h)
	var hh_start := half_h - blend_h / 2
	var hh_end := half_h + blend_h / 2
	for y in range(hh_start, hh_end):
		var t := float(y - hh_start) / float(blend_h)
		var factor := t * t * (3.0 - 2.0 * t)
		for x in range(w):
			var col_curr = out.get_pixel(x, y)
			var mirror_y = (y + half_h) % h
			var col_opp = out.get_pixel(x, mirror_y)
			var blended = col_curr.lerp(col_opp, factor * 0.5)
			out.set_pixel(x, y, blended)
			
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
		var path: String = "res://assets/textures/house/" + tex_name + ".png"
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			var seamless_img := make_seamless(img, 0.28)
			var out_path: String = "res://assets/textures/house/" + tex_name + "_seamless.png"
			seamless_img.save_png(ProjectSettings.globalize_path(out_path))
			print("✓ Generada textura seamless: ", out_path)
	
	quit(0)
