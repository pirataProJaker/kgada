extends SceneTree

func _init() -> void:
	_analyze_toaster()
	_analyze_coffee_table()
	_analyze_washer_and_dryer()
	quit(0)

func _analyze_toaster() -> void:
	print("=== TOASTER.PNG (64x64) ===")
	var img := Image.new()
	img.load("res://assets/textures/furniture/toaster.png")
	# Check quadrants:
	# Top-left (X: 0..31, Y: 0..31)
	# Top-right (X: 32..63, Y: 0..31)
	# Bottom-left (X: 0..31, Y: 32..63)
	# Bottom-right (X: 32..63, Y: 32..63)
	# Let's inspect regions:
	# Where is the lever?
	# Where are the slots?
	for y in range(0, 64, 4):
		var line := ""
		for x in range(0, 64, 2):
			var c = img.get_pixel(x, y)
			if c.r < 0.1 and c.g < 0.1 and c.b < 0.1:
				line += "#" # Black (slots or lever)
			elif c.r > 0.7:
				line += "." # Light metal
			elif c.r > 0.4:
				line += "+" # Medium metal
			else:
				line += "-" # Dark metal
		print("%2d: %s" % [y, line])

func _analyze_coffee_table() -> void:
	print("\n=== COFFEE_TABLE.PNG (128x128) ===")
	var img := Image.new()
	img.load("res://assets/textures/furniture/coffee_table.png")
	# Detect distinct rectangular patches
	# Top-left: table surface?
	# Bottom-left: drawer front?
	# Right half: legs / structure?
	print("Pixel at (20, 20) top-left: ", img.get_pixel(20, 20))
	print("Pixel at (20, 90) bottom-left: ", img.get_pixel(20, 90))
	print("Pixel at (100, 20) top-right: ", img.get_pixel(100, 20))
	print("Pixel at (100, 90) bottom-right: ", img.get_pixel(100, 90))

func _analyze_washer_and_dryer() -> void:
	print("\n=== WASHER.PNG & DRYER.PNG (128x128) ===")
	var img_w := Image.new()
	img_w.load("res://assets/textures/furniture/washer.png")
	var img_d := Image.new()
	img_d.load("res://assets/textures/furniture/dryer.png")
	
	# Find control panel in washer:
	for y in range(20, 40):
		var has_dark := false
		for x in range(40, 90):
			var c = img_w.get_pixel(x, y)
			if c.r < 0.4 or c.b > 0.7:
				has_dark = true
		if has_dark:
			print("Washer control panel active at Y=", y)

