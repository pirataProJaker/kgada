extends SceneTree

var _frame: int = 0

func _init() -> void:
	var root_node := Node3D.new()
	root_node.name = "ShowcaseRoot"
	root.add_child(root_node)
	
	# Entorno
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.42, 0.62, 0.82)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.65, 0.70, 0.75)
	env_res.ambient_light_energy = 0.8
	env.environment = env_res
	root_node.add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root_node.add_child(sun)
	
	# Suelo
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 80)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.24, 0.38, 0.18)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = floor_mat
	root_node.add_child(floor_mi)
	
	# 3 Árboles en fila: Classic Oak, Alnus Acuminata, Autumn Birch
	var t1 := ProceduralTree.new()
	t1.profile_id = "classic_oak"
	t1.tree_seed = 12345
	t1.cast_shadows = true
	root_node.add_child(t1)
	t1.position = Vector3(-7, 0, 0)
	
	var t2 := ProceduralTree.new()
	t2.profile_id = "alnus_acuminata"
	t2.tree_seed = 67890
	t2.cast_shadows = true
	root_node.add_child(t2)
	t2.position = Vector3(0, 0, 0)
	
	var t3 := ProceduralTree.new()
	t3.profile_id = "autumn_birch"
	t3.tree_seed = 45678
	t3.cast_shadows = true
	root_node.add_child(t3)
	t3.position = Vector3(7, 0, 0)
	
	# Cámara
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6.0, 20.0)
	cam.look_at(Vector3(0, 6.0, 0), Vector3.UP)
	cam.fov = 50.0
	root_node.add_child(cam)
	
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frame += 1
	if _frame == 20:
		var img := root.get_viewport().get_texture().get_image()
		if img != null:
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/botanical_world_trees_verified.png"
			img.save_png(save_path)
			print("[SUCCESS] Imagen guardada en: " + save_path)
		quit(0)
