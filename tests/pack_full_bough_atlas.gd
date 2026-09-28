extends SceneTree

func _init() -> void:
	var img1 = Image.load_from_file("res://assets/vegetation/alnus/alnus_full_bough_1.png")
	var img2 = Image.load_from_file("res://assets/vegetation/alnus/alnus_full_bough_2.png")
	
	var atlas = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	
	# Slot 0: Top half, placed at (0, 0)
	atlas.blit_rect(img1, Rect2i(0, 0, 1024, 341), Vector2i(0, 0))
	
	# Slot 1: Bottom half, placed at (0, 512)
	atlas.blit_rect(img2, Rect2i(0, 0, 1024, 341), Vector2i(0, 512))
	
	var out_path = "res://assets/vegetation/alnus/alnus_full_bough_atlas.png"
	atlas.save_png(out_path)
	print("✓ Created: ", out_path)
	quit(0)
