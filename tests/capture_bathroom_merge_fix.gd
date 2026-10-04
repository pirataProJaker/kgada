extends SceneTree

var _frames := 0
var _node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_node = showcase_scn.instantiate()
	_node.is_capture_mode = true
	root.add_child(_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	if _frames == 10:
		if _node.ui_canvas:
			_node.ui_canvas.visible = false
		_node._show_roofs = false
		_node.regenerate_houses()

	elif _frames == 20:
		# Vista isométrica aérea de la suite principal y el nuevo baño unificado en la residencia (Parcela 17)
		# Centro de la suite en X = 29.5, Z = 18.0; Baño unificado en Z = 20.0
		_node._camera.position = Vector3(26.0, 8.5, 14.5)
		_node._camera.look_at_from_position(_node._camera.position, Vector3(29.5, 0.5, 19.0))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/spacious_bathroom_merged_topdown.png")
				print("✓ Captura 1: spacious_bathroom_merged_topdown.png")

	elif _frames == 30:
		# Vista angular desde la recámara mostrando la puerta abierta hacia el baño grande
		_node._camera.position = Vector3(31.5, 2.0, 17.5)
		_node._camera.look_at_from_position(_node._camera.position, Vector3(29.5, 1.2, 19.5))

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/spacious_bathroom_door_entry.png")
				print("✓ Captura 2: spacious_bathroom_door_entry.png")

	elif _frames == 40:
		# Vista dentro del baño espacioso mirando hacia la recámara a través de la puerta
		_node._camera.position = Vector3(29.5, 1.8, 20.2)
		_node._camera.look_at_from_position(_node._camera.position, Vector3(29.5, 1.2, 17.5))

	elif _frames == 45:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/spacious_bathroom_interior_view.png")
				print("✓ Captura 3: spacious_bathroom_interior_view.png")

	elif _frames >= 50:
		quit(0)
	return false
