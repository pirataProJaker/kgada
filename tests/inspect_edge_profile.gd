extends SceneTree

func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/house/pared_desgastada4.png"))
	var w = img.get_width()
	var h = img.get_height()
	
	print("--- INSPECCION DE PERFIL DE BORDE (pared_desgastada4, fila y=80) ---")
	for x in range(10, 45):
		var p = img.get_pixel(x, 80)
		var b_val = int(round(((p.r + p.g + p.b) / 3.0) * 255.0))
		print("x=%2d: RGB=(%3d, %3d, %3d) lum=%3d" % [
			x, int(p.r * 255.0), int(p.g * 255.0), int(p.b * 255.0), b_val
		])
	quit(0)
