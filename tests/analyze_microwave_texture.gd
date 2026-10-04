extends SceneTree

func _init() -> void:
	var m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/microondas.png"))
	var w := m.get_width()
	var h := m.get_height()
	print("Microondas dims: ", w, "x", h)

	# 1. Analizar la línea horizontal divisoria (Y)
	for y in range(h):
		var black_count := 0
		for x in range(w):
			var c := m.get_pixel(x, y)
			if c.r < 0.1 and c.g < 0.1 and c.b < 0.1:
				black_count += 1
		if black_count > 40:
			print("Divisoria horizontal en Y=", y, " (black=", black_count, ")")

	# 2. Analizar líneas verticales (X)
	for x in range(w):
		var black_count := 0
		for y in range(h):
			var c := m.get_pixel(x, y)
			if c.r < 0.1 and c.g < 0.1 and c.b < 0.1:
				black_count += 1
		if black_count > 25:
			print("Divisoria vertical en X=", x, " (black=", black_count, ")")

	quit(0)
