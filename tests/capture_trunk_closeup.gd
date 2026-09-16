extends SceneTree

var _stage: int = 0
var _frame_count: int = 0
var _tree_controller: Node = null

func _init() -> void:
	var scene_res := load("res://tests/test_procedural_tree.tscn") as PackedScene
	var scene := scene_res.instantiate()
	root.add_child(scene)
	_tree_controller = scene
	
	# Enfocar camara a 1.6m a la altura de los ojos (Y=1.4m)
	_tree_controller.set("_camera_distance", 1.6)
	_tree_controller.set("_camera_pitch", 0.0)
	var pivot: Node3D = scene.get_node("CameraPivot")
	if pivot:
		pivot.position = Vector3(0, 1.4, 0)
	_tree_controller.call("_update_camera_transform")
	
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame_count += 1
	if _frame_count < 10:
		return
	
	match _stage:
		0:
			print("Capturando primer plano de tronco Abedul (Birch)...")
			_tree_controller.call("_apply_tree_generation", 77777, "autumn_birch")
			_stage = 1
			_frame_count = 0
		1:
			if _frame_count >= 15:
				_save_capture("res://tests/trunk_birch_closeup.png")
				_stage = 2
				_frame_count = 0
		2:
			print("Capturando primer plano de tronco Roble (Oak)...")
			_tree_controller.call("_apply_tree_generation", 12345, "classic_oak")
			_stage = 3
			_frame_count = 0
		3:
			if _frame_count >= 15:
				_save_capture("res://tests/trunk_oak_closeup.png")
				print("=== CAPTURAS DE TRONCO COMPLETADAS ===")
				quit(0)


func _save_capture(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(path))
		print("Guardada captura en: ", path)
