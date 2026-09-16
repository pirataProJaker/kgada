extends Node3D

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/921de2e6-895f-493c-ab6c-3bf9c7f89e6f"

var _city: CityLayoutGenerator
var _camera: Camera3D

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_city()
	_run_captures()

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.42, 0.62)
	sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.85)
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.68, 0.72, 0.78)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 800.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.30, 0.42, 0.24)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	add_child(ground)

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CaptureCamera"
	_camera.current = true
	_camera.fov = 65.0
	_camera.far = 1500.0
	add_child(_camera)

func _setup_city() -> void:
	_city = CityLayoutGenerator.new()
	_city.name = "City"
	_city.city_length = 240.0
	_city.neighborhood_blocks_per_side = 2
	_city.generate_houses = true
	_city.scatter_decorations = true
	_city.show_parcel_outlines = false
	add_child(_city)

func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _capture_and_save(filename: String) -> void:
	await _wait_frames(5)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var target_path := ARTIFACT_DIR + "/" + filename
		img.save_png(target_path)
		print("[CaptureProceduralCity] Guardada: ", filename)

func _run_captures() -> void:
	await _wait_frames(10)

	# 1. Divided Boulevard (Boulevard con camellón arbolado) - Vista Aérea
	_city.avenue_type = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
	_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID
	_city.generate_city()
	_camera.position = Vector3(100.0, 100.0, 110.0)
	_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	await _capture_and_save("avenue_boulevard_overview.png")

	# 2. Divided Boulevard - Vista a Nivel de Calle (carril derecho viendo camellón con árboles)
	_camera.position = Vector3(10.0, 2.8, 75.0)
	_camera.look_at(Vector3(6.0, 2.0, -30.0), Vector3.UP)
	await _capture_and_save("avenue_boulevard_street.png")

	# 3. Stream Parkway (Avenida con Arroyo/Canal y Vegetación de Ribera)
	_city.avenue_type = CityRoadPatterns.AvenueType.STREAM_PARKWAY
	_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.CUL_DE_SAC_SUBURB
	_city.generate_city()
	_camera.position = Vector3(15.0, 6.0, 35.0)
	_camera.look_at(Vector3(0.0, -0.5, 10.0), Vector3.UP)
	await _capture_and_save("avenue_stream_parkway.png")

	# 4. Commercial Main (Avenida Comercial Ancha)
	_city.avenue_type = CityRoadPatterns.AvenueType.COMMERCIAL_MAIN
	_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.RESIDENTIAL_LOOPS
	_city.generate_city()
	_camera.position = Vector3(60.0, 45.0, 70.0)
	_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	await _capture_and_save("avenue_commercial_main.png")

	# 5. Acercamiento Cruce + (4-way cross intersection) en la colonia
	_city.avenue_type = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
	_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.RESIDENTIAL_LOOPS
	_city.generate_city()
	_camera.position = Vector3(-40.0, 22.0, 56.0)
	_camera.look_at(Vector3(-53.0, 0.0, 40.0), Vector3.UP)
	await _capture_and_save("cross_intersection_closeup.png")

	# 6. Cruce + a nivel de calle
	_camera.position = Vector3(-53.0, 1.8, 55.0)
	_camera.look_at(Vector3(-53.0, 0.5, 40.0), Vector3.UP)
	await _capture_and_save("cross_intersection_street.png")

	# 7. Acercamiento Cruce en T exterior
	_camera.position = Vector3(-80.0, 18.0, 55.0)
	_camera.look_at(Vector3(-93.0, 0.0, 40.0), Vector3.UP)
	await _capture_and_save("t_junction_closeup.png")

	# 8. Acercamiento Cruce de Avenida y Calle Colectora
	_camera.position = Vector3(5.0, 20.0, 55.0)
	_camera.look_at(Vector3(-8.5, 0.0, 40.0), Vector3.UP)
	await _capture_and_save("avenue_junction_closeup.png")

	# 9. Verificación Bug 1: Esquina exterior (donde antes salía la ranura verde de pasto)
	_camera.position = Vector3(-117.0, 16.0, -108.0)
	_camera.look_at(Vector3(-117.0, 0.0, -120.0), Vector3.UP)
	await _capture_and_save("outer_corner_closeup.png")

	# 10. Verificación Bug 2: Cruce en T (donde antes se desfasaba la banqueta entre cuadras)
	_camera.position = Vector3(-125.0, 18.0, -70.0)
	_camera.look_at(Vector3(-117.0, 0.0, -80.0), Vector3.UP)
	await _capture_and_save("t_junction_step_closeup.png")

	# 11. Verificación Bug 3: Extremo Norte de la Avenida con banqueta continua de cerramiento
	_camera.position = Vector3(0.0, 24.0, -100.0)
	_camera.look_at(Vector3(0.0, 0.0, -120.0), Vector3.UP)
	await _capture_and_save("avenue_end_closeup.png")

	# 12. Verificación Z-fighting: Acercamiento rasante a la esquina exterior
	_camera.position = Vector3(-114.0, 4.0, -115.0)
	_camera.look_at(Vector3(-121.5, 0.2, -124.5), Vector3.UP)
	await _capture_and_save("corner_z_fighting_fixed.png")

	print("[CaptureProceduralCity] Todas las capturas completadas con éxito.")
	get_tree().quit(0)
