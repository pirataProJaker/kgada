extends SceneTree

func _init() -> void:
	for name in ["pared_desgastada2.png", "pared_desgastada4.png", "pared_desgastada6.png"]:
		var path = "res://assets/textures/house/" + name
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var w = img.get_width()
		var h = img.get_height()
		
		# Compute gradient magnitude (Sobel or simple diff)
		var grad := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in range(h):
			for x in range(w):
				var p = img.get_pixel(x, y)
				var l = (p.r + p.g + p.b) / 3.0
				
				var lx = (img.get_pixel(clampi(x+1, 0, w-1), y).r - img.get_pixel(clampi(x-1, 0, w-1), y).r) * 0.5
				var ly = (img.get_pixel(x, clampi(y+1, 0, h-1)).r - img.get_pixel(x, clampi(y-1, 0, h-1)).r) * 0.5
				var g = sqrt(lx*lx + ly*ly)
				
				grad.set_pixel(x, y, Color(g * 3.0, g * 3.0, g * 3.0, 1.0))
				
		var base = name.get_basename()
		grad.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/grad_" + base + ".png")
		print("Saved grad_%s.png" % base)
		
	quit(0)
