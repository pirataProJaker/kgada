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

	# Frame 15: Vista interior angular mostrando las nuevas estanterías de izquierda a derecha
	if _frames == 15:
		if cam:
			# Posición dentro de la tienda cerca de la entrada mirando a las góndolas
			cam.position = Vector3(-13.5, 1.65, 14.5)
			cam.look_at_from_position(cam.position, Vector3(-16.0, 1.25, 17.0))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/new_otxo_shelves_interior_1.png")
				print("✓ Captura 1 guardada: new_otxo_shelves_interior_1.png")

	# Frame 30: Otra perspectiva interior desde el fondo mirando hacia el frente
	elif _frames == 30:
		if cam:
			cam.position = Vector3(-17.0, 1.70, 18.5)
			cam.look_at_from_position(cam.position, Vector3(-14.5, 1.20, 14.5))

	elif _frames == 40:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/new_otxo_shelves_interior_2.png")
				print("✓ Captura 2 guardada: new_otxo_shelves_interior_2.png")
				quit(0)

	return false
