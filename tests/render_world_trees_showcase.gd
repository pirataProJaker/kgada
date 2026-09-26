extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	root.name = "WorldTreesShowcase"
	
	# Entorno y luz solar
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.45, 0.65, 0.85) # Cielo azul montañés
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.60, 0.65, 0.70)
	env_res.ambient_light_energy = 0.8
	env.environment = env_res
	root.add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	
	# Suelo de césped
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(120, 120)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.42, 0.20)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = floor_mat
	root.add_child(floor_mi)
	
	# Generar una arboleda variada con las diferentes especies
	var tree_configs := [
		{"pos": Vector3(-12, 0, -5), "profile": "classic_oak", "seed": 101},
		{"pos": Vector3(-4, 0, -8), "profile": "alnus_acuminata", "seed": 202},
		{"pos": Vector3(4, 0, -6), "profile": "autumn_birch", "seed": 303},
		{"pos": Vector3(12, 0, -4), "profile": "weeping_willow", "seed": 404},
		{"pos": Vector3(-8, 0, 4), "profile": "alnus_acuminata", "seed": 505},
		{"pos": Vector3(8, 0, 3), "profile": "classic_oak", "seed": 606},
		{"pos": Vector3(0, 0, -14), "profile": "dead_tree", "seed": 707}
	]
	
	for cfg in tree_configs:
		var tree := ProceduralTree.new()
		tree.profile_id = cfg["profile"]
		tree.tree_seed = cfg["seed"]
		tree.cast_shadows = true
		root.add_child(tree)
		tree.global_position = cfg["pos"]
		# Rotación aleatoria
		tree.rotate_y(cfg["seed"] * 0.73)
	
	# Cámara para vista panorámica de la arboleda
	var cam := Camera3D.new()
	cam.position = Vector3(0, 7.5, 18)
	cam.look_at(Vector3(0, 6.0, -5), Vector3.UP)
	cam.fov = 55.0
	root.add_child(cam)
	
	# Viewport para renderizado
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(root)
	
	get_root().add_child(vp)
	
	# Esperar 4 frames para que shaders, sombras y geometrías se rendericen
	for i in range(5):
		await process_frame
		
	var img := vp.get_texture().get_image()
	var out_path := "user://world_botanical_trees_showcase.png"
	var global_out := ProjectSettings.globalize_path(out_path)
	img.save_png(global_out)
	print("[SHOWCASE] Imagen guardada en: " + global_out)
	
	var copy_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/world_botanical_trees_showcase.png"
	img.save_png(copy_path)
	print("[SHOWCASE] Copia guardada en artefactos: " + copy_path)
	
	quit()
