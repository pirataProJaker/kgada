extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/d7b9b686-f79d-420d-8d57-bd09152134d2"
const PROCEDURAL_SKY_SHADER := preload("res://shaders/procedural_math_sky.gdshader")

var _camera: Camera3D
var _world_env: WorldEnvironment
var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _day_night: DayNightCycle
var _holder: Node3D

func _initialize() -> void:
	_holder = Node3D.new()
	_holder.name = "SkyShowcaseHolder"
	root.add_child(_holder)
	
	_setup_scene()
	_run_captures()

func _setup_scene() -> void:
	# 1. Shader Material & Sky
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = PROCEDURAL_SKY_SHADER
	
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.68, 0.76, 0.85)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	
	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = env
	_holder.add_child(_world_env)
	
	# 2. Sol
	_sun = DirectionalLight3D.new()
	_sun.name = "DirectionalLight3D"
	_sun.shadow_enabled = true
	_holder.add_child(_sun)
	
	# 3. DayNightCycle oficial del proyecto
	_day_night = DayNightCycle.new()
	_day_night.cycle_duration = 0.0
	_day_night.sun_path = NodePath("../DirectionalLight3D")
	_day_night.world_env_path = NodePath("../WorldEnvironment")
	_holder.add_child(_day_night)
	
	# 4. Terreno simple con pasto
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.20, 0.32, 0.16)
	ground_mat.roughness = 0.9
	ground.material_override = ground_mat
	_holder.add_child(ground)
	
	# 5. Árboles procedurales
	for i in range(12):
		var tree := ProceduralTree.new()
		tree.profile_id = "classic_oak"
		tree.tree_seed = 500 + i * 37
		var angle := float(i) * 0.32 - 1.6
		var dist := 28.0 + float(i % 3) * 10.0
		tree.position = Vector3(sin(angle) * dist, 0.0, -cos(angle) * dist)
		_holder.add_child(tree)
	
	# 6. Cámara mirando hacia el cielo y el horizonte
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 70.0
	_camera.position = Vector3(0.0, 2.0, 0.0)
	_camera.rotation_degrees = Vector3(26.0, 0.0, 0.0)
	_holder.add_child(_camera)

func _wait_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _capture_and_save(filename: String) -> void:
	await _wait_frames(8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null:
		var target_path := ARTIFACT_DIR + "/" + filename
		img.save_png(target_path)
		print("[SkyCapture] Exito: ", filename)
	else:
		printerr("[SkyCapture] Error: get_image() nulo")

func _run_captures() -> void:
	await _wait_frames(15)
	
	# 1. Nivel 2: Nubes Naturales Cinemáticas a Mediodía (Cúmulos + Claros + Cirros)
	_sky_mat.set_shader_parameter("cloud_quality", 2)
	_sky_mat.set_shader_parameter("cloud_coverage", 0.54)
	_sky_mat.set_shader_parameter("cloud_clustering", 0.65)
	_day_night.set_time(0.50)
	_camera.rotation_degrees = Vector3(34.0, 15.0, 0.0)
	await _capture_and_save("cielo_natural_mediodia.png")
	
	# 2. Nivel 2: Nubes Naturales al Atardecer (Mirando hacia el sol poniente, colores cálidos)
	_day_night.set_time(0.74)
	_camera.rotation_degrees = Vector3(18.0, 65.0, 0.0)
	await _capture_and_save("cielo_natural_atardecer.png")
	
	# 3. Nivel 1: Nubes Básicas / Rápidas (Económicas 1-pass)
	_sky_mat.set_shader_parameter("cloud_quality", 1)
	_day_night.set_time(0.50)
	_camera.rotation_degrees = Vector3(26.0, 25.0, 0.0)
	await _capture_and_save("cielo_basico_economico.png")
	
	# 4. Nivel 0: Sin Nubes (Cielo Despejado Puro)
	_sky_mat.set_shader_parameter("cloud_quality", 0)
	_day_night.set_time(0.50)
	_camera.rotation_degrees = Vector3(26.0, 25.0, 0.0)
	await _capture_and_save("cielo_despejado_sin_nubes.png")
	
	print("--- CAPTURAS TERMINADAS ---")
	quit(0)
