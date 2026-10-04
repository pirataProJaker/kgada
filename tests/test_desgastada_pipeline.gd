extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	print("=== PIPELINE DE PRUEBA PARA PARED DESGASTADA ===")
	
	# Probemos con pared_desgastada2, pared_desgastada3 y pared_desgastada4
	for file_name in ["pared_desgastada2.png", "pared_desgastada3.png", "pared_desgastada4.png", "pared_desgastada6.png", "pintura_desgastada.png"]:
		var path = "res://assets/textures/house/" + file_name
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if not img:
			continue
		var w = img.get_width()
		var h = img.get_height()
		
		# Metodo: Flood-fill desde el perimetro para encontrar el fondo exterior
		# Umbral de fondo: píxeles muy claros conectados al borde exterior
		# Para evitar fugas por grietas diminutas, analicemos el umbral óptimo
		var bg_mask := _compute_background_mask(img, w, h)
		
		# Crear imagen RGBA con transparencia procesada
		var result := Image.create(w, h, false, Image.FORMAT_RGBA8)
		
		# También crearemos una imagen compuesta sobre fondo amarillo para verificación visual
		var comp_yellow := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var wall_color := Color(0.85, 0.72, 0.40, 1.0) # Amarillo estuco
		
		for y in range(h):
			for x in range(w):
				var p = img.get_pixel(x, y)
				var lum = (p.r + p.g + p.b) / 3.0
				var is_bg = bg_mask[y * w + x]
				
				var alpha := 1.0
				if is_bg:
					alpha = 0.0
					
				# Si no es fondo (es detalle interior), alpha debe ser 1.0, 
				# preservando completamente el gris casi blanco y los detalles
				var out_color := Color(p.r, p.g, p.b, alpha)
				result.set_pixel(x, y, out_color)
				
				# Componer sobre el color de pared
				var blended = wall_color.lerp(Color(p.r, p.g, p.b, 1.0), alpha)
				comp_yellow.set_pixel(x, y, blended)
				
		var base = file_name.get_basename()
		comp_yellow.save_png(ARTIFACT_DIR + "/comp_yellow_" + base + ".png")
		print("Guardado: comp_yellow_%s.png" % base)
		
	quit(0)

func _compute_background_mask(img: Image, w: int, h: int) -> Array:
	var mask := []
	mask.resize(w * h)
	mask.fill(false)
	
	# Paso 1: Flood fill desde los 4 bordes con umbral alto (>= 248)
	var queue := []
	var thresh = 248.0 / 255.0
	
	for x in range(w):
		for y in [0, h - 1]:
			var idx = y * w + x
			var p = img.get_pixel(x, y)
			if (p.r + p.g + p.b) / 3.0 >= thresh:
				mask[idx] = true
				queue.append(Vector2i(x, y))
	for y in range(1, h - 1):
		for x in [0, w - 1]:
			var idx = y * w + x
			var p = img.get_pixel(x, y)
			if (p.r + p.g + p.b) / 3.0 >= thresh:
				mask[idx] = true
				queue.append(Vector2i(x, y))
				
	var head = 0
	while head < queue.size():
		var curr = queue[head]
		head += 1
		for n in [Vector2i(curr.x+1, curr.y), Vector2i(curr.x-1, curr.y), Vector2i(curr.x, curr.y+1), Vector2i(curr.x, curr.y-1)]:
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
				var idx = n.y * w + n.x
				if not mask[idx]:
					var p = img.get_pixel(n.x, n.y)
					var lum = (p.r + p.g + p.b) / 3.0
					if lum >= thresh:
						mask[idx] = true
						queue.append(n)
						
	return mask
