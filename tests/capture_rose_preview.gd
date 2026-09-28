extends SceneTree

var _stage: int = 0
var _frame_count: int = 0
var _scene: Node = null
const ARTIFACT_DIR := "C:/Users/PC 1/.gemini/antigravity-ide/brain/7665bda4-35a4-4713-97f9-d4941a9911be"

func _init() -> void:
	var scene_res := load("res://tests/test_procedural_rose.tscn") as PackedScene
	_scene = scene_res.instantiate()
	root.add_child(_scene)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame_count += 1
	if _frame_count < 10:
		return
	
	match _stage:
		0:
			# 1. Rosa Solitaria Blanca Pura (Textura fotográfica original del atlas sin tinte)
			print("1. Capturando Rosa Solitaria Blanca...")
			_scene.set("_display_mode", 1) # Solitaria
			_scene.call("_apply_visibility")
			_scene.set("_current_color_idx", 3) # Blanco Marfil
			_scene.call("_apply_colors")
			_scene.set("_camera_distance", 0.95)
			_scene.set("_camera_pitch", deg_to_rad(16.0))
			_scene.set("_camera_yaw", deg_to_rad(-20.0))
			_scene.call("_update_camera_transform")
			_scene.get_node("HUD").visible = false
			_stage = 1
			_frame_count = 0
		1:
			if _frame_count >= 15:
				_save_capture("res://tests/rose_solitary_white_atlas.png")
				_save_capture(ARTIFACT_DIR + "/rose_solitary_white_atlas.png")
				_stage = 2
				_frame_count = 0
		2:
			# 2. Rosa Solitaria Rojo Carmesí (Tinte terciopelo sobre textura real)
			print("2. Capturando Rosa Solitaria Roja...")
			_scene.set("_current_color_idx", 0) # Rojo Carmesí
			_scene.call("_apply_colors")
			_stage = 3
			_frame_count = 0
		3:
			if _frame_count >= 15:
				_save_capture("res://tests/rose_solitary_red_atlas.png")
				_save_capture(ARTIFACT_DIR + "/rose_solitary_red_atlas.png")
				_stage = 4
				_frame_count = 0
		4:
			# 3. Rosal Arbustivo en LOD 0 con rosas coral y follaje denso fotorrealista
			print("3. Capturando Rosal Arbustivo LOD 0...")
			_scene.set("_display_mode", 2) # Arbusto
			_scene.call("_apply_visibility")
			_scene.set("_current_color_idx", 1) # Rosa Coral / Salmón
			_scene.call("_apply_colors")
			_scene.set("_forced_lod", 0)
			_scene.call("_apply_lod")
			_scene.set("_camera_distance", 1.45)
			_scene.set("_camera_pitch", deg_to_rad(22.0))
			_scene.set("_camera_yaw", deg_to_rad(30.0))
			_scene.call("_update_camera_transform")
			_scene.get_node("HUD").visible = true
			_stage = 5
			_frame_count = 0
		5:
			if _frame_count >= 15:
				_save_capture("res://tests/procedural_rose_comparative.png")
				_save_capture(ARTIFACT_DIR + "/rose_shrub_lod0_atlas.png")
				_stage = 6
				_frame_count = 0
		6:
			# 4. Rosal Arbustivo en LOD 1 (Cross-Quads fotorrealistas de 6 tris)
			print("4. Capturando Rosal Arbustivo LOD 1...")
			_scene.set("_forced_lod", 1)
			_scene.call("_apply_lod")
			_stage = 7
			_frame_count = 0
		7:
			if _frame_count >= 15:
				_save_capture("res://tests/rose_lod1_grass.png")
				_save_capture(ARTIFACT_DIR + "/rose_shrub_lod1_atlas.png")
				_stage = 8
				_frame_count = 0
		8:
			# 5. Rosal Arbustivo en LOD 2 (Cross-Quads ultraligeros de 4 tris)
			print("5. Capturando Rosal Arbustivo LOD 2...")
			_scene.set("_forced_lod", 2)
			_scene.call("_apply_lod")
			_stage = 9
			_frame_count = 0
		9:
			if _frame_count >= 15:
				_save_capture("res://tests/rose_lod2_grass.png")
				_save_capture(ARTIFACT_DIR + "/rose_shrub_lod2_atlas.png")
				print("✓ Todas las capturas de rosas guardadas exitosamente.")
				quit(0)

func _save_capture(save_path: String) -> void:
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img != null:
		img.save_png(save_path)
		print("Guardada captura en: ", save_path)
