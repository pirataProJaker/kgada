extends SceneTree

func _init() -> void:
	var cal_img := Image.load_from_file("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/hazard_tile_calibrated.png")
	if cal_img:
		cal_img.save_png("res://assets/textures/military/military_tile_32_r3_c7.png")
		print("✓ Copiada textura calibrada a res://assets/textures/military/military_tile_32_r3_c7.png")
	else:
		printerr("Error cargando hazard_tile_calibrated.png")
	quit(0)
