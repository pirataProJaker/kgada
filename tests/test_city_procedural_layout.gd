extends Node3D
## Escena de prueba e inspección visual del Sistema de Trazado de Ciudades y Avenidas Procedurales.
## Permite alternar en tiempo real entre patrones de avenidas (boulevard arbolado, arroyo, comercial),
## patrones de colonia (retícula escalonada, cerradas, bucles) y volar libremente sobre la ciudad.

const CityLayoutGenerator = preload("res://world/city/city_layout_generator.gd")
const CityRoadPatterns = preload("res://world/city/city_road_patterns.gd")

var _city: CityLayoutGenerator
var _camera: Camera3D
var _mode_label: Label
var _stats_label: Label

var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.60
const CAM_MOVE_SPEED := 35.0
var _mouse_captured: bool = false
var is_capture_mode: bool = false


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_city()
	_setup_ui()

	if DisplayServer.get_name() == "headless" and not is_capture_mode:
		_run_headless_verification()


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
	sun.rotation_degrees = Vector3(-60.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	# Suelo verde pasto natural circundante
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
	_camera.name = "FlyCamera"
	_camera.current = true
	_camera.fov = 65.0
	_camera.far = 1200.0
	_camera.position = Vector3(0.0, 90.0, 150.0)
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)


func _setup_city() -> void:
	_city = CityLayoutGenerator.new()
	_city.name = "City"
	_city.city_length = 240.0
	_city.neighborhood_blocks_per_side = 2
	_city.avenue_type = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
	_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID
	_city.generate_houses = true
	_city.scatter_decorations = true
	_city.show_parcel_outlines = true
	add_child(_city)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(500, 280)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "GENERADOR PROCEDURAL DE CIUDADES Y AVENIDAS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 13)
	_mode_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	vbox.add_child(_mode_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vbox.add_child(_stats_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var help := Label.new()
	help.text = "[1] Boulevard Camellón | [2] Avenida Arroyo | [3] Avenida Comercial\n[4] Colonia Escalonada | [5] Colonia Bucles | [6] Cerradas (Cul-de-sacs)\n[R] Semilla Aleatoria | [H] Alternar Casas | [P] Alternar Lotes\n[WASD/Shift] Volar libremente | [Q/E] Subir/Bajar | [Click Izq/ESC] Capturar Mouse"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.65, 0.80, 1.0))
	vbox.add_child(help)

	_update_ui_labels()


func _update_ui_labels() -> void:
	if _mode_label == null:
		return

	var ave_name := ""
	match _city.avenue_type:
		CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD:
			ave_name = "Boulevard con Camellón Arbolado (Doble Calzada)"
		CityRoadPatterns.AvenueType.STREAM_PARKWAY:
			ave_name = "Avenida con Arroyo/Canal Natural y Puentes"
		CityRoadPatterns.AvenueType.COMMERCIAL_MAIN:
			ave_name = "Avenida Comercial Ancha Directa"

	var hood_name := ""
	match _city.neighborhood_pattern:
		CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID:
			hood_name = "Colonia en Retícula Escalonada (T-Junctions)"
		CityRoadPatterns.NeighborhoodPattern.RESIDENTIAL_LOOPS:
			hood_name = "Colonia con Bucles Residenciales"
		CityRoadPatterns.NeighborhoodPattern.CUL_DE_SAC_SUBURB:
			hood_name = "Colonia con Cerradas Residenciales (Cul-de-sacs)"

	_mode_label.text = "Avenida: %s\nPatrón Colonia: %s" % [ave_name, hood_name]
	_stats_label.text = "Semilla: %d | Largo Ciudad: %.0fm\nTotal Manzanas: %d | Total Lotes/Parcelas: %d | Casas: %s" % [
		_city.rng_seed,
		_city.city_length,
		_city.block_rects.size(),
		_city.block_parcels.size(),
		"Sí" if _city.generate_houses else "No"
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_city.avenue_type = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
				_city.generate_city()
				_update_ui_labels()
			KEY_2:
				_city.avenue_type = CityRoadPatterns.AvenueType.STREAM_PARKWAY
				_city.generate_city()
				_update_ui_labels()
			KEY_3:
				_city.avenue_type = CityRoadPatterns.AvenueType.COMMERCIAL_MAIN
				_city.generate_city()
				_update_ui_labels()
			KEY_4:
				_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID
				_city.generate_city()
				_update_ui_labels()
			KEY_5:
				_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.RESIDENTIAL_LOOPS
				_city.generate_city()
				_update_ui_labels()
			KEY_6:
				_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.CUL_DE_SAC_SUBURB
				_city.generate_city()
				_update_ui_labels()
			KEY_R:
				_city.randomize_seed_on_run = true
				_city.generate_city()
				_update_ui_labels()
			KEY_H:
				_city.generate_houses = not _city.generate_houses
				_city.generate_city()
				_update_ui_labels()
			KEY_P:
				_city.show_parcel_outlines = not _city.show_parcel_outlines
				_city.generate_city()
				_update_ui_labels()
			KEY_ESCAPE:
				_mouse_captured = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_captured = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and _mouse_captured:
		_cam_yaw -= event.relative.x * 0.003
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -1.4, 1.4)
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _process(delta: float) -> void:
	if _camera == null:
		return

	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move -= _camera.transform.basis.z
	if Input.is_physical_key_pressed(KEY_S):
		move += _camera.transform.basis.z
	if Input.is_physical_key_pressed(KEY_A):
		move -= _camera.transform.basis.x
	if Input.is_physical_key_pressed(KEY_D):
		move += _camera.transform.basis.x
	if Input.is_physical_key_pressed(KEY_E):
		move += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		move -= Vector3.UP

	if move.length_squared() > 0.001:
		var speed := CAM_MOVE_SPEED * (2.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		_camera.position += move.normalized() * speed * delta


func _run_headless_verification() -> void:
	print("[TestCityProceduralLayout] Ejecutando verificación headless...")
	var segments := _city._road_system.get_all_segments()
	if segments.size() < 10:
		push_error("Error: Tramos viales insuficientes: %d" % segments.size())
		get_tree().quit(1)
		return

	if _city.block_rects.size() < 4:
		push_error("Error: Manzanas insuficientes: %d" % _city.block_rects.size())
		get_tree().quit(1)
		return

	if _city.block_parcels.size() < 15:
		push_error("Error: Parcelas insuficientes: %d" % _city.block_parcels.size())
		get_tree().quit(1)
		return

	var aabb := _city.get_generated_footprint_aabb()
	if aabb.size.x < 50.0 or aabb.size.z < 50.0:
		push_error("Error: Huella AABB de ciudad inválida: %s" % str(aabb))
		get_tree().quit(1)
		return

	print("[TestCityProceduralLayout] Éxito: %d tramos viales, %d manzanas, %d parcelas, AABB=%s verificados." % [
		segments.size(), _city.block_rects.size(), _city.block_parcels.size(), str(aabb)
	])
	get_tree().quit(0)
