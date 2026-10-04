extends SceneTree

func _init() -> void:
	var img := Image.new()
	var err := img.load("res://assets/textures/furniture/sofa_leather.png")
	if err != OK:
		print("Error loading sofa_leather.png: ", err)
		quit(1)
		return
	print("sofa_leather.png dimensions: ", img.get_size())
	# Sample colors across key regions
	# 1. Backrest capitoné buttons: around X: 106, Y: 20
	print("Backrest buttons (106, 20): ", img.get_pixel(106, 20))
	# 2. Backrest lower smooth: around X: 106, Y: 60
	print("Backrest smooth (106, 60): ", img.get_pixel(106, 60))
	# 3. Leg dark texture: around X: 76, Y: 20
	print("Leg dark (76, 20): ", img.get_pixel(76, 20))
	# 4. Seat cushion: around X: 44, Y: 57
	print("Seat cushion (44, 57): ", img.get_pixel(44, 57))
	# 5. Side profile: around X: 35, Y: 100
	print("Side profile (35, 100): ", img.get_pixel(35, 100))
	# 6. Armrest padding / top: around X: 10, Y: 55
	print("Armrest padding (10, 55): ", img.get_pixel(10, 55))
	quit(0)





