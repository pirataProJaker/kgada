extends SceneTree

func _init() -> void:
	var c := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/cabinets.png"))

	print("--- GRANITO EN CABINETS.PNG ---")
	# Encontrar dónde termina el granito a la derecha (eje X)
	for x in range(140, 180):
		var p := c.get_pixel(x, 40)
		print("X=", x, " (Y=40): R=", snappedf(p.r, 0.01), " G=", snappedf(p.g, 0.01), " B=", snappedf(p.b, 0.01))

	# Encontrar dónde termina el granito abajo (eje Y)
	for y in range(70, 105):
		var p := c.get_pixel(40, y)
		print("Y=", y, " (X=40): R=", snappedf(p.r, 0.01), " G=", snappedf(p.g, 0.01), " B=", snappedf(p.b, 0.01))

	quit(0)
