extends SceneTree

func _init() -> void:
	print("--- GENERANDO TEXTURAS RETRO PSX DE RUIDO DE PÍXEL ---")

	var dir := DirAccess.open("res://assets")
	if not dir.dir_exists("textures/roads"):
		dir.make_dir_recursive("textures/roads")

	# Tamaño retro auténtico PSX: 64x64 texels
	var tex_size := 64

	# 1. TEXTURA DE ASFALTO / PAVIMENTO (COLOR NEGRO DOMINANTE CON GRISES NEGROS)
	# Domina totalmente el negro profundo y carbón. Cero grises blancos ni motas claras.
	var img_asphalt := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var asphalt_palette := [
		Color(0.03, 0.03, 0.04), # 0: Negro profundo dominante
		Color(0.06, 0.06, 0.07), # 1: Negro alquitrán
		Color(0.10, 0.10, 0.12), # 2: Negro carbón
		Color(0.14, 0.14, 0.16), # 3: Gris negro oscuro
		Color(0.19, 0.19, 0.22), # 4: Gris asfalto oscuro
		Color(0.25, 0.25, 0.28)  # 5: Gris grafito (tono máximo, sin blancos ni grises claros)
	]

	for y in range(tex_size):
		for x in range(tex_size):
			var u := float(x) / float(tex_size)
			var v := float(y) / float(tex_size)

			# Macro-patrón orgánico continuo
			var n_macro := sin(u * TAU * 1.5) * cos(v * TAU * 1.5) * 0.15
			var h := _hash2d(x, y, 777)
			var val := h * 0.75 + (n_macro + 0.5) * 0.25

			# Distribución muy cargada hacia los negros (dominancia negra)
			var color_idx := 0
			if val < 0.35:
				color_idx = 0 # 35% Negro profundo
			elif val < 0.65:
				color_idx = 1 # 30% Negro alquitrán
			elif val < 0.82:
				color_idx = 2 # 17% Negro carbón
			elif val < 0.92:
				color_idx = 3 # 10% Gris negro oscuro
			elif val < 0.97:
				color_idx = 4 # 5% Gris asfalto
			else:
				color_idx = 5 # 3% Gris grafito sutil

			img_asphalt.set_pixel(x, y, asphalt_palette[color_idx])

	var path_asphalt := "res://assets/textures/roads/asphalt_pixel_noise.png"
	img_asphalt.save_png(path_asphalt)
	print("✓ Textura de asfalto guardada en: ", path_asphalt)

	# 2. TEXTURA DE BANQUETA (SOLO LÍNEAS TRANSVERSALES QUE PARTEN LA BANQUETA EN TRAMOS)
	# Solo tiene ranura de junta en Y (y == 0), cortando la banqueta de lado a lado.
	# En X NO hay ninguna línea (cero líneas horizontales paralelas a la calle).
	var img_sidewalk := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var sidewalk_palette := [
		Color(0.36, 0.35, 0.33),  # 0: Ranura profunda de junta transversal
		Color(0.52, 0.51, 0.49),  # 1: Bisel / sombra de junta
		Color(0.70, 0.69, 0.67),  # 2: Gris concreto base medio
		Color(0.80, 0.79, 0.77),  # 3: Concreto arena claro
		Color(0.89, 0.88, 0.86),  # 4: Tono blanco piedra
		Color(0.97, 0.96, 0.94)   # 5: Blanco brillante calcáreo
	]

	for y in range(tex_size):
		for x in range(tex_size):
			var u := float(x) / float(tex_size)
			var v := float(y) / float(tex_size)

			var n_macro := sin(u * TAU * 1.0) * cos(v * TAU * 1.0) * 0.12
			var h := _hash2d(x, y, 999)
			var val := h * 0.75 + (n_macro + 0.5) * 0.25

			var color_idx := 2
			if val < 0.15:
				color_idx = 1
			elif val < 0.40:
				color_idx = 2
			elif val < 0.70:
				color_idx = 3
			elif val < 0.90:
				color_idx = 4
			else:
				color_idx = 5

			# ÚNICAMENTE junta transversal en Y (simula partir la banqueta en tramos)
			# NUNCA en X (elimina las líneas horizontales paralelas a la calle)
			var is_groove := (y == 0)
			var is_bevel := (y == 1)
			if is_groove:
				color_idx = 0
			elif is_bevel:
				color_idx = 1

			img_sidewalk.set_pixel(x, y, sidewalk_palette[color_idx])

	var path_sidewalk := "res://assets/textures/roads/sidewalk_pixel_noise.png"
	img_sidewalk.save_png(path_sidewalk)
	print("✓ Textura de banqueta (solo juntas transversales) guardada en: ", path_sidewalk)


	# 3. TEXTURA DE BORDILLO / GUARNICIÓN (GRIS DE PIEDRA PÉTREA)
	var img_curb := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var curb_palette := [
		Color(0.38, 0.38, 0.37),
		Color(0.48, 0.48, 0.47),
		Color(0.58, 0.58, 0.57),
		Color(0.68, 0.68, 0.67),
		Color(0.78, 0.78, 0.77),
		Color(0.86, 0.86, 0.85)
	]


	for y in range(tex_size):
		for x in range(tex_size):
			var h := _hash2d(x, y, 555)
			var idx := int(h * 5.99)
			img_curb.set_pixel(x, y, curb_palette[idx])

	var path_curb := "res://assets/textures/roads/curb_pixel_noise.png"
	img_curb.save_png(path_curb)
	print("✓ Textura de bordillo guardada en: ", path_curb)

	print("--- ¡TODAS LAS TEXTURAS RETRO GENERADAS CON ÉXITO! ---")
	quit(0)


static func _hash2d(x: int, y: int, seed_val: int) -> float:
	var n: int = (x * 374761393 + y * 668265263 + seed_val * 1274126177) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	n = (n ^ (n >> 16)) & 0x7FFFFFFF
	return float(n) / 2147483647.0

