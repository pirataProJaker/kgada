extends SceneTree

var _frames := 0
var _showcase_node = null
var _cam: Camera3D = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 15: Captura Vista Aérea General de la Calle en Cruz
	if _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_overview.png")
				print("✓ Vista Aérea guardada: cross_street_overview.png")

	# Frame 25: Enfoque Esquina NW (Colonia Vieja pared con pared)
	elif _frames == 25:
		_showcase_node._focus_nw()

	elif _frames == 32:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_nw_colonia_vieja.png")
				print("✓ Esquina NW guardada: cross_street_nw_colonia_vieja.png")

	# Frame 34: Vista de esquina enfocando el costado (pared lateral sin ventanas) de la casa NW
	elif _frames == 34:
		_showcase_node._camera.position = Vector3(-3.5, 2.2, -3.0)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-11.0, 1.6, -12.0))

	elif _frames == 37:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_graffiti_corner_view.png")
				print("✓ Vista Esquina y Costado guardada: cross_street_graffiti_corner_view.png")

	# Frame 38: Vista frontal directa a la pared lateral ("a un lado de la casa")
	elif _frames == 38:
		_showcase_node._camera.position = Vector3(-2.8, 1.8, -9.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-7.0, 1.8, -9.5))

	elif _frames == 41:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_graffiti_side_wall.png")
				print("✓ Pared lateral con grafitis guardada: cross_street_graffiti_side_wall.png")

	# Frame 44: Enfoque Esquina NE (Colonia Nueva / Infonavit)
	elif _frames == 44:
		_showcase_node._focus_ne()

	elif _frames == 48:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_ne_infonavit.png")
				print("✓ Esquina NE guardada: cross_street_ne_infonavit.png")

	# Frame 52: Alternar Techos (T) para inspección interior
	elif _frames == 52:
		_showcase_node._show_roofs = false
		_showcase_node.regenerate_houses()
		_showcase_node._focus_overview()

	elif _frames == 58:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_interior_inspection.png")
				print("✓ Inspección Interior (sin techos) guardada: cross_street_interior_inspection.png")

	# Frame 62: Acercamiento interior a la esquina NW
	elif _frames == 62:
		_showcase_node._focus_nw()

	elif _frames == 68:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_interior_nw_closeup.png")
				print("✓ Detalle Interior NW guardado: cross_street_interior_nw_closeup.png")

	# Frame 72: Simular presionar [R] (randomize_all_seeds)
	elif _frames == 72:
		_showcase_node._show_roofs = true
		_showcase_node.randomize_all_seeds()
		_showcase_node._focus_overview()

	elif _frames == 80:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_randomized_r.png")
				print("✓ Casas Regeneradas con [R] guardadas: cross_street_randomized_r.png")

	# Frame 82: Acercamiento directo al gran grafiti en el costado de la casa
	elif _frames == 82:
		_showcase_node._camera.position = Vector3(-3.0, 1.8, 11.0)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-7.0, 1.8, 11.0))

	elif _frames == 86:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_large_graffiti_closeup.png")
				print("✓ Acercamiento a gran grafiti lateral guardado: cross_street_large_graffiti_closeup.png")

	elif _frames >= 90:
		quit(0)

	return false
