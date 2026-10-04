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

	# Frame 12: Acercamiento a ventanas de planta baja en Infonavit NE
	if _frames == 12:
		# Posicionar cámara a nivel de calle (y=1.5) frente a las ventanas de la fachada frontal NE
		cam.position = Vector3(10.5, 1.6, -4.5)
		cam.look_at_from_position(cam.position, Vector3(10.5, 1.4, -7.0))

	elif _frames == 18:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_grilles_infonavit_ne.png")
				print("✓ Captura Herrería Infonavit NE: verify_grilles_infonavit_ne.png")

	# Frame 22: Acercamiento a fachada de Colonia Vieja NW (planta baja tradicional)
	elif _frames == 22:
		cam.position = Vector3(-12.5, 1.6, -4.5)
		cam.look_at_from_position(cam.position, Vector3(-12.5, 1.4, -7.0))

	elif _frames == 28:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_grilles_colonia_vieja_nw.png")
				print("✓ Captura Herrería Colonia Vieja NW: verify_grilles_colonia_vieja_nw.png")

	# Frame 32: Acercamiento angular a ventana con detalle de reja y marco
	elif _frames == 32:
		cam.position = Vector3(11.8, 1.5, -5.2)
		cam.look_at_from_position(cam.position, Vector3(10.5, 1.4, -7.0))

	elif _frames == 38:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_grilles_closeup_angle.png")
				print("✓ Captura Detalle Angular de Herrería: verify_grilles_closeup_angle.png")

	# Frame 42: Vista panorámica a nivel de calle mostrando varias casas con sus protecciones
	elif _frames == 42:
		cam.position = Vector3(0.0, 1.8, 3.0)
		cam.look_at_from_position(cam.position, Vector3(14.0, 2.0, -14.0))

	elif _frames == 48:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_grilles_street_perspective.png")
				print("✓ Captura Perspectiva Urbana Herrería: verify_grilles_street_perspective.png")

	elif _frames >= 52:
		quit(0)

	return false
