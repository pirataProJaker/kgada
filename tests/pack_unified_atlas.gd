extends SceneTree

func _init() -> void:
	var bough_atlas = Image.load_from_file("res://assets/vegetation/alnus/alnus_bough_atlas.png")
	var full_atlas = Image.load_from_file("res://assets/vegetation/alnus/alnus_full_bough_atlas.png")
	
	var unified = Image.create(2048, 1024, false, Image.FORMAT_RGBA8)
	unified.fill(Color(0, 0, 0, 0))
	
	# Left 1024x1024: 4 square boughs
	unified.blit_rect(bough_atlas, Rect2i(0, 0, 1024, 1024), Vector2i(0, 0))
	
	# Right 1024x1024: 2 full limb boughs
	unified.blit_rect(full_atlas, Rect2i(0, 0, 1024, 1024), Vector2i(1024, 0))
	
	var out_path = "res://assets/vegetation/alnus/alnus_unified_atlas.png"
	unified.save_png(out_path)
	print("✓ Created: ", out_path)
	quit(0)
