extends SceneTree

func make_perfect_seamless(src_img: Image) -> Image:
	var w := src_img.get_width()
	var h := src_img.get_height()
	
	var orig := Image.create(w, h, false, Image.FORMAT_RGBA8)
	orig.blit_rect(src_img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	
	var half_w := w / 2
	var half_h := h / 2
	
	# 1. Imagen desplazada (shifted)
	var shifted := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var sx = (x + half_w) % w
			var sy = (y + half_h) % h
			shifted.set_pixel(x, y, orig.get_pixel(sx, sy))
			
	# 2. Mezcla con máscara hacia los bordes
	# En los bordes (dist grande) -> 100% shifted (tiling perfecto sin costuras)
	# En el centro (dist pequeño) -> 100% original (tapa las costuras de shifted)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for y in range(h):
		var ny := absf(float(y - half_h)) / float(half_h) # 0 en centro, 1 en borde
		for x in range(w):
			var nx := absf(float(x - half_w)) / float(half_w) # 0 en centro, 1 en borde
			
			# Distancia manhattan suave al borde
			var d := maxf(nx, ny)
			
			# Smoothstep entre 0.35 y 0.65
			var t := clampf((d - 0.35) / 0.30, 0.0, 1.0)
			var weight_shifted := t * t * (3.0 - 2.0 * t)
			
			var c_orig := orig.get_pixel(x, y)
			var c_shift := shifted.get_pixel(x, y)
			
			var final_col := c_orig.lerp(c_shift, weight_shifted)
			out.set_pixel(x, y, final_col)
			
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
			# Guardamos una copia de respaldo si no existe
			var backup_path: String = "res://assets/textures/house/" + tex_name + "_original.png"
			if not FileAccess.file_exists(backup_path):
				img.save_png(ProjectSettings.globalize_path(backup_path))
			
			var seamless := make_perfect_seamless(img)
			# Guardamos sobre el archivo principal y sobre el seamless
			seamless.save_png(ProjectSettings.globalize_path(path))
			var s_path: String = "res://assets/textures/house/" + tex_name + "_seamless.png"
			seamless.save_png(ProjectSettings.globalize_path(s_path))
			print("✓ Procesada textura seamless perfecta: ", tex_name)
			
	quit(0)
