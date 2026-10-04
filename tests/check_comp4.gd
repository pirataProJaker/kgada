extends SceneTree

func _init() -> void:
	var path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/comp_yellow_pared_desgastada4.png"
	var img := Image.load_from_file(path)
	print("Pixel at (140, 60): %s" % str(img.get_pixel(140, 60)))
	print("Pixel at (115, 95): %s" % str(img.get_pixel(115, 95)))
	print("Pixel at (35, 70): %s" % str(img.get_pixel(35, 70)))
	print("Wall color is: %s" % str(Color(0.85, 0.72, 0.40, 1.0)))
	quit(0)
