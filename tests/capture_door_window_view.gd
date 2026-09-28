extends SceneTree

const ARTIFACT_DIR := "C:/Users/PC 1/.gemini/antigravity-ide/brain/7665bda4-35a4-4713-97f9-d4941a9911be"

var _camera: Camera3D
var _scene_root: Node3D
var _engine: Node3D

func _init() -> void:
	print("🔍 [CaptureDoorWindow] Inicializando render visual...")

	_scene_root = Node3D.new()
	root.add_child(_scene_root)

	var sun := DirectionalLight3D.new()
	sun.transform.basis = Basis.looking_at(Vector3(-0.5, -0.7, -0.4).normalized(), Vector3.UP)
	sun.position = Vector3(0, 15, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	_scene_root.add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.70, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 1.0
	env_node.environment = env
	_scene_root.add_child(env_node)

	# Suelo césped
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.28, 0.48, 0.22)
	plane.material = ground_mat
	ground.mesh = plane
	_scene_root.add_child(ground)

	# ConstructionEngine
	var engine_script = load("res://rust_core/src/construction/engine_node.rs")
	if ClassDB.class_exists("ConstructionEngine"):
		_engine = ClassDB.instantiate("ConstructionEngine")
	else:
		_engine = Node3D.new()
	_scene_root.add_child(_engine)

	# 1. Construir piso de 6m x 6m (y=0.0) de Madera
	_engine.call("add_floor_span", Vector3(-3, 0, -3), Vector3(3, 0, 3), 0)

	# 2. Construir pared sobre el borde norte (de x=-3 a 3, z=-2.9, y=0.20, h=3.0)
	# Apertura 1: Puerta en t=1.5..2.8 (ancho 1.30m, y=0.0..2.10)
	# Apertura 2: Ventana en t=3.8..5.2 (ancho 1.40m, y=1.0..2.20)
	var planned_site_script = load("res://world/building/planned_site.gd")
	var wall_site = planned_site_script.new()
	var p0 := Vector3(-3.0, 0.20, -2.9)
	var p1 := Vector3(3.0, 0.20, -2.9)
	wall_site.setup(1, p0, p1, {"name": "Palo de Trazado", "marker_type": "dirt_scrape"}, 3.0)
	_scene_root.add_child(wall_site)

	wall_site.add_door_opening(2.15, 1.30, 2.10)
	wall_site.add_window_opening(3.8, 5.2, 1.0, 2.2)

	# Construir la pared con madera
	wall_site.build_with_material(0, null, _engine)

	# Cámara orientada hacia la puerta y la ventana a la altura de los ojos
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 65.0
	_camera.position = Vector3(0.0, 1.6, 2.5)
	_camera.look_at(Vector3(0.0, 1.3, -2.9), Vector3.UP)
	_scene_root.add_child(_camera)

	# Esperar 4 frames para renderizado
	for i in range(5):
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	if img:
		var save_path := ARTIFACT_DIR + "/door_and_window_fixed_view.png"
		var err := img.save_png(save_path)
		print("📸 Captura guardada en: %s (Err: %d)" % [save_path, err])

	quit(0)
