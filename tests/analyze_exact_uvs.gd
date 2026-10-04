extends SceneTree

func _init() -> void:
	var m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/microondas.png"))
	var c := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/cabinets.png"))

	print("=== DETALLES MICROONDAS (128x128) ===")
	# Analizar columnas en Y=60 (mitad vertical de la ventana y panel)
	for x in range(50, 128):
		var p := m.get_pixel(x, 60)
		# Detectar borde entre ventana y keypad
		if x in [100, 105, 106, 107, 108, 109, 110, 111, 112, 115]:
			print("X=", x, " (ventana/panel): R=", snappedf(p.r, 0.01), " G=", snappedf(p.g, 0.01), " B=", snappedf(p.b, 0.01))

	print("\n=== DETALLES PUERTA CABINETS (256x256) ===")
	# La columna de la puerta es entre X=89 y X=159 aprox.
	# Veamos la altura en Y de la puerta y el panel interior
	for y in range(80, 256, 5):
		var p := c.get_pixel(125, y)
		print("Y=", y, " Color en X=125: R=", snappedf(p.r, 0.01), " G=", snappedf(p.g, 0.01), " B=", snappedf(p.b, 0.01))

	quit(0)
