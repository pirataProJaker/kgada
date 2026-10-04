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
		# Enfoque frontal-angular dentro de la recámara mostrando el armario completo y sus holguras
		_node._camera.position = Vector3(-15.5, 1.6, -16.5)
		_node._camera.look_at_from_position(_node._camera.position, Vector3(-13.63, 1.3, -18.45))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_wardrobe_corner_fix.png")
				print("✓ Captura: cross_street_wardrobe_corner_fix.png")

	elif _frames == 30:
		# Enfoque cercano a la cornisa superior y la esquina de los muros
		_node._camera.position = Vector3(-14.3, 1.9, -17.7)
		_node._camera.look_at_from_position(_node._camera.position, Vector3(-13.63, 1.9, -18.45))

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cross_street_wardrobe_corner_fix2.png")
				print("✓ Captura: cross_street_wardrobe_corner_fix2.png")

	elif _frames >= 40:
		quit(0)
	return false
