extends SceneTree

func _init() -> void:
	var img_m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/microondas.png"))
	var img_c := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/cabinets.png"))

	print("--- ANALISIS MICROONDAS (128x128) ---")
	# Buscar líneas negras
	for x in range(img_m.get_width()):
		var black := 0
		for y in range(img_m.get_height()):
			var c := img_m.get_pixel(x, y)
			if c.r < 0.15 and c.g < 0.15 and c.b < 0.15:
				black += 1
		if black > 15:
			print("Línea vertical en X = ", x, " (negros: ", black, ")")

	for y in range(img_m.get_height()):
		var black := 0
		for x in range(img_m.get_width()):
			var c := img_m.get_pixel(x, y)
			if c.r < 0.15 and c.g < 0.15 and c.b < 0.15:
				black += 1
		if black > 15:
			print("Línea horizontal en Y = ", y, " (negros: ", black, ")")

	print("\n--- ANALISIS CABINETS (256x256) ---")
	for x in range(img_c.get_width()):
		var black := 0
		for y in range(img_c.get_height()):
			var c := img_c.get_pixel(x, y)
			if c.r < 0.15 and c.g < 0.15 and c.b < 0.15:
				black += 1
		if black > 30:
			print("Línea vertical en X = ", x, " (negros: ", black, ")")

	for y in range(img_c.get_height()):
		var black := 0
		for x in range(img_c.get_width()):
			var c := img_c.get_pixel(x, y)
			if c.r < 0.15 and c.g < 0.15 and c.b < 0.15:
				black += 1
		if black > 30:
			print("Línea horizontal en Y = ", y, " (negros: ", black, ")")

	quit(0)
