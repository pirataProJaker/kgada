extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada2.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Load clean_alpha_pared_desgastada2.png
	var clean := Image.load_from_file("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/clean_alpha_pared_desgastada2.png")
	
	print("Checking opaque near-white pixels in clean_alpha_pared_desgastada2:")
	var count = 0
	for y in range(h):
		for x in range(w):
			var cp = clean.get_pixel(x, y)
			if cp.a > 0.5:
				var orig = img.get_pixel(x, y)
				var b = int(((orig.r + orig.g + orig.b)/3.0)*255)
				if b >= 245:
					count += 1
					if count <= 15:
						print("  Opaque white at (%d, %d): b=%d, alpha=%.2f" % [x, y, b, cp.a])
	print("Total opaque near-white pixels: %d" % count)
	quit(0)
