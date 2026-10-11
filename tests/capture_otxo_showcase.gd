extends SceneTree

var _frames := 0
var _showcase_node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	var cam: Camera3D = _showcase_node._camera

	# Frame 10: Enfocar la esquina SW donde está la tienda OTXO con vista angular
	if _frames == 10:
		if cam:
			# Mirar desde el cruce de calles hacia la tienda OTXO, su estacionamiento y su tótem
			cam.position = Vector3(-6.0, 4.5, 4.0)
			cam.look_at_from_position(cam.position, Vector3(-15.0, 2.5, 15.0))

	# Frame 20: Captura 1 - Vista general de la tienda OTXO, Tótem y Estacionamiento
	elif _frames == 20:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/otxo_store_exterior.png")
				print("✓ Vista Exterior OTXO guardada: otxo_store_exterior.png")

	# Frame 22: Enfocar primer plano al Tótem gigante (poste y letrero OTXO elevado)
	elif _frames == 22:
		if cam:
			cam.position = Vector3(-20.5, 7.2, 3.5)
			cam.look_at_from_position(cam.position, Vector3(-21.5, 7.6, 8.5))

	# Frame 30: Captura 2 - Detalle del Tótem Gigante
	elif _frames == 30:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/otxo_totem_closeup.png")
				print("✓ Detalle Tótem OTXO guardado: otxo_totem_closeup.png")

	# Frame 32: Vista de primer plano a la entrada, marquesina, puertas, banqueta con guarnición
	elif _frames == 32:
		if cam:
			cam.position = Vector3(-14.2, 1.85, 9.6)
			cam.look_at_from_position(cam.position, Vector3(-14.6, 1.90, 14.2))

	# Frame 42: Captura 3 - Detalle de Fachada, Marquesina y Letrero
	elif _frames == 42:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/otxo_facade_closeup.png")
				print("✓ Detalle Fachada OTXO guardado: otxo_facade_closeup.png")

	# Frame 45: Vista Interior de la tienda (Perspectiva amplia del piso de venta)
	elif _frames == 45:
		if cam:
			cam.position = Vector3(-13.0, 1.65, 17.5)
			cam.look_at_from_position(cam.position, Vector3(-16.2, 1.15, 14.2))

	# Frame 55: Captura 4 - Interior de la tienda OTXO
	elif _frames == 55:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/otxo_store_interior.png")
				print("✓ Vista Interior OTXO guardada: otxo_store_interior.png")
				quit(0)

	return false
