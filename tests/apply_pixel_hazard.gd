extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d"

func _init() -> void:
	# Instalar la versión de 64x64 (baja resolución retro PSX) en assets
	var pix_img := Image.load_from_file(ARTIFACT_DIR + "/hazard_pixelated_64.png")
	if pix_img:
		pix_img.save_png("res://assets/textures/military/military_tile_32_r3_c7.png")
		pix_img.save_png("res://assets/textures/military/military_tile_07_r0_c6.png")
		print("✓ Instalada versión pixelada 64x64 retro en assets.")
	quit(0)
