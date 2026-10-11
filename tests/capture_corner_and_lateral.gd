extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

func _init() -> void:
	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var scene_res = load("res://scenes/procedural_store_showcase.tscn")
	var showcase = scene_res.instantiate()
	root_vp.add_child(showcase)

	_run(showcase)

func _run(showcase: Node) -> void:
	# Esperar a que showcase._ready() se ejecute
	for i in range(4):
		await process_frame

	var found_corner_seed := -1
	for s in range(100, 200):
		showcase.generate_store(s, false)
		var comm = showcase._last_comm_data
		if comm.get("entrance_type", 0) == 1 and comm.get("has_lateral_showcase", false):
			found_corner_seed = s
			print("✓ Encontrada tienda de esquina con vitral lateral y acceso en esquina: Semilla ", s)
			break

	if found_corner_seed != -1:
		showcase.generate_store(found_corner_seed, false)
		showcase._focus_facade()
		for i in range(8):
			await process_frame

		var img := get_root().get_viewport().get_texture().get_image()
		if img and not img.is_empty():
			img.save_png(ARTIFACT_DIR + "/showcase_store_corner_entrance.png")
			print("✓ Captura guardada: showcase_store_corner_entrance.png")

		# Capturar la esquina desde perspectiva angular exterior para ver cómo la puerta y los ventanales se integran
		showcase._camera.position = Vector3(-13.0, 3.2, -13.0)
		showcase._camera.look_at_from_position(showcase._camera.position, Vector3(-2.0, 1.8, -2.0))
		for i in range(6):
			await process_frame

		var img_angle := get_root().get_viewport().get_texture().get_image()
		if img_angle and not img_angle.is_empty():
			img_angle.save_png(ARTIFACT_DIR + "/showcase_store_corner_angle_view.png")
			print("✓ Captura guardada: showcase_store_corner_angle_view.png")

	quit()
