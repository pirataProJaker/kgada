extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d"

func _init() -> void:
	# Cargar la textura individual
	var tile := Image.load_from_file("res://assets/textures/military/military_tile_32_r3_c7.png")
	if tile == null:
		print("Error cargando textura")
		quit(1)
		return
		
	# Guardar la imagen de 1 solo cuadro 1x1m (256x256)
	tile.save_png(ARTIFACT_DIR + "/single_tile_1x1m.png")
	print("✓ Baldosa individual 1x1m guardada: single_tile_1x1m.png (256x256)")
	
	# Guardar repetición 2x2 (2 cuadros x 2 cuadros = 2m x 2m)
	var grid_2x2 := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for y in range(2):
		for x in range(2):
			grid_2x2.blit_rect(tile, Rect2i(0, 0, 256, 256), Vector2i(x * 256, y * 256))
	grid_2x2.save_png(ARTIFACT_DIR + "/grid_2x2_blocks.png")
	print("✓ Cuadrícula 2x2 bloques guardada: grid_2x2_blocks.png (512x512)")

	quit(0)
