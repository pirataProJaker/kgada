@tool
extends SceneTree

func _init() -> void:
	var path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790292662399.jpg"
	var img = Image.load_from_file(path)
	if not img:
		print("Failed to load image!")
		quit()
		return
	
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	print("New bough atlas image loaded: ", w, "x", h)
	
	# Analyze each quadrant (512x512 if 1024x1024)
	var half_w = w / 2
	var half_h = h / 2
	
	for q in range(4):
		var col = q % 2
		var row = q / 2
		var ox = col * half_w
		var oy = row * half_h
		
		# Find stem base (lowest and leftmost dark pixels in quadrant)
		var min_x = half_w
		var min_y = half_h
		var max_x = 0
		var max_y = 0
		var stem_px := Vector2i(-1, -1)
		var lowest_stem_y = 0
		
		for ly in range(half_h):
			var y = oy + ly
			for lx in range(half_w):
				var x = ox + lx
				var c = img.get_pixel(x, y)
				var lum = (c.r + c.g + c.b) / 3.0
				if lum < 0.90: # non-white pixel
					min_x = mini(min_x, lx)
					min_y = mini(min_y, ly)
					max_x = maxi(max_x, lx)
					max_y = maxi(max_y, ly)
					
					# Look for the thick bark stem in the bottom-left area
					if lx < half_w * 0.35 and ly > half_h * 0.65 and lum < 0.35:
						if ly >= lowest_stem_y:
							lowest_stem_y = ly
							stem_px = Vector2i(lx, ly)
		
		print("Quadrant ", q, " (row=", row, " col=", col, "): bounds=[", min_x, "..", max_x, "] x [", min_y, "..", max_y, "], stem_base=", stem_px)
	
	quit()
