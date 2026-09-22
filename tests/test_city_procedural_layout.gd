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
var _is_rmb_dragging: bool = false
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

	# Suelo verde pasto natural circundante a gran escala
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3500.0, 3500.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.26, 0.38, 0.20)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	add_child(ground)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "FlyCamera"
	_camera.current = true
	_camera.fov = 65.0
	_camera.far = 3500.0
	# Panorámica general aérea inicial a gran escala
	_camera.position = Vector3(0.0, 220.0, 380.0)
	_cam_yaw = 0.0
	_cam_pitch = -0.52
	_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	add_child(_camera)

	# Capturar cursor automáticamente al iniciar para mirar libremente con el mouse
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = true


func _setup_city() -> void:
	_city = CityLayoutGenerator.new()
	_city.name = "City"
	_city.city_length = 720.0
	_city.neighborhood_blocks_per_side = 4
	_city.avenue_type = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
	_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID
	_city.neighborhood_zone = CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS
	_city.generate_houses = true
	_city.scatter_decorations = true
	_city.show_parcel_outlines = false
	add_child(_city)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(500, 280)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "GENERADOR PROCEDURAL DE CIUDADES Y AVENIDAS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 13)
	_mode_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_mode_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_stats_label)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var help := Label.new()
	help.text = """Presets de Cámara:
  [1] Panorámica General Aérea (Toda la Metrópolis)
  [2] Gran Avenida Central (Boulevard Arbolado)
  [3] Sector Barrio Tradicional (Colonia Vieja pared con pared)
  [4] Sector Gran Fraccionamiento Infonavit (Casas Serializadas)
  [5] Sector Zona Residencial (Zona X Mansiones y Fincas)

Controles de Escala y Configuración:
  [+] Agrandar Metrópolis (+1 bloque por lado, +180m de largo)
  [-] Reducir Metrópolis
  [T] Alternar Avenida (Boulevard 6 carriles / Arroyo / Comercial)
  [Z] Alternar Zonificación (Macro-Colonias Mixtas / Solo Vieja / Solo Infonavit / Solo Zona X)
  [N] Alternar Traza de Calles (Escalonada / Bucles / Cerradas)
  [R] Regenerar Ciudad con Nueva Semilla | [H] Alternar Casas | [P] Alternar Catastro
  [Mouse] Mirar libremente | [Clic Izq / Clic Der] Capturar | [ESC] Liberar cursor
  [WASD / Shift / QE] Volar | [Rueda Mouse] Zoom"""
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.65, 0.80, 1.0))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(help)

	_update_ui_labels()


func _set_camera_preset(preset: int) -> void:
	if _camera == null:
		return
	match preset:
		1:
			# Panorámica General aérea de toda la metrópolis
			_camera.position = Vector3(0.0, 240.0, 420.0)
			_cam_yaw = 0.0
			_cam_pitch = -0.52
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		2:
			# Gran Avenida Central (Boulevard arbolado a ras de calle)
			_camera.position = Vector3(0.0, 12.0, 60.0)
			_cam_yaw = 0.0
			_cam_pitch = -0.12
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		3:
			# Sector Noroeste: Colonia Vieja (Barrio Tradicional, pared con pared)
			_camera.position = Vector3(-140.0, 16.0, -140.0)
			_cam_yaw = 0.85
			_cam_pitch = -0.20
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		4:
			# Sector Este: Gran Fraccionamiento Infonavit (Casas serializadas)
			_camera.position = Vector3(140.0, 16.0, 40.0)
			_cam_yaw = -0.75
			_cam_pitch = -0.22
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		5:
			# Sector Suroeste: Zona Residencial Las Lomas (Zona X Mansiones y Fincas)
			_camera.position = Vector3(-170.0, 22.0, 160.0)
			_cam_yaw = -2.20
			_cam_pitch = -0.25
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _update_ui_labels() -> void:
	if _mode_label == null or _city == null:
		return

	var av_name := "Boulevard con Camellón Arbolado"
	match _city.avenue_type:
		CityRoadPatterns.AvenueType.STREAM_PARKWAY: av_name = "Arroyo Pluvial Central"
		CityRoadPatterns.AvenueType.COMMERCIAL_MAIN: av_name = "Avenida Comercial Continua"

	var pat_name := "Cuadrícula Escalonada (Seguridad)"
	match _city.neighborhood_pattern:
		CityRoadPatterns.NeighborhoodPattern.RESIDENTIAL_LOOPS: pat_name = "Bucles Residenciales (Baja Velocidad)"
		CityRoadPatterns.NeighborhoodPattern.CUL_DE_SAC_SUBURB: pat_name = "Cerradas con Glorieta (Retorno)"

	var zone_name := "Macro-Colonias Mixtas (Barrio Tradicional + Infonavit + Zona X)"
	match _city.neighborhood_zone:
		CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA: zone_name = "Colonia Vieja (Lotes estrechos, casas pared con pared)"
		CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA: zone_name = "Colonia Nueva / Infonavit (Lotes idénticos serializados)"
		CityRoadPatterns.NeighborhoodZoneType.ZONA_X: zone_name = "Zona X / Ricos (Lotes gigantescos muy asimétricos)"

	_mode_label.text = "Avenida: %s\nPatrón: %s\nZonificación: %s" % [av_name, pat_name, zone_name]

	var house_count := _city._house_generator.generated_houses.size() if _city._house_generator != null else 0
	var vacant_count := _city._house_generator.vacant_parcels.size() if _city._house_generator != null else 0

	_stats_label.text = """Tramos viales generados: %d | Largo Ciudad: %.0fm (%d bloques/lado)
Manzanas construidas: %d | Parcelas delimitadas: %d
Casas levantadas: %d | Lotes baldíos: %d
Semilla actual: %d (Presiona R para nueva variante)""" % [
		_city._road_system.get_all_segments().size() if _city._road_system != null else 0,
		_city.city_length,
		_city.neighborhood_blocks_per_side,
		_city.block_rects.size(),
		_city.block_parcels.size(),
		house_count,
		vacant_count,
		_city.rng_seed
	]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_camera_preset(1)
			KEY_2: _set_camera_preset(2)
			KEY_3: _set_camera_preset(3)
			KEY_4: _set_camera_preset(4)
			KEY_5: _set_camera_preset(5)

			KEY_T:
				var next_av := (_city.avenue_type + 1) % 3
				_city.avenue_type = next_av as CityRoadPatterns.AvenueType
				_city.generate_city()
				_update_ui_labels()

			KEY_Z:
				var next_z := (_city.neighborhood_zone + 1) % 4
				_city.neighborhood_zone = next_z as CityRoadPatterns.NeighborhoodZoneType
				_city.generate_city()
				_update_ui_labels()

			KEY_N:
				var next_p := (_city.neighborhood_pattern + 1) % 3
				_city.neighborhood_pattern = next_p as CityRoadPatterns.NeighborhoodPattern
				_city.generate_city()
				_update_ui_labels()

			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				# Agrandar ciudad a gran escala
				_city.neighborhood_blocks_per_side = mini(_city.neighborhood_blocks_per_side + 1, 6)
				_city.city_length = minf(_city.city_length + 160.0, 1600.0)
				_city.generate_city()
				_update_ui_labels()
				_set_camera_preset(1)

			KEY_MINUS, KEY_KP_SUBTRACT:
				# Reducir ciudad
				_city.neighborhood_blocks_per_side = maxi(_city.neighborhood_blocks_per_side - 1, 2)
				_city.city_length = maxf(_city.city_length - 160.0, 360.0)
				_city.generate_city()
				_update_ui_labels()
				_set_camera_preset(1)

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
				_mouse_captured = not _mouse_captured
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_mouse_captured = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rmb_dragging = event.pressed
			if event.pressed:
				_mouse_captured = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if _camera != null:
				_camera.position -= _camera.transform.basis.z * 6.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if _camera != null:
				_camera.position += _camera.transform.basis.z * 6.0

	if event is InputEventMouseMotion:
		if _mouse_captured or _is_rmb_dragging:
			_cam_yaw -= event.relative.x * 0.003
			_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -1.45, 1.45)
			if _camera != null:
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
	print("[TestCityProceduralLayout] Ejecutando verificación headless de estándares métricos...")
	
	# Desactivar casas durante la verificación rápida de perfiles de avenida
	_city.generate_houses = false
	_city.scatter_decorations = false

	var test_types: Array[CityRoadPatterns.AvenueType] = [
		CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD,
		CityRoadPatterns.AvenueType.STREAM_PARKWAY,
		CityRoadPatterns.AvenueType.COMMERCIAL_MAIN
	]
	
	for av_type in test_types:
		_city.avenue_type = av_type
		_city.generate_city()
		
		var segments := _city._road_system.get_all_segments()
		if segments.size() < 10:
			push_error("Error: Tramos viales insuficientes para %s: %d" % [av_type, segments.size()])
			get_tree().quit(1)
			return

		var expected_width: float = CityRoadPatterns.get_avenue_config(av_type).roadway_width
		var found_avenue_seg := false
		for s_item in segments:
			var s: RoadTrajectorySystem.RoadSegment = s_item
			if absf(s.width - expected_width) < 0.01:
				found_avenue_seg = true
				break
		if not found_avenue_seg:
			push_error("Error: No se encontró tramo de avenida con ancho estandarizado %.2f para tipo %s" % [expected_width, av_type])
			get_tree().quit(1)
			return

		var aabb := _city.get_generated_footprint_aabb()
		print("[TestCityProceduralLayout] Tipo %s verificado: %d tramos, ancho avenida=%.2fm, AABB=%s" % [
			av_type, segments.size(), expected_width, str(aabb)
		])

	# Verificación final de la Gran Metrópolis con casas y colonias completas
	_city.generate_houses = true
	_city.scatter_decorations = true
	_city.avenue_type = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
	_city.neighborhood_zone = CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS
	_city.generate_city()

	var house_count := _city._house_generator.generated_houses.size() if _city._house_generator != null else 0
	print("[TestCityProceduralLayout] ¡ÉXITO! Gran Metrópolis generada: %d manzanas, %d parcelas, %d casas levantadas." % [
		_city.block_rects.size(), _city.block_parcels.size(), house_count
	])
	get_tree().quit(0)
