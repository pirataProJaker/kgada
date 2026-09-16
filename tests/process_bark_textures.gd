extends SceneTree

func _init() -> void:
	var user_dir := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded"
	var out_dir := "res://assets/textures/foliage"
	
	print("--- PROCESANDO TEXTURAS DE CORTEZA ---")
	
	# 1. Pino: media_1789516456991.jpg -> bark_pine.png
	process_bark(user_dir + "/media_1789516456991.jpg", out_dir + "/bark_pine.png", 0.95, 1.10)
	
	# 2. Roble: media_1789516457251.jpg -> bark_oak.png
	# Se equilibra el rango para que al multiplicar con marron oscuro no se apague
	process_bark(user_dir + "/media_1789516457251.jpg", out_dir + "/bark_oak.png", 0.85, 1.25)
	
	# 3. Abedul: media_1789516457298.jpg -> bark_birch.png
	process_bark(user_dir + "/media_1789516457298.jpg", out_dir + "/bark_birch.png", 1.0, 1.0)
	
	print("--- PROCESAMIENTO DE CORTEZA COMPLETADO ---")
	quit()


func process_bark(in_path: String, out_path: String, gamma: float, gain: float) -> void:
	var src := Image.load_from_file(in_path)
	if src == null:
		printerr("No se pudo cargar corteza: ", in_path)
		return
	
	var target_size := 512 # 512x512 optimo para rendimiento VRAM
	var dest := Image.create(target_size, target_size, false, Image.FORMAT_RGB8)
	
	var src_w := src.get_width()
	var src_h := src.get_height()
	var scale_x := float(src_w) / float(target_size)
	var scale_y := float(src_h) / float(target_size)
	
	for y in range(target_size):
		var sy := int(float(y) * scale_y)
		for x in range(target_size):
			var sx := int(float(x) * scale_x)
			var p := src.get_pixel(sx, sy)
			var lum := (p.r + p.g + p.b) / 3.0
			
			# Aplicar curva tonal equilibrada
			lum = pow(lum, gamma) * gain
			lum = clampf(lum, 0.05, 1.0)
			
			dest.set_pixel(x, y, Color(lum, lum, lum, 1.0))
	
	dest.save_png(out_path)
	print("Corteza guardada: ", out_path)
