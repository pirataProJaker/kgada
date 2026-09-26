extends SceneTree

var _frames := 0
var _scene: Node = null

func _init() -> void:
	var scene_res: PackedScene = load("res://scenes/pine_lod_showcase.tscn")
	_scene = scene_res.instantiate()
	root.add_child(_scene)
	print("Showcase instanciado.")

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	if _frames == 15:
		if _scene and _scene.has_method("_set_cam_preset"):
			_scene._set_cam_preset(Vector3(-12, 18, 28), 10.0)
	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_showcase_25m.png")
			print("✓ Captura a 25m guardada.")
	elif _frames == 30:
		if _scene and _scene.has_method("_set_cam_preset"):
			_scene._set_cam_preset(Vector3(-12, 18, 55), 8.0)
	elif _frames == 40:
		if vp:
			var img = vp.get_texture().get_image()
			img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_showcase_50m.png")
			print("✓ Captura a 50m guardada.")
	elif _frames == 45:
		if _scene and _scene.has_method("_set_cam_preset"):
			_scene._set_cam_preset(Vector3(-12, 18, 105), 5.0)
	elif _frames == 55:
		if vp:
			var img = vp.get_texture().get_image()
			img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_showcase_100m.png")
			print("✓ Captura a 105m guardada.")
		quit(0)
		return true
	return false
