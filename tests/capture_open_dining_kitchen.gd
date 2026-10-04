extends SceneTree

var _frames := 0
var _showcase_node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	_showcase_node._show_roofs = false
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# 1. Colonia Vieja (NW) - Vista Cenital / Top-down Floor Plan
	# Muestra claramente la ausencia de muro entre Sala y Comedor y el vano de la Cocina
	if _frames == 16:
		_showcase_node._camera.position = Vector3(-10.5, 9.0, -21.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-10.5, 0.0, -21.5), Vector3(0, 0, -1))

	elif _frames == 20:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_colonia_vieja_topdown_plan.png")
				print("✓ 1. Top-down Floor Plan Colonia Vieja guardado")

	# 2. Colonia Vieja (NW) - Vista Isométrica 3D Inclinada sobre Sala, Comedor y Cocina
	elif _frames == 23:
		_showcase_node._camera.position = Vector3(-10.5, 4.5, -16.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-10.5, 0.5, -22.0))

	elif _frames == 27:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_colonia_vieja_isometric_interior.png")
				print("✓ 2. Isométrica Interior 3D Colonia Vieja guardada")

	# 3. Colonia Vieja (NW) - A Ojo Humano dentro de la Sala mirando al Comedor y Cocina
	elif _frames == 30:
		_showcase_node._camera.position = Vector3(-13.5, 1.35, -21.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(-9.0, 0.95, -21.5))

	elif _frames == 34:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_colonia_vieja_eye_level_dining.png")
				print("✓ 3. Ojo Humano Comedor y Cocina Colonia Vieja guardado")

	# 4. Infonavit (NE) - Vista Cenital / Top-down Floor Plan
	elif _frames == 37:
		_showcase_node._camera.position = Vector3(11.0, 7.5, -18.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(11.0, 0.0, -18.5), Vector3(0, 0, -1))

	elif _frames == 41:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_infonavit_topdown_plan.png")
				print("✓ 4. Top-down Floor Plan Infonavit guardado")

	# 5. Infonavit (NE) - A Ojo Humano dentro de la Sala mirando al Comedor y Cocina
	elif _frames == 44:
		_showcase_node._camera.position = Vector3(9.2, 1.30, -16.5)
		_showcase_node._camera.look_at_from_position(_showcase_node._camera.position, Vector3(12.5, 0.95, -17.5))

	elif _frames == 48:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_infonavit_eye_level_dining.png")
				print("✓ 5. Ojo Humano Comedor y Cocina Infonavit guardado")

	elif _frames >= 52:
		quit(0)

	return false
