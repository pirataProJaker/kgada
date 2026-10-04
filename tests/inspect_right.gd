extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	
	print("Matrix around x=[135..155], y=[55..65]:")
	for y in range(55, 66):
		var line = "y=%d: " % y
		for x in range(135, 156):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0)*255)
			line += "%d " % b
		print(line)
		
	quit(0)
