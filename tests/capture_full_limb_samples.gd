extends SceneTree

var _frames := 0
var _tree_view: BotanicalTreeView = null
var _cam: Camera3D = null
var _light: DirectionalLight3D = null
var _env_node: WorldEnvironment = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96"

func _init() -> void:
	var root3d = Node3D.new()
	root.add_child(root3d)

	# WorldEnvironment con cielo montañés luminoso
	_env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.74, 0.92) # Azul cielo límpido
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.75, 0.85)
	env.ambient_light_energy = 0.85
	_env_node.environment = env
	root3d.add_child(_env_node)

	# Luz solar direccional (sol montañés alto y cálido)
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-42.0, 48.0, 0.0)
	_light.light_color = Color(1.0, 0.98, 0.90)
	_light.light_energy = 1.35
	_light.shadow_enabled = true
	root3d.add_child(_light)

	# Suelo
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(100, 100)
	ground.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.42, 0.38, 0.30)
	ground.material_override = ground_mat
	root3d.add_child(ground)

	# Árbol Botánico Alnus
	_tree_view = BotanicalTreeView.new()
	_tree_view.species_id = "alnus_acuminata"
	_tree_view.tree_seed = 12345
	_tree_view.age = 1.0 # Adulto maduro completo
	_tree_view.forced_lod = 0
	_tree_view.foliage_mode = 3 # Empezamos con Muestra 1: Híbrido
	root3d.add_child(_tree_view)

	# Cámara general
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 52.0
	root3d.add_child(_cam)
	_cam.look_at_from_position(Vector3(0.0, 9.5, 24.0), Vector3(0.0, 9.5, 0.0))

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# =========================================================================
	# MUESTRA 1: HÍBRIDO (Ramas procedurales 3D + Ramas fotográficas completas)
	# =========================================================================
	if _frames == 15:
		# Vista frontal completa
		_cam.fov = 52.0
		_cam.position = Vector3(0.0, 9.5, 24.0)
		_cam.look_at(Vector3(0.0, 9.5, 0.0))

	elif _frames == 22:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_sample_hybrid.png")
				print("✓ Muestra 1 guardada: alnus_sample_hybrid.png")

	elif _frames == 25:
		# Vista perspectiva 3/4 para apreciar volumen y tridimensionalidad
		_cam.fov = 50.0
		_cam.position = Vector3(16.0, 9.0, 18.0)
		_cam.look_at(Vector3(0.0, 8.5, 0.0))

	elif _frames == 32:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_sample_hybrid_angle.png")
				print("✓ Muestra 1 perspectiva 3/4 guardada: alnus_sample_hybrid_angle.png")

	elif _frames == 35:
		# Close-up al tronco despejado mostrando nacimiento de rama procedural y rama foto
		_cam.fov = 50.0
		_cam.position = Vector3(-1.8, 4.2, 4.6)
		_cam.look_at(Vector3(0.0, 4.3, 0.0))

	elif _frames == 42:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_sample_hybrid_closeup.png")
				print("✓ Close-up Híbrido guardado: alnus_sample_hybrid_closeup.png")

	# =========================================================================
	# MUESTRA 2: PURAS FOTOS NUEVAS (15-20m directo del tronco, sin rama procedural)
	# =========================================================================
	elif _frames == 45:
		_tree_view.foliage_mode = 4 # Muestra 2: FullLimbPhotos
		# Vista frontal completa
		_cam.fov = 52.0
		_cam.position = Vector3(0.0, 9.5, 24.0)
		_cam.look_at(Vector3(0.0, 9.5, 0.0))

	elif _frames == 55:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_sample_full_photo.png")
				print("✓ Muestra 2 guardada: alnus_sample_full_photo.png")

	elif _frames == 58:
		# Vista perspectiva 3/4 para apreciar volumen y extensión
		_cam.fov = 50.0
		_cam.position = Vector3(16.0, 9.0, 18.0)
		_cam.look_at(Vector3(0.0, 8.5, 0.0))

	elif _frames == 65:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_sample_full_photo_angle.png")
				print("✓ Muestra 2 perspectiva 3/4 guardada: alnus_sample_full_photo_angle.png")

	elif _frames == 68:
		# Close-up del tronco y collar donde nacen las ramas fotográficas
		_cam.fov = 52.0
		_cam.position = Vector3(2.5, 5.2, 5.0)
		_cam.look_at(Vector3(0.2, 4.6, 0.0))

	elif _frames == 75:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_sample_full_photo_closeup.png")
				print("✓ Close-up Puras Fotos guardado: alnus_sample_full_photo_closeup.png")

	elif _frames >= 80:
		quit(0)

	return false
