@tool
extends SceneTree

func _init() -> void:
	var img_w := Image.load_from_file("res://assets/textures/furniture/washer.png")
	print("--- WASHER LID CORNERS AND CENTER ---")
	print("TL (50, 38): ", img_w.get_pixel(50, 38))
	print("TR (83, 38): ", img_w.get_pixel(83, 38))
	print("BL (50, 66): ", img_w.get_pixel(50, 66))
	print("BR (83, 66): ", img_w.get_pixel(83, 66))
	print("Center (66, 52): ", img_w.get_pixel(66, 52))
	
	var img_d := Image.load_from_file("res://assets/textures/furniture/dryer.png")
	print("--- DRYER DOOR CORNERS AND CENTER ---")
	print("TL (50, 79): ", img_d.get_pixel(50, 79))
	print("TR (83, 79): ", img_d.get_pixel(83, 79))
	print("BL (50, 107): ", img_d.get_pixel(50, 107))
	print("BR (83, 107): ", img_d.get_pixel(83, 107))
	print("Center (66, 93): ", img_d.get_pixel(66, 93))
	quit(0)
