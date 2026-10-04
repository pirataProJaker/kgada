extends SceneTree

# Algoritmo Profesional de Texturas Seamless (Bordes Espejados con Hermite)
# 1. Filtro Paso-Alto (High-Pass): Normaliza la iluminación para que no haya zonas claras/oscuras.
# 2. Fundido Hermite en Márgenes: Funde gradualmente el borde izquierdo con el derecho
#    y el borde superior con el inferior ÚNICAMENTE en los márgenes exteriores.
#    El centro de la imagen permanece 100% limpio y libre de costuras o cruces.

func make_clean_seamless(src_img: Image) -> Image:
	var w := src_img.get_width()
	var h := src_img.get_height()
	
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.blit_rect(src_img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	
	# --- PASO 1: HIGHPASS / APLANADO DE ILUMINACIÓN SUAVE ---
	var sum_r: float = 0.0
	var sum_g: float = 0.0
	var sum_b: float = 0.0
	var total: float = float(w * h)
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			sum_r += c.r
			sum_g += c.g
			sum_b += c.b
	var mean_col := Color(sum_r / total, sum_g / total, sum_b / total, 1.0)
	
	# Desenfocado de baja frecuencia
	var rad := 12
	var flat := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var br: float = 0.0
			var bg: float = 0.0
			var bb: float = 0.0
			var count: int = 0
			for dy in range(-rad, rad + 1, 2):
				var sy = clampi(y + dy, 0, h - 1)
				for dx in range(-rad, rad + 1, 2):
					var sx = clampi(x + dx, 0, w - 1)
					var pc := img.get_pixel(sx, sy)
					br += pc.r
					bg += pc.g
					bb += pc.b
					count += 1
			var orig_c := img.get_pixel(x, y)
			var blur_c := Color(br / float(count), bg / float(count), bb / float(count))
			# Highpass suave (80% aplanado, 20% contraste natural)
			var r := clampf(orig_c.r - (blur_c.r - mean_col.r) * 0.85, 0.0, 1.0)
			var g := clampf(orig_c.g - (blur_c.g - mean_col.g) * 0.85, 0.0, 1.0)
			var b := clampf(orig_c.b - (blur_c.b - mean_col.b) * 0.85, 0.0, 1.0)
			flat.set_pixel(x, y, Color(r, g, b, 1.0))
			
	# --- PASO 2: FUNDIDO BIDIRECCIONAL EN BORDES (Seamless Margin Blend) ---
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mx: int = w / 4 # Margen del 25% en X
	var my: int = h / 4 # Margen del 25% en Y
	
	for y in range(h):
		# Factor Y: cuánto peso tiene el borde opuesto vertical
		var wy: float = 0.0
		var opp_y: int = y
		if y < my:
			var t := float(y) / float(my)
			# En y=0, peso 0.5; en y=my, peso 0.0
			wy = (1.0 - t * t * (3.0 - 2.0 * t)) * 0.5
			opp_y = h - 1 - (my - 1 - y)
		elif y >= h - my:
			var t := float(h - 1 - y) / float(my)
			wy = (1.0 - t * t * (3.0 - 2.0 * t)) * 0.5
			opp_y = (h - 1 - y)
			
		for x in range(w):
			# Factor X: cuánto peso tiene el borde opuesto horizontal
			var wx: float = 0.0
			var opp_x: int = x
			if x < mx:
				var t := float(x) / float(mx)
				wx = (1.0 - t * t * (3.0 - 2.0 * t)) * 0.5
				opp_x = w - 1 - (mx - 1 - x)
			elif x >= w - mx:
				var t := float(w - 1 - x) / float(mx)
				wx = (1.0 - t * t * (3.0 - 2.0 * t)) * 0.5
				opp_x = (w - 1 - x)
				
			var c_curr := flat.get_pixel(x, y)
			var c_opp_x := flat.get_pixel(opp_x, y)
			var c_opp_y := flat.get_pixel(x, opp_y)
			var c_opp_xy := flat.get_pixel(opp_x, opp_y)
			
			# Interpolación bilineal de los bordes opuestos
			var c_blend := c_curr * (1.0 - wx) * (1.0 - wy) \
						 + c_opp_x * wx * (1.0 - wy) \
						 + c_opp_y * (1.0 - wx) * wy \
						 + c_opp_xy * wx * wy
						
			out.set_pixel(x, y, c_blend)
			
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
			var res := make_clean_seamless(src_img)
			res.save_png(ProjectSettings.globalize_path(path))
			var s_path: String = "res://assets/textures/house/" + tex_name + "_seamless.png"
			res.save_png(ProjectSettings.globalize_path(s_path))
			print("✓ Generada textura seamless limpia sin costuras cruzadas: ", tex_name)
			
	quit(0)
