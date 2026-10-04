extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada6.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	
	print("Luminance matrix around x=[80..95], y=[35..55]:")
	var header = "   "
	for x in range(80, 96):
		header += "%3d " % x
	print(header)
	
	for y in range(35, 56):
		var line = "%2d:" % y
		for x in range(80, 96):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0) * 255.0)
			line += "%4d" % b
		print(line)
		
	quit(0)
