extends SceneTree

func _init() -> void:
	var m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/microondas.png"))
	print("--- PARTE INFERIOR DERECHA (CAVIDAD/PLATO) ---")
	print("Centro de la caja oscura (90, 110): ", m.get_pixel(90, 110))
	print("Borde superior de la caja (90, 93): ", m.get_pixel(90, 93))
	print("Borde izquierdo de la caja (61, 110): ", m.get_pixel(61, 110))
	print("Borde derecho de la caja (123, 110): ", m.get_pixel(123, 110))
	print("Borde inferior de la caja (90, 125): ", m.get_pixel(90, 125))

	for x in range(55, 127, 5):
		print("X=", x, " (Y=110): lum=", snappedf(m.get_pixel(x, 110).get_luminance(), 0.01))

	quit(0)
