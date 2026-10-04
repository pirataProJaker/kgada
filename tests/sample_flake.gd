extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	
	# Sample pixels inside the left flake, say x=35, y=70
	print("Sample pixels in left flake of desgastada4:")
	for y in range(65, 80, 2):
		var line = "y=%d: " % y
		for x in range(30, 45, 2):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0) * 255.0)
			line += "%d " % b
		print(line)
		
	quit(0)
