extends SceneTree

func _init() -> void:
	var sheet := Image.load_from_file("res://assets/textures/military/_original_military_sheet.jpg")
	if sheet == null:
		print("Error loading sheet")
		quit(1)
		return

	# Let's test both candidate crops from the sheet:
	# Crop A: Row 0, Col 6 (x=768, y=0, w=128, h=130)
	# Crop B: Row 3, Col 7 (x=896, y=390, w=128, h=130)
	
	print("--- SWEEPING ZOOM CALIBRATION ON CROP A (Row 0, Col 6) ---")
	_sweep_crop(sheet, Rect2i(768 + 2, 0 + 2, 124, 126), "crop_r0_c6")
	
	print("\n--- SWEEPING ZOOM CALIBRATION ON CROP B (Row 3, Col 7) ---")
	_sweep_crop(sheet, Rect2i(896 + 2, 390 + 2, 124, 126), "crop_r3_c7")
	
	quit(0)

func _sweep_crop(sheet: Image, base_rect: Rect2i, prefix: String) -> void:
	var base_crop := sheet.get_region(base_rect)
	base_crop.resize(512, 512, Image.INTERPOLATE_LANCZOS) # High-res base for sampling
	
	# We test zoom levels: window size inside base_crop
	# Center is at (256, 256)
	var best_err := 999999.0
	var best_zoom := 1.0
	
	var zooms := [
		0.70, 0.75, 0.78, 0.80, 0.82, 0.84, 0.844, 0.86, 0.88, 0.90, 0.95,
		1.00, 1.05, 1.10, 1.15, 1.20, 1.24, 1.266, 1.28, 1.30, 1.35, 1.40
	]
	
	for z in zooms:
		# Window size: 256 * z
		var win_size := int(round(256.0 * z))
		var x0 := int(256 - win_size / 2)
		var y0 := int(256 - win_size / 2)
		
		# Sample tile of 256x256 from this window
		var tile := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for ty in range(256):
			var sy := int(y0 + (ty / 256.0) * win_size)
			sy = clampi(sy, 0, 511)
			for tx in range(256):
				var sx := int(x0 + (tx / 256.0) * win_size)
				sx = clampi(sx, 0, 511)
				tile.set_pixel(tx, ty, base_crop.get_pixel(sx, sy))
				
		# Measure seam discontinuity in a 2x2 repetition:
		# Across vertical seam: compare tile right edge (x=255) with tile left edge (x=0)
		# Across horizontal seam: compare tile bottom edge (y=255) with tile top edge (y=0)
		var err := 0.0
		for i in range(256):
			var c_right := tile.get_pixel(255, i)
			var c_left := tile.get_pixel(0, i)
			var c_bot := tile.get_pixel(i, 255)
			var c_top := tile.get_pixel(i, 0)
			
			var diff_h := absf(c_right.r - c_left.r) + absf(c_right.g - c_left.g) + absf(c_right.b - c_left.b)
			var diff_v := absf(c_bot.r - c_top.r) + absf(c_bot.g - c_top.g) + absf(c_bot.b - c_top.b)
			err += diff_h + diff_v
			
		err /= (256.0 * 2.0)
		print("Zoom: %0.3f | Seam Discontinuity Error: %0.4f" % [z, err])
		
		if err < best_err:
			best_err = err
			best_zoom = z
			
		# Save 3x3 repetition images for selected key zooms
		if z in [0.75, 0.80, 0.844, 0.90, 1.00, 1.15, 1.266, 1.35]:
			var repeat := Image.create(256 * 3, 256 * 3, false, Image.FORMAT_RGBA8)
			for ry in range(3):
				for rx in range(3):
					repeat.blit_rect(tile, Rect2i(0, 0, 256, 256), Vector2i(rx * 256, ry * 256))
			var out_name := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/%s_zoom_%0.3f.png" % [prefix, z]
			repeat.save_png(out_name)
			
	print(">>> BEST ZOOM FOR %s: %0.3f (Error: %0.4f)" % [prefix, best_zoom, best_err])
