extends SceneTree

func _init() -> void:
	var t1 := Image.load_from_file("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/crop_r0_c6_clean.png")
	var t2 := Image.load_from_file("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/crop_r3_c7_clean.png")
	var t3 := Image.load_from_file("res://assets/textures/military/military_tile_32_r3_c7.png")
	
	_make_repeat_image(t1, "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/repeat_r0_c6.png")
	_make_repeat_image(t2, "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/repeat_r3_c7.png")
	_make_repeat_image(t3, "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/repeat_tile32.png")
	
	quit(0)

func _make_repeat_image(src: Image, out_path: String) -> void:
	if src == null:
		return
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w * 3, h * 3, false, src.get_format())
	for ty in range(3):
		for tx in range(3):
			out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(tx * w, ty * h))
	out.save_png(out_path)
	print("Saved 3x3 repeat: ", out_path)
