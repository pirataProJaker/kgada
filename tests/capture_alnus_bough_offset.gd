extends SceneTree

var _frames := 0
var _tree_view: BotanicalTreeView = null
var _cam: Camera3D = null
var _light: DirectionalLight3D = null
var _env_node: WorldEnvironment = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96"

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var root3d = Node3D.new()
	root.add_child(root3d)

	# WorldEnvironment con luz natural de montaña
	_env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.75, 0.80)
	env.ambient_light_energy = 0.90
	_env_node.environment = env
	root3d.add_child(_env_node)

	# Sol
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-38.0, 42.0, 0.0)
	_light.light_color = Color(1.0, 0.98, 0.92)
	_light.light_energy = 1.25
	_light.shadow_enabled = true
	root3d.add_child(_light)

	# Suelo
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(60, 60)
	ground.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.35, 0.33, 0.28)
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	root3d.add_child(ground)

	# Árbol Alnus
	_tree_view = BotanicalTreeView.new()
	_tree_view.species_id = "alnus_acuminata"
	_tree_view.tree_seed = 12345
	_tree_view.age = 0.90
	_tree_view.forced_lod = 0
	root3d.add_child(_tree_view)

	# Cámara
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 55.0
	root3d.add_child(_cam)
	# Vista 1: Ángulo desde abajo mirando hacia la inserción de las ramas en el tronco
	_cam.look_at_from_position(Vector3(1.5, 2.6, 2.8), Vector3(0.0, 3.8, 0.0))

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Captura 1: Vista bajo la copa mirando el cuello de rama (Branch Collar) y los 1.5m de madera despejada
	if _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_bough_offset_undercanopy.png")
				print("✓ Captura 1: alnus_bough_offset_undercanopy.png guardada.")

	# Captura 2: Vista lateral de cuerpo entero
	elif _frames == 30:
		_cam.fov = 50.0
		_cam.position = Vector3(0.0, 6.5, 17.0)
		_cam.look_at(Vector3(0.0, 6.5, 0.0))
	elif _frames == 45:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_bough_offset_full.png")
				print("✓ Captura 2: alnus_bough_offset_full.png guardada.")

	# Captura 3: Cambiar a especie "classic_oak" (donde offset = 0.0m) para validar la reutilización en el motor
	elif _frames == 50:
		_tree_view.species_id = "classic_oak"
		_cam.fov = 52.0
		_cam.position = Vector3(0.0, 5.5, 15.0)
		_cam.look_at(Vector3(0.0, 5.5, 0.0))
	elif _frames == 65:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/species_classic_oak_comparison.png")
				print("✓ Captura 3: species_classic_oak_comparison.png guardada.")
		quit(0)
		return true

	return false
