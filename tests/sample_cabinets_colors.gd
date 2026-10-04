extends SceneTree

func _init() -> void:
	var img_c := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/cabinets.png"))

	print("--- COLORES DE CABINETS (256x256) ---")
	print("Esquina sup-izq (30, 30): ", img_c.get_pixel(30, 30))       # Granito
	print("Esquina sup-der (200, 30): ", img_c.get_pixel(200, 30))     # Fregadero / hueco gris?
	print("Centro-izq (40, 150): ", img_c.get_pixel(40, 150))          # Madera clara lateral
	print("Centro (115, 120): ", img_c.get_pixel(115, 120))             # Puerta de madera barnizada
	print("Der-abajo (200, 180): ", img_c.get_pixel(200, 180))         # Fregadero / tarja con desagüe

	# Detectar la división vertical entre madera lateral y puerta de madera
	for x in range(0, 200, 5):
		var px := img_c.get_pixel(x, 150)
		print("X=", x, " Color: R=", snappedf(px.r, 0.01), " G=", snappedf(px.g, 0.01), " B=", snappedf(px.b, 0.01))

	# Detectar la división horizontal entre granito superior y puertas inferiores
	for y in range(0, 150, 5):
		var px := img_c.get_pixel(115, y)
		print("Y=", y, " Color en X=115: R=", snappedf(px.r, 0.01), " G=", snappedf(px.g, 0.01), " B=", snappedf(px.b, 0.01))

	quit(0)
