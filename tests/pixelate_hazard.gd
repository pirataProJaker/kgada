extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d"

func _init() -> void:
	var base_tile := Image.load_from_file(ARTIFACT_DIR + "/master_hazard_tile_256.png")
	if base_tile == null:
		base_tile = Image.load_from_file("res://assets/textures/military/military_tile_32_r3_c7.png")
		
	# Opción A: 128x128 (Resolución nativa PSX, bloques de 2x2 píxeles)
	# Mantiene un nivel de detalle retro perfecto que coincide con el resto del pack militar
	var pix_128 := base_tile.duplicate()
	pix_128.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	pix_128.resize(256, 256, Image.INTERPOLATE_NEAREST)
	pix_128.save_png(ARTIFACT_DIR + "/hazard_pixelated_128.png")
	
	# Opción B: 96x96 (Pixelado medio-marcado)
	var pix_96 := base_tile.duplicate()
	pix_96.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	pix_96.resize(256, 256, Image.INTERPOLATE_NEAREST)
	pix_96.save_png(ARTIFACT_DIR + "/hazard_pixelated_96.png")

	# Opción C: 64x64 (Pixelado retro marcado, bloques de 4x4 píxeles)
	var pix_64 := base_tile.duplicate()
	pix_64.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	pix_64.resize(256, 256, Image.INTERPOLATE_NEAREST)
	pix_64.save_png(ARTIFACT_DIR + "/hazard_pixelated_64.png")

	# Generar repeticiones 2x2 de cada una para verificar que sigan siendo 100% seamless
	_make_2x2(pix_128, ARTIFACT_DIR + "/compare_2x2_pixel_128.png")
	_make_2x2(pix_96, ARTIFACT_DIR + "/compare_2x2_pixel_96.png")
	_make_2x2(pix_64, ARTIFACT_DIR + "/compare_2x2_pixel_64.png")

	print("✓ Versiones pixeladas generadas.")
	quit(0)

func _make_2x2(tile: Image, out_path: String) -> void:
	var out := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for y in range(2):
		for x in range(2):
			out.blit_rect(tile, Rect2i(0, 0, 256, 256), Vector2i(x * 256, y * 256))
	out.save_png(out_path)
