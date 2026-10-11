extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

func _init() -> void:
	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var scene_res = load("res://scenes/procedural_store_showcase.tscn")
	var showcase = scene_res.instantiate()
	root_vp.add_child(showcase)

	_run_captures(showcase)

func _run_captures(showcase: Node) -> void:
	# 1. Captura Fachada Inicial
	for i in range(8):
		await process_frame

	var img1 := get_root().get_viewport().get_texture().get_image()
	if img1 and not img1.is_empty():
		img1.save_png(ARTIFACT_DIR + "/showcase_store_initial.png")
		print("✓ Captura 1 guardada: showcase_store_initial.png")

	# 2. Captura Fachada Lateral (Vitrales panorámicos y columnas 3D)
	showcase._focus_lateral()
	for i in range(6):
		await process_frame

	var img_lat := get_root().get_viewport().get_texture().get_image()
	if img_lat and not img_lat.is_empty():
		img_lat.save_png(ARTIFACT_DIR + "/showcase_store_lateral.png")
		print("✓ Captura 2 guardada: showcase_store_lateral.png")

	# 3. Regeneración con tecla R (variación procedural: acceso y vitrales)
	print("Simulando tecla R...")
	showcase.generate_store(-1, true)
	showcase._focus_facade()
	for i in range(8):
		await process_frame

	var img2 := get_root().get_viewport().get_texture().get_image()
	if img2 and not img2.is_empty():
		img2.save_png(ARTIFACT_DIR + "/showcase_store_regenerated_r.png")
		print("✓ Captura 3 guardada: showcase_store_regenerated_r.png")

	# 4. Rotación del predio [O] (adaptación urbana a esquina con orientación 90°)
	print("Simulando rotación [O]...")
	showcase.cycle_orientation(90)
	showcase._focus_aerial()
	for i in range(6):
		await process_frame

	var img_rot := get_root().get_viewport().get_texture().get_image()
	if img_rot and not img_rot.is_empty():
		img_rot.save_png(ARTIFACT_DIR + "/showcase_store_rotated.png")
		print("✓ Captura 4 guardada: showcase_store_rotated.png")

	# 5. Vista del tótem publicitario
	showcase._focus_totem()
	for i in range(6):
		await process_frame

	var img3 := get_root().get_viewport().get_texture().get_image()
	if img3 and not img3.is_empty():
		img3.save_png(ARTIFACT_DIR + "/showcase_store_totem_view.png")
		print("✓ Captura 5 guardada: showcase_store_totem_view.png")

	print("Todas las capturas completadas con éxito.")
	quit()
