extends SceneTree

const WindowGrilleSystem = preload("res://world/building/window_grille_system.gd")
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

var _frames := 0
var _root: Node3D

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.65, 0.75, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.ambient_light_energy = 1.0
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_root.add_child(sun)

	# Crear una pared de fondo con 4 ventanas
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.85, 0.83, 0.78)
	wall_mat.roughness = 0.90

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.25, 0.45, 0.65, 0.60)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.15

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.95, 0.95, 0.95)

	# 4 estilos:
	# 0: HORIZONTAL_BARS
	# 1: FLOATING_LOOPS
	# 2: GEOMETRIC_GRID
	# 3: VERTICAL_BARS
	var styles = [
		{"name": "Barrotes Horizontales", "style": 0, "color": Color(0.12, 0.12, 0.13, 1.0), "x": -4.2},
		{"name": "Marcos Flotantes", "style": 1, "color": Color(0.12, 0.12, 0.13, 1.0), "x": -1.4},
		{"name": "Retícula Geométrica", "style": 2, "color": Color(0.24, 0.16, 0.12, 1.0), "x": 1.4},
		{"name": "Barrotes Verticales", "style": 3, "color": Color(0.92, 0.93, 0.94, 1.0), "x": 4.2}
	]

	var w_size := Vector2(1.8, 1.4)

	# Muro largo
	var wall_mesh := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(14.0, 3.5, 0.20)
	wall_mesh.mesh = wall_box
	wall_mesh.material_override = wall_mat
	wall_mesh.position = Vector3(0.0, 1.75, 0.0)
	_root.add_child(wall_mesh)

	for item in styles:
		var cx: float = item["x"]
		var s_idx: int = item["style"]
		var col: Color = item["color"]

		# Marco blanco
		var f_mesh := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(w_size.x + 0.08, w_size.y + 0.08, 0.22)
		f_mesh.mesh = f_box
		f_mesh.material_override = frame_mat
		f_mesh.position = Vector3(cx, 1.75, 0.0)
		_root.add_child(f_mesh)

		# Cristal
		var g_mesh := MeshInstance3D.new()
		var g_box := BoxMesh.new()
		g_box.size = Vector3(w_size.x, w_size.y, 0.04)
		g_mesh.mesh = g_box
		g_mesh.material_override = glass_mat
		g_mesh.position = Vector3(cx, 1.75, 0.0)
		_root.add_child(g_mesh)

		# Reja de protección procedural
		var grille_img := WindowGrilleSystem.generate_grille_image(s_idx, col, 1234, w_size.x, w_size.y)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.50
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.85
		mat.albedo_texture = ImageTexture.create_from_image(grille_img)

		var q_mesh := MeshInstance3D.new()
		q_mesh.mesh = WindowGrilleSystem.get_unit_quad()
		q_mesh.material_override = mat
		q_mesh.position = Vector3(cx, 1.75, 0.12)
		q_mesh.scale = Vector3(w_size.x, w_size.y, 1.0)
		_root.add_child(q_mesh)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.75, 6.2)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.75, 0.0), Vector3.UP)
	cam.fov = 55.0
	_root.add_child(cam)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	if _frames == 12:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_all_4_grille_styles.png")
				print("✓ Comparativa de los 4 Estilos guardada: verify_all_4_grille_styles.png")
	elif _frames >= 16:
		quit(0)

	return false
