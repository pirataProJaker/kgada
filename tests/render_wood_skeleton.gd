extends SceneTree

var _frames := 0

func _init() -> void:
	var root3d = Node3D.new()
	root.add_child(root3d)

	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.74, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.75, 0.85)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	root3d.add_child(env_node)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, 48.0, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	root3d.add_child(light)

	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(80, 80)
	ground.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.42, 0.38, 0.30)
	ground.material_override = ground_mat
	root3d.add_child(ground)

	# Render procedural tree skeleton ONLY (foliage_mode = 0, but hide leaves surface)
	var tree_view = BotanicalTreeView.new()
	tree_view.species_id = "alnus_acuminata"
	tree_view.tree_seed = 12345
	tree_view.age = 1.0
	tree_view.forced_lod = 0
	root3d.add_child(tree_view)

	var cam = Camera3D.new()
	cam.current = true
	cam.fov = 53.0
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 9.5, 23.0), Vector3(0.0, 9.5, 0.0))

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	if _frames == 20:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/procedural_wood_skeleton.png")
				print("Saved procedural_wood_skeleton.png")
		quit(0)
		return true
	return false
