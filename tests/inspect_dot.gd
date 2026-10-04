extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada2.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	
	print("Crop around (15, 50):")
	for y in range(48, 53):
		var line = "y=%d: " % y
		for x in range(12, 18):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0)*255)
			line += "%3d " % b
		print(line)
	quit(0)
