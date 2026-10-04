extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

var _frames := 0
var _showcase_node = null

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	var cam: Camera3D = _showcase_node._camera

	# Frame 10: Acercamiento directo al quiebre de esquina / pretil en L (Caso Imagen 1)
	if _frames == 10:
		# Enfocar la esquina escalonada del pretil de la casa SE (Mansión Zona X)
		cam.position = Vector3(17.8, 4.8, 13.8)
		cam.look_at_from_position(cam.position, Vector3(15.8, 3.2, 13.8))

	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_corner_fusion.png")
				print("✓ Captura Esquinas Fusionadas: verify_corner_fusion.png")

	# Frame 20: Vista a las fachadas amarillas y azules para verificar ausencia de Z-fighting (Caso Imagen 2)
	elif _frames == 20:
		# Enfocar las casas de 2 pisos amarillas y azules de Infonavit (NE)
		cam.position = Vector3(10.5, 4.2, -18.5)
		cam.look_at_from_position(cam.position, Vector3(15.0, 3.8, -23.0))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_no_zfighting_facades.png")
				print("✓ Captura Fachadas Sin Z-Fighting: verify_no_zfighting_facades.png")

	# Frame 30: Acercamiento a ventanas con desgaste para verificar que NO invaden el marco (Caso Imagen 3)
	elif _frames == 30:
		cam.position = Vector3(19.0, 2.8, -22.0)
		cam.look_at_from_position(cam.position, Vector3(21.0, 2.5, -24.0))

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_windows_clean_decals.png")
				print("✓ Captura Ventanas Sin Desgaste Encimado: verify_windows_clean_decals.png")

	elif _frames >= 40:
		quit(0)

	return false
