extends SceneTree

func _init() -> void:
	var img_r := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/refrigerador.png"))
	var img_e := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/estufa.png"))

	# Encontrar la línea vertical divisoria en refrigerador.png
	print("--- REFRIGERADOR.PNG ANALISIS ---")
	for x in range(img_r.get_width()):
		var black_count := 0
		for y in range(img_r.get_height()):
			var px := img_r.get_pixel(x, y)
			if px.r < 0.1 and px.g < 0.1 and px.b < 0.1:
				black_count += 1
		if black_count > 100:
			print("Posible línea vertical en X = ", x, " (píxeles oscuros: ", black_count, ")")

	# Encontrar la línea horizontal entre puerta de freezer y puerta principal
	for y in range(img_r.get_height()):
		var black_count := 0
		for x in range(85):
			var px := img_r.get_pixel(x, y)
			if px.r < 0.1 and px.g < 0.1 and px.b < 0.1:
				black_count += 1
		if black_count > 40:
			print("Posible línea horizontal de puerta en Y = ", y, " (píxeles oscuros: ", black_count, ")")

	print("\n--- ESTUFA.PNG ANALISIS ---")
	# Encontrar líneas divisorias en estufa.png
	for x in range(img_e.get_width()):
		var black_count := 0
		for y in range(img_e.get_height()):
			var px := img_e.get_pixel(x, y)
			if px.r < 0.1 and px.g < 0.1 and px.b < 0.1:
				black_count += 1
		if black_count > 100:
			print("Posible línea vertical en X = ", x, " (píxeles oscuros: ", black_count, ")")

	for y in range(img_e.get_height()):
		var black_count := 0
		for x in range(img_e.get_width()):
			var px := img_e.get_pixel(x, y)
			if px.r < 0.1 and px.g < 0.1 and px.b < 0.1:
				black_count += 1
		if black_count > 100:
			print("Posible línea horizontal en Y = ", y, " (píxeles oscuros: ", black_count, ")")

	quit(0)
