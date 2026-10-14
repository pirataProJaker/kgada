extends SceneTree

func _init() -> void:
	# 1. Extraer la textura original exacta de _original_military_sheet.jpg
	var sheet := Image.load_from_file("res://assets/textures/military/_original_military_sheet.jpg")
	if sheet == null:
		print("Error cargando sheet")
		quit(1)
		return

	# Row 3, Col 7: x = 896, y = 390, w = 128, h = 130
	var orig_crop := sheet.get_region(Rect2i(896, 390, 128, 130))
	orig_crop.convert(Image.FORMAT_RGBA8)
	# Redimensionar a 256x256 cuadrado
	orig_crop.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	orig_crop.save_png("res://assets/textures/military/military_tile_32_r3_c7.png")
	print("✓ Textura original restaurada y guardada en 256x256.")

	# 2. Vamos a probar diferentes zooms / escalas UV en un grid de 2x2 baldosas
	# para ver en qué escala UV las franjas conectan mejor entre baldosas contiguas
	var scales := [0.80, 0.85, 0.90, 0.95, 1.0, 1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.333, 1.40, 1.50]
	
	for s_val in scales:
		var w_out := 512
		var h_out := 512
		var test_img := Image.create(w_out, h_out, false, Image.FORMAT_RGBA8)
		
		# Simular 2x2 baldosas con UV scale = s_val
		for y in range(h_out):
			var tile_y := int(y / 256)
			var local_y := (y % 256) / 256.0
			for x in range(w_out):
				var tile_x := int(x / 256)
				var local_x := (x % 256) / 256.0
				
				# UV local escalada por zoom
				var u := fmod(local_x * s_val, 1.0)
				var v := fmod(local_y * s_val, 1.0)
				if u < 0.0: u += 1.0
				if v < 0.0: v += 1.0
				
				var px := int(u * 255.0)
				var py := int(v * 255.0)
				test_img.set_pixel(x, y, orig_crop.get_pixel(px, py))
		
		var fname := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/zoom_test_scale_%.3f.png" % s_val
		test_img.save_png(fname)
		print("Guardado: ", fname)

	quit(0)
