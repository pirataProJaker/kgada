@tool
extends SceneTree

func _init() -> void:
	print("--- GENERADOR DE TEXTURAS FOTORREALISTAS PARA ALNUS ACUMINATA ---")
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("assets/vegetation/alnus"):
		dir.make_dir_recursive("assets/vegetation/alnus")
	
	generate_photoreal_bark("res://assets/vegetation/alnus/alnus_bark.png")
	generate_photoreal_foliage("res://assets/vegetation/alnus/alnus_leaf_cluster.png")
	
	print("✓ Nuevas texturas botánicas generadas exitosamente.")
	quit(0)

func generate_photoreal_bark(path: String) -> void:
	var w = 512
	var h = 512
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Color de corteza del árbol de referencia:
	# Pardo-grisáceo carbón con fisuras verticales finas y tono leñoso oscuro
	var col_base = Color(0.24, 0.21, 0.18, 1.0)
	var col_deep_fissure = Color(0.12, 0.10, 0.08, 1.0)
	var col_lenticel = Color(0.42, 0.38, 0.32, 1.0)
	var col_moss = Color(0.26, 0.27, 0.17, 1.0)
	
	for y in range(h):
		for x in range(w):
			var nx = float(x) / float(w) * TAU
			var ny = float(y) / float(h) * TAU
			
			# Vetas verticales profundas y orgánicas (seamless en X e Y)
			var grain1 = sin(nx * 18.0 + sin(ny * 6.0) * 1.8) * 0.12
			var grain2 = sin(nx * 36.0 + cos(ny * 12.0) * 1.2) * 0.06
			var micro = sin(nx * 64.0) * cos(ny * 32.0) * 0.04
			
			# Fisuras verticales oscuras
			var fissure_val = fmod(float(x) + sin(float(y) * 0.15) * 4.0, 16.0)
			var is_fissure = fissure_val < 2.2
			
			# Lenticelas y marcas transversales
			var lenticel_val = fmod(float(y), 18.0) < 2.0 and fmod(float(x) + float(y) * 0.5, 14.0) < 6.0
			
			# Tono base modulado
			var col = col_base
			var lum = grain1 + grain2 + micro
			col.r += lum * 0.8
			col.g += lum * 0.75
			col.b += lum * 0.65
			
			if is_fissure:
				col = col.lerp(col_deep_fissure, 0.65)
			elif lenticel_val:
				col = col.lerp(col_lenticel, 0.45)
				
			# Toque sutil de musgo en la base del tronco
			if (sin(nx * 4.0) * cos(ny * 2.0)) > 0.6:
				col = col.lerp(col_moss, 0.25)
			
			col.r = clampf(col.r, 0.08, 0.55)
			col.g = clampf(col.g, 0.07, 0.52)
			col.b = clampf(col.b, 0.05, 0.45)
			img.set_pixel(x, y, col)
	
	img.save_png(path)
	print("  - Corteza fotorrealista guardada en: ", path)

func generate_photoreal_foliage(path: String) -> void:
	var w = 256
	var h = 256
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # Fondo transparente
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 9876543
	
	# Esqueleto de ramitas de soporte leñoso
	var center_stem_base = Vector2(128, 245)
	var center_stem_tip = Vector2(128, 75)
	var col_wood = Color(0.26, 0.19, 0.14, 1.0)
	
	draw_twig(img, center_stem_base, center_stem_tip, col_wood, 3.0)
	
	# Ramitas laterales
	var branches = [
		{"from": Vector2(128, 205), "to": Vector2(50, 160)},
		{"from": Vector2(128, 200), "to": Vector2(206, 160)},
		{"from": Vector2(128, 155), "to": Vector2(40, 105)},
		{"from": Vector2(128, 150), "to": Vector2(216, 105)},
		{"from": Vector2(128, 110), "to": Vector2(65, 55)},
		{"from": Vector2(128, 105), "to": Vector2(190, 55)},
		{"from": Vector2(128, 75), "to": Vector2(128, 30)},
	]
	for b in branches:
		draw_twig(img, b["from"], b["to"], col_wood, 2.0)
	
	# Generar nube de 55 a 65 hojas densas, superpuestas en capas:
	# Capa 1: Hojas interiores oscuras / sombra
	# Capa 2: Hojas intermedias verde bosque
	# Capa 3: Hojas exteriores soleadas verde oliva
	var leaf_nodes = []
	
	# Hojas apicales superiores
	for i in range(8):
		var pos = Vector2(128 + rng.randf_range(-35, 35), 45 + rng.randf_range(-25, 35))
		var angle = -PI * 0.5 + rng.randf_range(-0.5, 0.5)
		leaf_nodes.append({"pos": pos, "angle": angle, "scale": rng.randf_range(16.0, 22.0), "layer": 1})
	
	# Hojas laterales y centrales
	for b in branches:
		var start: Vector2 = b["from"]
		var end: Vector2 = b["to"]
		var count = 5
		for k in range(count):
			var t = float(k + 1) / float(count + 1)
			var base_pos = start.lerp(end, t) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
			var dir_angle = (end - start).angle() + rng.randf_range(-0.6, 0.6)
			
			# Hoja izquierda
			leaf_nodes.append({
				"pos": base_pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)),
				"angle": dir_angle - 0.4 + rng.randf_range(-0.3, 0.3),
				"scale": rng.randf_range(16.0, 24.0),
				"layer": rng.randi_range(0, 2)
			})
			# Hoja derecha
			leaf_nodes.append({
				"pos": base_pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)),
				"angle": dir_angle + 0.4 + rng.randf_range(-0.3, 0.3),
				"scale": rng.randf_range(16.0, 24.0),
				"layer": rng.randi_range(0, 2)
			})
	
	# Ordenar por capa para profundidad
	leaf_nodes.sort_custom(func(a, b): return a["layer"] < b["layer"])
	
	for leaf in leaf_nodes:
		draw_realistic_alnus_leaf(img, leaf["pos"], leaf["angle"], leaf["scale"], leaf["layer"])
	
	# Agregar pequeños amentillos colgantes (alder catkins) típicos del Alnus acuminata
	var catkins = [
		Vector2(60, 175), Vector2(195, 170),
		Vector2(55, 120), Vector2(205, 115),
		Vector2(115, 80), Vector2(145, 75)
	]
	for c_pos in catkins:
		draw_catkin(img, c_pos, rng.randf_range(12.0, 18.0))
		
	img.save_png(path)
	print("  - Follaje fotorrealista denso guardado en: ", path)

func draw_twig(img: Image, from: Vector2, to: Vector2, col: Color, thickness: float) -> void:
	var dist = from.distance_to(to)
	var steps = int(dist * 2.0)
	var half_t = int(round(thickness * 0.5))
	
	for s in range(steps):
		var t = float(s) / float(steps)
		var p = from.lerp(to, t)
		var px = int(round(p.x))
		var py = int(round(p.y))
		for ox in range(-half_t, half_t + 1):
			for oy in range(-half_t, half_t + 1):
				var x = px + ox
				var y = py + oy
				if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, col)

func draw_realistic_alnus_leaf(img: Image, origin: Vector2, angle: float, length: float, layer: int) -> void:
	var width = length * 0.68
	var cos_a = cos(angle)
	var sin_a = sin(angle)
	var perp_cos = -sin_a
	var perp_sin = cos_a
	
	# Paleta calibrada con la foto real de referencia:
	# Capa 0 (Interior/Sombra): Verde oscuro profundo bosque
	# Capa 1 (Intermedia): Verde hoja fresco
	# Capa 2 (Exterior soleado): Verde oliva brillante con luz dorada
	var col_shade: Color
	var col_sun: Color
	var col_vein: Color
	var col_edge: Color
	
	if layer == 0:
		col_shade = Color(0.12, 0.22, 0.08, 1.0)
		col_sun = Color(0.22, 0.38, 0.14, 1.0)
		col_vein = Color(0.28, 0.44, 0.18, 1.0)
		col_edge = Color(0.09, 0.18, 0.06, 1.0)
	elif layer == 1:
		col_shade = Color(0.20, 0.38, 0.14, 1.0)
		col_sun = Color(0.36, 0.58, 0.22, 1.0)
		col_vein = Color(0.48, 0.68, 0.28, 1.0)
		col_edge = Color(0.16, 0.30, 0.10, 1.0)
	else:
		col_shade = Color(0.30, 0.50, 0.18, 1.0)
		col_sun = Color(0.50, 0.70, 0.26, 1.0) # Toque soleado dorado
		col_vein = Color(0.62, 0.80, 0.36, 1.0)
		col_edge = Color(0.22, 0.38, 0.12, 1.0)
	
	var steps_l = int(length)
	for l in range(steps_l):
		var t = float(l) / float(steps_l) # 0.0 (peciolo) a 1.0 (ápice acuminado)
		# Forma ovada / acuminada auténtica de Alnus acuminata
		var w_factor = sin(pow(t, 0.75) * PI) * (1.0 - t * 0.3)
		var half_w = int(round(width * 0.5 * w_factor))
		
		var center_pt = origin + Vector2(cos_a, sin_a) * float(l)
		
		for w in range(-half_w, half_w + 1):
			var pt = center_pt + Vector2(perp_cos, perp_sin) * float(w)
			var px = int(round(pt.x))
			var py = int(round(pt.y))
			
			if px < 0 or px >= img.get_width() or py < 0 or py >= img.get_height():
				continue
			
			var is_edge = (abs(w) == half_w)
			var is_vein = (w == 0) or (abs(w) > 1 and fmod(float(l) * 2.0 + float(w), 5.0) < 1.0)
			
			var pixel_col: Color
			if is_edge:
				pixel_col = col_edge
			elif is_vein:
				pixel_col = col_vein
			else:
				var light_bias = (float(w) / float(half_w + 1)) * 0.5 + 0.5
				pixel_col = col_shade.lerp(col_sun, light_bias)
			
			img.set_pixel(px, py, pixel_col)

func draw_catkin(img: Image, pos: Vector2, len: float) -> void:
	var col1 = Color(0.34, 0.24, 0.16, 1.0)
	var col2 = Color(0.48, 0.36, 0.22, 1.0)
	var steps = int(len)
	for s in range(steps):
		var y = int(pos.y) + s
		var x = int(pos.x)
		var w = 1 if (s == 0 or s == steps - 1) else 2
		for ox in range(-w, w + 1):
			var px = x + ox
			if px >= 0 and px < img.get_width() and y >= 0 and y < img.get_height():
				var c = col1 if (s % 2 == 0) else col2
				img.set_pixel(px, y, c)
