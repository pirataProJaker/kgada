@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null:
		quit()
		return
	
	print("--- FRONT PIECE (x: 10..65, y: 15..45) ---")
	for y in [17, 20, 25, 30, 33, 38, 43]:
		var s := "y=%2d: " % y
		for x in range(12, 60, 4):
			var c := img.get_pixel(x, y)
			if c.r > 0.8 and c.g > 0.8 and c.b > 0.8:
				s += ". "
			elif c.r > 0.5 and c.g < 0.4:
				s += "A " # amber
			elif c.r > 0.5 and c.g > 0.5:
				s += "W " # white/silver
			elif c.r > 0.2:
				s += "G " # grey
			else:
				s += "B " # black
		print(s)
		
	print("--- REAR PIECE (x: 180..250, y: 10..45) ---")
	for y in [15, 20, 25, 30, 35, 40]:
		var s := "y=%2d: " % y
		for x in range(180, 250, 5):
			var c := img.get_pixel(x, y)
			if c.r > 0.8 and c.g > 0.8 and c.b > 0.8:
				s += ". "
			elif c.r > 0.5 and c.g < 0.2:
				s += "R " # red
			elif c.r > 0.5 and c.g < 0.4:
				s += "A " # amber
			elif c.r > 0.2:
				s += "G " # grey
			else:
				s += "B " # black
		print(s)

	print("--- SIDE PROFILE (y: 35..100) ---")
	# Let's inspect side features at Y=65 (beltline) and Y=45 (windows)
	print("Side at y=48 (windows):")
	var sw := ""
	for x in range(0, 256, 8):
		var c := img.get_pixel(x, 48)
		if c.r < 0.15:
			sw += "#" # glass
		elif c.r < 0.7:
			sw += "=" # pillar/body
		else:
			sw += " " # air
	print(sw)

	print("Side at y=65 (body):")
	var sb := ""
	for x in range(0, 256, 8):
		var c := img.get_pixel(x, 65)
		if c.r < 0.15:
			sb += "#" # trim/glass
		elif c.r < 0.8:
			sb += "=" # body
		else:
			sb += " " # air
	print(sb)

	print("Side at y=85 (rockers & wheels):")
	var sr := ""
	for x in range(0, 256, 8):
		var c := img.get_pixel(x, 85)
		if c.r < 0.15:
			sr += "#" # black bumper/trim
		elif c.r < 0.8:
			sr += "=" # body
		else:
			sr += "O" # wheel arch cutout
	print(sr)

	quit()
