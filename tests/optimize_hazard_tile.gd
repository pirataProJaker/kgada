extends SceneTree

func _init() -> void:
	var sheet := Image.load_from_file("res://assets/textures/military/_original_military_sheet.jpg")
	if sheet == null:
		print("Error loading sheet")
		quit(1)
		return

	# Crop A: Row 0, Col 6 (x=768, y=0, w=128, h=130)
	var base_crop := sheet.get_region(Rect2i(768 + 2, 0 + 2, 124, 126))
	base_crop.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	
	var best_err := 999999.0
	var best_z := 0.844
	var best_ox := 0
	var best_oy := 0
	
	for z_i in range(820, 870, 5):
		var z := z_i / 1000.0
		var win_size := int(round(256.0 * z))
		
		for ox in range(-12, 13, 2):
			for oy in range(-12, 13, 2):
				var x0 := int(256 - win_size / 2) + ox
				var y0 := int(256 - win_size / 2) + oy
				
				# Quick seam error
				var err := 0.0
				for i in range(0, 256, 4): # sample every 4th pixel for speed
					var sy_top := clampi(int(y0 + (0.0 / 256.0) * win_size), 0, 511)
					var sy_bot := clampi(int(y0 + (255.0 / 256.0) * win_size), 0, 511)
					var sx_left := clampi(int(x0 + (0.0 / 256.0) * win_size), 0, 511)
					var sx_right := clampi(int(x0 + (255.0 / 256.0) * win_size), 0, 511)
					
					var sx_i := clampi(int(x0 + (i / 256.0) * win_size), 0, 511)
					var sy_i := clampi(int(y0 + (i / 256.0) * win_size), 0, 511)
					
					var c_right := base_crop.get_pixel(sx_right, sy_i)
					var c_left := base_crop.get_pixel(sx_left, sy_i)
					var c_bot := base_crop.get_pixel(sx_i, sy_bot)
					var c_top := base_crop.get_pixel(sx_i, sy_top)
					
					err += absf(c_right.r - c_left.r) + absf(c_right.g - c_left.g) + absf(c_right.b - c_left.b)
					err += absf(c_bot.r - c_top.r) + absf(c_bot.g - c_top.g) + absf(c_bot.b - c_top.b)
					
				if err < best_err:
					best_err = err
					best_z = z
					best_ox = ox
					best_oy = oy

	print("Optimal Calibration Found:")
	print("  Zoom: ", best_z)
	print("  Offset X: ", best_ox, " px")
	print("  Offset Y: ", best_oy, " px")
	print("  Best Error: ", best_err)
	
	# Generate and save the perfectly calibrated tile
	var win_size := int(round(256.0 * best_z))
	var x0 := int(256 - win_size / 2) + best_ox
	var y0 := int(256 - win_size / 2) + best_oy
	var optimal_tile := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for ty in range(256):
		var sy := clampi(int(y0 + (ty / 256.0) * win_size), 0, 511)
		for tx in range(256):
			var sx := clampi(int(x0 + (tx / 256.0) * win_size), 0, 511)
			optimal_tile.set_pixel(tx, ty, base_crop.get_pixel(sx, sy))
			
	optimal_tile.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/hazard_tile_calibrated.png")
	
	# Render 4x4 tiled floor
	var floor_4x4 := Image.create(256 * 4, 256 * 4, false, Image.FORMAT_RGBA8)
	for fy in range(4):
		for fx in range(4):
			floor_4x4.blit_rect(optimal_tile, Rect2i(0, 0, 256, 256), Vector2i(fx * 256, fy * 256))
	floor_4x4.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/hazard_floor_4x4_calibrated.png")
	print("Saved calibrated tile and 4x4 floor.")
	quit(0)
