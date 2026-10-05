@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null:
		print("ERROR: could not load image")
		quit()
		return
	print("Atlas size: ", img.get_size(), " format: ", img.get_format())
	
	# Let's inspect colors at key coordinates:
	# Front grill & lights
	print("Front Grill left center: (15, 25) = ", img.get_pixel(15, 25))
	print("Front Headlight: (35, 25) = ", img.get_pixel(35, 25))
	print("Front Corner Amber: (56, 25) = ", img.get_pixel(56, 25))
	print("Front Bumper: (35, 38) = ", img.get_pixel(35, 38))
	print("Front Lower Amber: (45, 35) = ", img.get_pixel(45, 35))
	
	# Side profile
	print("Side Hood: (30, 55) = ", img.get_pixel(30, 55))
	print("Side Front Door: (100, 55) = ", img.get_pixel(100, 55))
	print("Side Window: (100, 48) = ", img.get_pixel(100, 48))
	print("Side Wheel Rim: (230, 230) = ", img.get_pixel(230, 230))
	print("Side Tire: (195, 230) = ", img.get_pixel(195, 230))

	# Top profile:
	print("Top Hood: (30, 130) = ", img.get_pixel(30, 130))
	print("Top Windshield: (60, 130) = ", img.get_pixel(60, 130))
	print("Top Roof: (100, 130) = ", img.get_pixel(100, 130))
	print("Top Rear Window: (165, 130) = ", img.get_pixel(165, 130))
	print("Top Trunk: (210, 130) = ", img.get_pixel(210, 130))

	quit()
