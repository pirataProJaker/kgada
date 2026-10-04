extends SceneTree

func _init() -> void:
	print("Procesando textura de medidor CFE...")
	var src_path := "res://assets/textures/house/medidor_cfe.jpg"
	var out_path := "res://assets/textures/house/medidor_cfe.png"
	
	var img := Image.load_from_file(ProjectSettings.globalize_path(src_path))
	if not img or img.is_empty():
		printerr("No se pudo cargar medidor_cfe.jpg")
		quit(1)
		return
	
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	
	# El medidor está centrado aproximadamente en (195, 193.5) con radio ~188
	var center_x := float(w) * 0.5
	var center_y := float(h) * 0.5
	var radius := (float(min(w, h)) * 0.5) - 2.0
	
	print("Dimensiones: %dx%d, centro: (%.1f, %.1f), radio: %.1f" % [w, h, center_x, center_y, radius])
	
	for y in range(h):
		for x in range(w):
			var dx := float(x) + 0.5 - center_x
			var dy := float(y) + 0.5 - center_y
			var dist := sqrt(dx * dx + dy * dy)
			
			var c := img.get_pixel(x, y)
			
			# Suavizado antialiasing en el borde exterior del cristal
			if dist > radius + 1.0:
				# Totalmente fuera del círculo del medidor
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif dist >= radius - 1.0:
				# Borde antialiased
				var alpha := clampf(1.0 - (dist - (radius - 1.0)) / 2.0, 0.0, 1.0)
				# Quitar tinte blanco del fondo en el borde
				if c.r > 0.85 and c.g > 0.85 and c.b > 0.85:
					c.r = lerpf(0.65, c.r, 0.4)
					c.g = lerpf(0.67, c.g, 0.4)
					c.b = lerpf(0.70, c.b, 0.4)
				c.a = alpha
				img.set_pixel(x, y, c)
			else:
				# Dentro del medidor
				# Si algún píxel de la mera orilla es fondo blanco residual, limpiarlo
				if dist > radius - 3.0 and c.r > 0.92 and c.g > 0.92 and c.b > 0.92:
					var a := clampf((radius - dist) / 3.0, 0.0, 1.0)
					c.a = a
					img.set_pixel(x, y, c)
				else:
					c.a = 1.0
					img.set_pixel(x, y, c)
	
	var err := img.save_png(ProjectSettings.globalize_path(out_path))
	if err == OK:
		print("✓ Medidor guardado con éxito en: ", out_path)
	else:
		printerr("Error al guardar medidor_cfe.png: ", err)
	quit(0)
