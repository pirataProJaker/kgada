extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	
	print("Profile from x=0 to x=35 at y=70 in desgastada4:")
	var line = ""
	for x in range(35):
		var p = img.get_pixel(x, 70)
		var b = int(((p.r + p.g + p.b)/3.0) * 255.0)
		line += "%d " % b
	print(line)
	quit(0)
