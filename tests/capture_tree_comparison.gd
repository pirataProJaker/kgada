extends SceneTree

var _stage: int = 0
var _frame_count: int = 0
var _tree_controller: Node = null

func _init() -> void:
	var scene_res := load("res://tests/test_procedural_tree.tscn") as PackedScene
	var scene := scene_res.instantiate()
	root.add_child(scene)
	_tree_controller = scene
	
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame_count += 1
	if _frame_count < 15:
		return
	
	match _stage:
		0:
			print("Generando árboles para captura comparativa (Roble en LOD 0)...")
			_tree_controller.set("_camera_distance", 14.0)
			_tree_controller.set("_camera_pitch", deg_to_rad(12.0))
			_tree_controller.set("_camera_yaw", 0.0)
			_tree_controller.set("_forced_lod_state", 0) # Forzar LOD0 para ver detalle completo
			_tree_controller.call("_apply_tree_generation", 12345, "classic_oak")
			_tree_controller.call("_update_camera_transform")
			_stage = 1
			_frame_count = 0
		1:
			_save_capture("res://tests/tree_comparison_capture.png")
			print("=== CAPTURA COMPARATIVA GUARDADA CON EXITO ===")
			quit(0)


func _save_capture(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(path))
		print("Guardada captura en: ", path)
