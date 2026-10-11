@tool
extends SceneTree

func _init() -> void:
	for tex_name in ["washer", "dryer"]:
		var path := "res://assets/textures/furniture/%s.png" % tex_name
		var img := Image.load_from_file(path)
		if img == null:
			print("Could not load ", path)
			continue
		print("\n=== TEXTURA: ", tex_name, " (", img.get_size(), ") ===")
		
		# Let's find distinct non-white or interesting regions
		# Scan in 8x8 blocks
		var w := img.get_width()
		var h := img.get_height()
		for by in range(0, h, 16):
			var line := "Y=%3d: " % by
			for bx in range(0, w, 16):
				var px: Color = img.get_pixel(bx, by)
				if px.r > 0.95 and px.g > 0.95 and px.b > 0.95:
					line += ". " # White
				elif px.r < 0.1 and px.g < 0.1 and px.b < 0.1:
					line += "# " # Black
				elif px.b > px.r + 0.2:
					line += "B " # Blue LED
				else:
					line += "x " # Detail / Gray / Color
			print(line)
	quit(0)
