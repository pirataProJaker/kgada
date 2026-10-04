extends SceneTree

# Conversor de Grafitis: Remueve el fondo blanco y genera canal alfa limpio sin halos
func process_graffiti_transparency(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	var img := Image.load_from_file(global_path)
	if not img:
		printerr("No se pudo cargar: ", path)
		return
		
	# Respaldo original
	var backup_path := path.get_basename() + "_original.png"
	var global_backup := ProjectSettings.globalize_path(backup_path)
	if not FileAccess.file_exists(global_backup):
		img.save_png(global_backup)
		
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			# Luminancia percibida
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			
			# Curva de opacidad:
			# lum >= 0.94 -> completamente transparente (fondo blanco)
			# lum <= 0.20 -> completamente opaco (tinta negra sólida)
			# lum en medio -> degradado suave de dispersión del spray
			var alpha: float = 0.0
			if lum < 0.94:
				alpha = clampf((0.94 - lum) / 0.74, 0.0, 1.0)
				# Suavizado de bordes
				alpha = alpha * alpha * (3.0 - 2.0 * alpha)
				
			# Clave contra halos blancos: el color RGB se forza a negro carbón/tinta
			# conservando la densidad y matiz oscuro del trazo
			var spray_color := Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, alpha)
			out.set_pixel(x, y, spray_color)
			
	out.save_png(global_path)
	print("✓ Grafiti procesado con alfa transparente: ", path.get_file(), " (%dx%d)" % [w, h])

func _init() -> void:
	var graffiti_files := [
		"res://assets/textures/house/grafiti.png",
		"res://assets/textures/house/grafiti2.png",
		"res://assets/textures/house/grafiti3.png",
		"res://assets/textures/house/grafiti4.png",
		"res://assets/textures/house/grafiti5.png",
		"res://assets/textures/house/grafiti_peque.png",
		"res://assets/textures/house/grafiti_peque2.png",
		"res://assets/textures/house/grafiti_peque3.png"
	]
	
	for path in graffiti_files:
		process_graffiti_transparency(path)
		
	quit(0)
