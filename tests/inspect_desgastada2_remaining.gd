extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada2.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Let's inspect where in perfect_comp_pared_desgastada2 there are pixels with high white that are not yellow wall
	var clean := Image.load_from_file("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/clean_alpha_pared_desgastada2.png")
	
	print("Checking remaining opaque pixels with lum > 0.90 in clean_alpha_pared_desgastada2:")
	for y in range(h):
		for x in range(w):
			var cp = clean.get_pixel(x, y)
			if cp.a > 0.2:
				var l = (cp.r + cp.g + cp.b) / 3.0
				var orig = img.get_pixel(x, y)
				var orig_b = int(((orig.r + orig.g + orig.b)/3.0)*255)
				if orig_b >= 235:
					# Is this near the edge or an isolated speck?
					print("  x=%d, y=%d: orig_b=%d, alpha=%.2f" % [x, y, orig_b, cp.a])
	quit(0)
