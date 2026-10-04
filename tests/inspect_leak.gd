extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Let's inspect the lower right quadrant (x: 80..130, y: 80..140)
	print("--- INSPECCION DE FILAS Y=90..115 EN PARED_DESGASTADA4 ---")
	for y in range(90, 115, 5):
		var line = "y=%3d: " % y
		for x in range(90, 130, 4):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0)*255.0)
			line += "%3d " % b
		print(line)
	quit(0)
