extends SceneTree

func _init() -> void:
	var path1 = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527137.png"
	var path2 = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527145.png"

	for idx in range(2):
		var path = path1 if idx == 0 else path2
		var img = Image.load_from_file(path)
		var w = img.get_width()
		var h = img.get_height()
		
		var out_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		
		var num_transparent = 0
		var num_opaque = 0
		var num_semi = 0
		
		for x in range(w):
			for y in range(h):
				var c = img.get_pixel(x, y)
				# Check if white background:
				# Distance from pure white (1, 1, 1):
				var max_val = max(c.r, max(c.g, c.b))
				var min_val = min(c.r, min(c.g, c.b))
				var saturation = (max_val - min_val) / max(max_val, 0.001)
				var brightness = (c.r + c.g + c.b) / 3.0
				
				var alpha = 1.0
				# Clean up cut base edge fringe (leftmost border)
				if x < 10 and brightness > 0.60 and saturation < 0.10:
					alpha = 0.0
					num_transparent += 1
				elif brightness > 0.985 and saturation < 0.02:
					alpha = 0.0
					num_transparent += 1
				elif brightness > 0.92 and saturation < 0.08:
					# Soft anti-aliased edge transition
					var t = (brightness - 0.92) / (0.985 - 0.92)
					alpha = clamp(1.0 - t, 0.0, 1.0)
					num_semi += 1
				else:
					num_opaque += 1
				
				# Un-premultiply or un-whiten edges:
				var r = c.r
				var g = c.g
				var b = c.b
				if alpha < 0.99 and alpha > 0.01:
					r = clamp((r - (1.0 - alpha)) / alpha, 0.0, 1.0)
					g = clamp((g - (1.0 - alpha)) / alpha, 0.0, 1.0)
					b = clamp((b - (1.0 - alpha)) / alpha, 0.0, 1.0)
				
				out_img.set_pixel(x, y, Color(r, g, b, alpha))
		
		var save_path = "res://assets/vegetation/alnus/alnus_full_bough_%d.png" % (idx + 1)
		out_img.save_png(save_path)
		print("Saved: %s (Transparent: %d, Semi: %d, Opaque: %d)" % [save_path, num_transparent, num_semi, num_opaque])
	quit(0)
