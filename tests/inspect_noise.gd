extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada3.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	print("Checking non-pure-white pixels in background of desgastada3:")
	var c_noise = 0
	for y in range(h):
		for x in range(w):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0) * 255.0)
			if b >= 240 and b < 248:
				# This pixel was NOT reached by flood fill because threshold was 248!
				c_noise += 1
				if c_noise <= 10:
					print("  Noise at (%d, %d): b=%d" % [x, y, b])
	print("Total pixels with byte in [240..247]: %d" % c_noise)
	quit(0)
