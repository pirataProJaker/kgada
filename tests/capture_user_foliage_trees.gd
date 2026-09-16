extends SceneTree

var _stage: int = 0
var _frame_count: int = 0
var _tree_controller: Node = null

func _init() -> void:
	var scene_res := load("res://tests/test_procedural_tree.tscn") as PackedScene
	var scene := scene_res.instantiate()
	root.add_child(scene)
	_tree_controller = scene
	_tree_controller.set("_camera_distance", 8.5)
	_tree_controller.call("_update_camera_transform")
	
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame_count += 1
	if _frame_count < 10:
		return
	
	match _stage:
		0:
			# Capturar Roble Clasico con textura del usuario
			print("Capturando Roble con textura real...")
			_tree_controller.call("_apply_tree_generation", 12345, "classic_oak")
			_stage = 1
			_frame_count = 0
		1:
			if _frame_count >= 15:
				_save_capture("res://tests/procedural_tree_oak_user.png")
				_stage = 2
				_frame_count = 0
		2:
			# Capturar Pino Boreal con textura de agujas
			print("Capturando Pino con textura real...")
			_tree_controller.call("_apply_tree_generation", 54321, "pine_boreal")
			_stage = 3
			_frame_count = 0
		3:
			if _frame_count >= 15:
				_save_capture("res://tests/procedural_tree_pine_user.png")
				_stage = 4
				_frame_count = 0
		4:
			# Capturar Abedul de Otono con corteza de abedul y hojas doradas
			print("Capturando Abedul con corteza real...")
			_tree_controller.call("_apply_tree_generation", 77777, "autumn_birch")
			_stage = 5
			_frame_count = 0
		5:
			if _frame_count >= 15:
				_save_capture("res://tests/procedural_tree_birch_user.png")
				_stage = 6
				_frame_count = 0
		6:
			# Capturar Sauce Lloron con frondas caidas
			print("Capturando Sauce Lloron con frondas...")
			_tree_controller.call("_apply_tree_generation", 98765, "weeping_willow")
			_stage = 7
			_frame_count = 0
		7:
			if _frame_count >= 15:
				_save_capture("res://tests/procedural_tree_willow_user.png")
				print("Todas las capturas guardadas exitosamente.")
				quit()


func _save_capture(save_path: String) -> void:
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img != null:
		img.save_png(save_path)
		print("Guardada captura en: ", save_path)
