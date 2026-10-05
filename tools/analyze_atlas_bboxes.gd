@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null:
		quit()
		return
	
	# Let's find the bounding box of the front grill/light (top-left)
	# Non-transparent pixels with y < 50, x < 100
	var min_x := 999; var max_x := -1; var min_y := 999; var max_y := -1
	for y in range(0, 50):
		for x in range(0, 100):
			var c := img.get_pixel(x, y)
			if c.a > 0.1 and not (c.r > 0.8 and c.g > 0.8 and c.b > 0.8): # exclude light grey background
				min_x = min(min_x, x); max_x = max(max_x, x)
				min_y = min(min_y, y); max_y = max(max_y, y)
	print("Front piece bbox: x=[", min_x, "..", max_x, "], y=[", min_y, "..", max_y, "]")

	# Rear piece bbox (top-right)
	min_x = 999; max_x = -1; min_y = 999; max_y = -1
	for y in range(0, 50):
		for x in range(150, 256):
			var c := img.get_pixel(x, y)
			if c.a > 0.1 and not (c.r > 0.8 and c.g > 0.8 and c.b > 0.8):
				min_x = min(min_x, x); max_x = max(max_x, x)
				min_y = min(min_y, y); max_y = max(max_y, y)
	print("Rear piece bbox: x=[", min_x, "..", max_x, "], y=[", min_y, "..", max_y, "]")

	# Side profile bbox
	min_x = 999; max_x = -1; min_y = 999; max_y = -1
	for y in range(35, 110):
		for x in range(0, 256):
			var c := img.get_pixel(x, y)
			# Find car pixels: black window, black bumper, grey body
			if c.a > 0.1 and (c.r < 0.75 or c.g < 0.75 or c.b < 0.75):
				min_x = min(min_x, x); max_x = max(max_x, x)
				min_y = min(min_y, y); max_y = max(max_y, y)
	print("Side profile bbox: x=[", min_x, "..", max_x, "], y=[", min_y, "..", max_y, "]")

	# Wheel rim bbox
	min_x = 999; max_x = -1; min_y = 999; max_y = -1
	for y in range(200, 256):
		for x in range(200, 256):
			var c := img.get_pixel(x, y)
			if c.a > 0.1 and (c.r < 0.75 or c.g < 0.75 or c.b < 0.75):
				min_x = min(min_x, x); max_x = max(max_x, x)
				min_y = min(min_y, y); max_y = max(max_y, y)
	print("Wheel rim bbox: x=[", min_x, "..", max_x, "], y=[", min_y, "..", max_y, "]")

	# Tire tread bbox
	min_x = 999; max_x = -1; min_y = 999; max_y = -1
	for y in range(200, 256):
		for x in range(140, 215):
			var c := img.get_pixel(x, y)
			if c.a > 0.1 and (c.r < 0.75 or c.g < 0.75 or c.b < 0.75):
				min_x = min(min_x, x); max_x = max(max_x, x)
				min_y = min(min_y, y); max_y = max(max_y, y)
	print("Tire tread bbox: x=[", min_x, "..", max_x, "], y=[", min_y, "..", max_y, "]")

	quit()
