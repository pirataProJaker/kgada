extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada6.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	
	print("Matrix of desgastada6 around x=[50..70], y=[50..70]:")
	for y in range(50, 71, 2):
		var line = "y=%2d: " % y
		for x in range(50, 71, 2):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0)*255)
			line += "%3d " % b
		print(line)
		
	quit(0)
