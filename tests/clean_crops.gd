extends SceneTree

func _init() -> void:
	var sheet := Image.load_from_file("res://assets/textures/military/_original_military_sheet.jpg")
	print("Sheet dimensions: ", sheet.get_width(), "x", sheet.get_height())
	
	# La hoja mide 1024x650
	# 8 columnas: 1024 / 8 = 128.0 px por columna
	# 5 filas: 650 / 5 = 130.0 px por fila
	
	# Probemos recortar exactamente dentro de la celda evitando los bordes (insets de 2-4 px si hay sangrado)
	# Celda Row 0, Col 6:
	var tile_r0_c6 := sheet.get_region(Rect2i(6 * 128 + 2, 0 * 130 + 2, 124, 126))
	tile_r0_c6.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	tile_r0_c6.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/crop_r0_c6_clean.png")

	# Celda Row 3, Col 7:
	var tile_r3_c7 := sheet.get_region(Rect2i(7 * 128 + 2, 3 * 130 + 2, 124, 126))
	tile_r3_c7.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	tile_r3_c7.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/crop_r3_c7_clean.png")
	
	print("Guardados recortes limpios sin bordes.")
	quit(0)
