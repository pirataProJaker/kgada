extends SceneTree

func _init() -> void:
	var img := Image.new()
	var err := img.load("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if err != OK:
		print("Failed to load image, err: ", err)
		quit()
		return
	
	var fa := FileAccess.open("c:/Users/PC 1/PSX/atlas_scan.txt", FileAccess.WRITE)
	if fa == null:
		quit()
		return
		
	fa.store_line("Image size: %d x %d" % [img.get_width(), img.get_height()])
	
	# 1. SIDE PROFILE (y: 35 to 105)
	var side_min_x: int = 999
	var side_max_x: int = -1
	var side_min_y: int = 999
	var side_max_y: int = -1
	
	for y in range(35, 105):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			var is_bg: bool = (abs(c.r - 0.84) < 0.05 and abs(c.g - 0.84) < 0.05 and abs(c.b - 0.84) < 0.05)
			if not is_bg:
				side_min_x = mini(side_min_x, x)
				side_max_x = maxi(side_max_x, x)
				side_min_y = mini(side_min_y, y)
				side_max_y = maxi(side_max_y, y)
				
	fa.store_line("Side Profile BBox: X=[%d, %d] Y=[%d, %d]" % [side_min_x, side_max_x, side_min_y, side_max_y])
	
	var arch_f_x0: int = -1
	var arch_f_x1: int = -1
	var arch_r_x0: int = -1
	var arch_r_x1: int = -1
	
	fa.store_line("\n--- Detailed Wheel Arch Cutout Scan ---")
	# Wheel arch is transparent/white background (c.r > 0.95 and c.g > 0.95 and c.b > 0.95)
	# scanning row by row at Y=75, 80, 85, 90, 95:
	for test_y in [70, 75, 80, 85, 90, 95]:
		var arch_f_min: int = -1; var arch_f_max: int = -1
		var arch_r_min: int = -1; var arch_r_max: int = -1
		for x in range(3, 253):
			var c: Color = img.get_pixel(x, test_y)
			var is_white_cutout: bool = (c.r > 0.95 and c.g > 0.95 and c.b > 0.95)
			if is_white_cutout:
				if x < 120:
					if arch_f_min == -1: arch_f_min = x
					arch_f_max = x
				else:
					if arch_r_min == -1: arch_r_min = x
					arch_r_max = x
		fa.store_line("Y=%2d: Front Arch=[%d, %d] (w=%d), Rear Arch=[%d, %d] (w=%d)" % [
			test_y, arch_f_min, arch_f_max, (arch_f_max - arch_f_min + 1) if arch_f_min != -1 else 0,
			arch_r_min, arch_r_max, (arch_r_max - arch_r_min + 1) if arch_r_min != -1 else 0
		])
	
	# Top Profile BBox (around y: 106 to 155)
	var top_min_x: int = 999
	var top_max_x: int = -1
	var top_min_y: int = 999
	var top_max_y: int = -1
	for y in range(106, 155):
		for x in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			var is_bg: bool = abs(c.r - 0.84) < 0.05 and abs(c.g - 0.84) < 0.05 and abs(c.b - 0.84) < 0.05
			if not is_bg:
				top_min_x = mini(top_min_x, x)
				top_max_x = maxi(top_max_x, x)
				top_min_y = mini(top_min_y, y)
				top_max_y = maxi(top_max_y, y)
				
	fa.store_line("\nTop Profile BBox: X=[%d, %d] Y=[%d, %d]" % [top_min_x, top_max_x, top_min_y, top_max_y])
	
	# Find front and rear windshields in top profile
	# Windshields are dark glass (c.r < 0.2)
	var wind_f_x0: int = -1
	var wind_f_x1: int = -1
	var wind_r_x0: int = -1
	var wind_r_x1: int = -1
	for x in range(top_min_x, top_max_x + 1):
		var c_mid: Color = img.get_pixel(x, 130)
		if c_mid.r < 0.2 and c_mid.g < 0.2 and c_mid.b < 0.2:
			if x < 120:
				if wind_f_x0 == -1: wind_f_x0 = x
				wind_f_x1 = x
			else:
				if wind_r_x0 == -1: wind_r_x0 = x
				wind_r_x1 = x
	# Front piece (top-left)
	var front_min_x: int = 999; var front_max_x: int = -1
	var front_min_y: int = 999; var front_max_y: int = -1
	for y in range(0, 50):
		for x in range(0, 70):
			var c: Color = img.get_pixel(x, y)
			var is_bg: bool = abs(c.r - 0.84) < 0.05 and abs(c.g - 0.84) < 0.05 and abs(c.b - 0.84) < 0.05
			if not is_bg:
				front_min_x = mini(front_min_x, x)
				front_max_x = maxi(front_max_x, x)
				front_min_y = mini(front_min_y, y)
				front_max_y = maxi(front_max_y, y)
	fa.store_line("\nFront Piece BBox: X=[%d, %d] Y=[%d, %d]" % [front_min_x, front_max_x, front_min_y, front_max_y])

	# Rear piece (top-right)
	var rear_min_x: int = 999; var rear_max_x: int = -1
	var rear_min_y: int = 999; var rear_max_y: int = -1
	for y in range(0, 50):
		for x in range(180, 256):
			var c: Color = img.get_pixel(x, y)
			var is_bg: bool = abs(c.r - 0.84) < 0.05 and abs(c.g - 0.84) < 0.05 and abs(c.b - 0.84) < 0.05
			if not is_bg:
				rear_min_x = mini(rear_min_x, x)
				rear_max_x = maxi(rear_max_x, x)
				rear_min_y = mini(rear_min_y, y)
				rear_max_y = maxi(rear_max_y, y)
	fa.store_line("Rear Piece BBox: X=[%d, %d] Y=[%d, %d]" % [rear_min_x, rear_max_x, rear_min_y, rear_max_y])

	# Wheel and Tire (bottom-right)
	var wheel_min_x: int = 999; var wheel_max_x: int = -1
	var wheel_min_y: int = 999; var wheel_max_y: int = -1
	for y in range(200, 256):
		for x in range(180, 256):
			var c: Color = img.get_pixel(x, y)
			var is_bg: bool = abs(c.r - 0.84) < 0.05 and abs(c.g - 0.84) < 0.05 and abs(c.b - 0.84) < 0.05
			if not is_bg:
				wheel_min_x = mini(wheel_min_x, x)
				wheel_max_x = maxi(wheel_max_x, x)
				wheel_min_y = mini(wheel_min_y, y)
				wheel_max_y = maxi(wheel_max_y, y)
	fa.store_line("Wheel/Tire Area BBox: X=[%d, %d] Y=[%d, %d]" % [wheel_min_x, wheel_max_x, wheel_min_y, wheel_max_y])

	fa.close()
	quit()
