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

	# WorldEnvironment con cielo montañés luminoso idéntico a la foto de referencia
	_env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.74, 0.92) # Azul cielo montañés límpido
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.75, 0.85)
	env.ambient_light_energy = 0.85
	_env_node.environment = env
	root3d.add_child(_env_node)

	# Luz solar direccional idéntica a la foto (sol alto a la derecha, proyectando sombras cálidas)
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-42.0, 48.0, 0.0)
	_light.light_color = Color(1.0, 0.98, 0.90)
	_light.light_energy = 1.35
	_light.shadow_enabled = true
	root3d.add_child(_light)

	# Suelo sutil
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(80, 80)
	ground.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.42, 0.38, 0.30) # Camino de tierra montañosa
	ground.material_override = ground_mat
	root3d.add_child(ground)

	# Árbol Botánico Alnus Acuminata
	_tree_view = BotanicalTreeView.new()
	_tree_view.species_id = "alnus_acuminata"
	_tree_view.tree_seed = 12345
	_tree_view.age = 1.0 # Adulto maduro completo
	_tree_view.forced_lod = 0
	root3d.add_child(_tree_view)

	# Cámara
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 53.0
	root3d.add_child(_cam)
	_cam.look_at_from_position(Vector3(0.0, 9.5, 23.0), Vector3(0.0, 9.5, 0.0))

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Captura 1: Vista general adulta completa (LOD 0) - Comparativa con la foto
	if _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_photoreal_full.png")
				print("✓ Captura 1: alnus_photoreal_full.png guardada.")

	# Captura 2: Close-up de ramas y conexión con el tronco orgánico
	elif _frames == 30:
		_cam.fov = 60.0
		_cam.position = Vector3(2.2, 5.0, 4.8)
		_cam.look_at(Vector3(0.3, 4.6, 0.0))
	elif _frames == 40:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_branch_connection_closeup.png")
				print("✓ Captura 2: alnus_branch_connection_closeup.png guardada.")

	# Captura 2B: Close-up de la base del tronco (Root flare / Pata de elefante y corteza)
	elif _frames == 42:
		_cam.fov = 48.0
		_cam.position = Vector3(1.6, 1.2, 2.4)
		_cam.look_at(Vector3(0.1, 0.8, 0.0))
	elif _frames == 52:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_trunk_bark_closeup.png")
				print("✓ Captura 2B: alnus_trunk_bark_closeup.png guardada.")

	# Captura 3: Transición otoñal dorada (autumn_factor = 1.0)
	elif _frames == 55:
		_tree_view.autumn_factor = 1.0
		_cam.fov = 53.0
		_cam.position = Vector3(0.0, 9.5, 23.0)
		_cam.look_at(Vector3(0.0, 9.5, 0.0))
	elif _frames == 68:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_autumn_golden.png")
				print("✓ Captura 3: alnus_autumn_golden.png guardada.")

	# Captura 4: Árbol joven / Brote (age = 0.25) con hojas tiernas (imágenes anteriores)
	elif _frames == 70:
		_tree_view.autumn_factor = 0.0
		_tree_view.age = 0.25
		_cam.fov = 48.0
		_cam.position = Vector3(0.0, 1.4, 3.8)
		_cam.look_at(Vector3(0.0, 1.1, 0.0))
	elif _frames == 85:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_young_sapling.png")
				print("✓ Captura 4: alnus_young_sapling.png guardada.")

	# Captura 5: Árbol en crecimiento medio (age = 0.52) en transición hacia boughs
	elif _frames == 90:
		_tree_view.age = 0.52
		_cam.fov = 50.0
		_cam.position = Vector3(0.0, 4.2, 10.5)
		_cam.look_at(Vector3(0.0, 4.0, 0.0))
	elif _frames == 105:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/alnus_mid_growth.png")
				print("✓ Captura 5: alnus_mid_growth.png guardada.")
		quit(0)
		return true

	return false
