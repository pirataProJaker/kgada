extends SceneTree

var _frames := 0
var _showcase_node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Ocultar techos y ocultar UI para capturas limpias
	if _frames == 10:
		if _showcase_node.ui_canvas:
			_showcase_node.ui_canvas.visible = false
		_showcase_node._show_roofs = false
		_showcase_node.regenerate_houses()

	# Frame 20: Captura 1 - Recámara NW (Cama 0 MADE con cobija de cuadros, buró, taza y tapete)
	elif _frames == 20:
		_showcase_node._camera.position = Vector3(-11.85, 3.8, -16.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-11.85, 0.50, -13.8))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_bedroom_closeup.png")
				print("✓ Captura 1: cross_street_bedroom_closeup.png")

	# Frame 30: Captura 2 - Recámara Planta Alta (Cama 2 UNMADE destendida con cobija arrugada y almohada inclinada)
	elif _frames == 30:
		_showcase_node._camera.position = Vector3(-8.19, 6.8, -10.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-8.19, 3.25, -7.8))

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_bedroom_unmade.png")
				print("✓ Captura 2: cross_street_bedroom_unmade.png")

	# Frame 40: Captura 3 - Recámara Planta Alta (Cama 27 en 21.775, 3.12, -28.85 con buró y ropero)
	elif _frames == 40:
		_showcase_node._camera.position = Vector3(21.775, 6.2, -31.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(21.775, 3.25, -28.85))

	elif _frames == 45:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_bedroom_second_room.png")
				print("✓ Captura 3: cross_street_bedroom_second_room.png")

	# Frame 50: Captura 4 - Baño con Lavamanos Blanco (SinkUnitWhite con grifo de metal y puertas)
	elif _frames == 50:
		_showcase_node._camera.position = Vector3(-15.5, 3.8, -12.4)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-15.5, 0.55, -14.61))

	elif _frames == 55:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_bathroom_sink.png")
				print("✓ Captura 4: cross_street_bathroom_sink.png")

	# Frame 60: Captura 5 - Vista Completa Isométrica de Casa Amueblada (Cocina, Comedor, Baño, Recámaras, Ropero)
	elif _frames == 60:
		_showcase_node._camera.position = Vector3(-11.5, 11.0, -8.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-13.5, 0.5, -16.0))

	elif _frames == 65:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_full_house_interior.png")
				print("✓ Captura 5: cross_street_full_house_interior.png")

	# Frame 70: Captura 6 - Estudio/Biblioteca con Libreros Modulares Altos (frente a libreros en z=19.23)
	elif _frames == 70:
		_showcase_node._camera.position = Vector3(13.1, 4.5, 21.8)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(13.1, 1.2, 19.23))

	elif _frames == 75:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_studio_bookcases.png")
				print("✓ Captura 6: cross_street_studio_bookcases.png")

	elif _frames >= 80:
		print("=======================================================")
		print(">>> TODAS LAS CAPTURAS COMPLETADAS EXITOSAMENTE <<<")
		print("=======================================================")
		quit(0)

	return false
