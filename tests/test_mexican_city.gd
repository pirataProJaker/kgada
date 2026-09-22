extends Node3D
## Escena interactiva de inspección y vuelo libre de la Ciudad Procedural Mexicana.
## Permite explorar la ciudad con presets de cámara en el Zócalo, Barrio Tradicional,
## Infonavit y Zona Residencial, además de alternar iluminación y avenidas en tiempo real.

const MexicanCityGenerator = preload("res://world/city/mexican_city_generator.gd")
const CityRoadPatterns = preload("res://world/city/city_road_patterns.gd")

enum LightingMode {
	SUNNY_DAY = 0,
	GOLDEN_HOUR = 1,
	URBAN_NIGHT = 2
}

var _city: MexicanCityGenerator
var _camera: Camera3D
var _sun: DirectionalLight3D
var _world_env: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial
var _mode_label: Label
var _stats_label: Label

var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.55
const CAM_MOVE_SPEED := 35.0
var _mouse_captured: bool = false
var is_capture_mode: bool = false
var _current_lighting: LightingMode = LightingMode.SUNNY_DAY


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_city()
	_setup_ui()

	if DisplayServer.get_name() == "headless" and not is_capture_mode:
		_run_headless_verification()


func _setup_environment() -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color(0.25, 0.45, 0.72)
	_sky_mat.sky_horizon_color = Color(0.74, 0.80, 0.88)
	_sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)

	var sky := Sky.new()
	sky.sky_material = _sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58.0, 38.0, 0.0)
	_sun.light_color = Color(1.0, 0.96, 0.88)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	add_child(_sun)

	# Terreno base circundante
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1000.0, 1000.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.28, 0.38, 0.22)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	add_child(ground)


var _is_rmb_dragging: bool = false


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "FlyCamera"
	_camera.current = true
	_camera.fov = 65.0
	_camera.far = 1400.0
	_set_camera_preset(1) # Panorámica por defecto
	add_child(_camera)

	# Capturar cursor automáticamente al iniciar para mirar libremente con el mouse
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = true


func _setup_city() -> void:
	_city = MexicanCityGenerator.new()
	_city.name = "MexicanCity"
	_city.city_length = 360.0
	_city.neighborhood_blocks_per_side = 2
	_city.neighborhood_zone = CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS
	_city.avenue_type = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
	_city.neighborhood_pattern = CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID
	_city.generate_houses = true
	_city.scatter_decorations = true
	_city.generate_zocalo = true
	_city.generate_corner_tienditas = true
	_city.show_parcel_outlines = false
	add_child(_city)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	_mode_label = Label.new()
	_mode_label.text = "CIUDAD PROCEDURAL MEXICANA (Play Sector X)"
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_mode_label)

	_stats_label = Label.new()
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_stats_label)

	var help_label := Label.new()
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.text = """
Presets de Cámara:
  [1] Panorámica General aérea
  [2] Zócalo / Plaza Mayor (Quiosco & Jardineras)
  [3] Barrio Tradicional (Pared con Pared & Tienditas)
  [4] Fraccionamiento Infonavit (Casas Serializadas)
  [5] Zona Residencial Las Lomas (Zona X Mansiones)

Controles Interactivos:
  [R] Regenerar Ciudad con Nueva Semilla
  [T] Alternar Avenida (Boulevard / Arroyo / Comercial)
  [L] Alternar Iluminación (Día / Atardecer / Noche)
  [P] Alternar Catastro de Lotes
  [Mouse] Mirar libremente | [Clic Izq / Clic Der] Capturar | [ESC] Liberar cursor
  [WASD / Shift / QE] Volar | [Rueda Mouse] Zoom
"""
	vbox.add_child(help_label)
	_update_ui_labels()


func _update_ui_labels() -> void:
	if _stats_label == null or _city == null:
		return

	var av_name := "Boulevard Camellón"
	match _city.avenue_type:
		CityRoadPatterns.AvenueType.STREAM_PARKWAY: av_name = "Arroyo Pluvial"
		CityRoadPatterns.AvenueType.COMMERCIAL_MAIN: av_name = "Avenida Comercial"

	var light_name := "Día Soleado"
	match _current_lighting:
		LightingMode.GOLDEN_HOUR: light_name = "Atardecer Dorado (Golden Hour)"
		LightingMode.URBAN_NIGHT: light_name = "Noche Urbana"

	var house_count := _city._house_generator.generated_houses.size() if _city._house_generator != null else 0
	var vacant_count := _city._house_generator.vacant_parcels.size() if _city._house_generator != null else 0

	_stats_label.text = """Avenida: %s | Iluminación: %s
Manzanas: %d | Terrenos: %d | Casas: %d | Baldíos: %d
Zócalo: %s | Tienditas en esquina: %s
""" % [
		av_name,
		light_name,
		_city.block_rects.size(),
		_city.block_parcels.size(),
		house_count,
		vacant_count,
		"Activo (Quiosco + 4 Árboles)" if _city.generate_zocalo else "Inactivo",
		"Activas" if _city.generate_corner_tienditas else "Inactivas"
	]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_camera_preset(1)
			KEY_2: _set_camera_preset(2)
			KEY_3: _set_camera_preset(3)
			KEY_4: _set_camera_preset(4)
			KEY_5: _set_camera_preset(5)

			KEY_R:
				_city.randomize_seed_on_run = true
				_city.generate_city()
				_update_ui_labels()

			KEY_T:
				var next_av := (_city.avenue_type + 1) % 3
				_city.avenue_type = next_av as CityRoadPatterns.AvenueType
				_city.generate_city()
				_update_ui_labels()

			KEY_L:
				_current_lighting = ((_current_lighting + 1) % 3) as LightingMode
				_apply_lighting_mode(_current_lighting)
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


func _set_camera_preset(preset: int) -> void:
	match preset:
		1:
			# Panorámica general aérea
			_camera.position = Vector3(0.0, 140.0, 220.0)
			_cam_yaw = 0.0
			_cam_pitch = -0.58
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		2:
			# Zócalo / Plaza Mayor (Vista de peatón / Quiosco)
			var z_pos := Vector3(-45.0, 12.0, 45.0)
			if _city != null and _city.zocalo_node != null:
				z_pos = _city.zocalo_node.position + Vector3(0.0, 10.0, 35.0)
			_camera.position = z_pos
			_cam_yaw = 0.0
			_cam_pitch = -0.22
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		3:
			# Barrio Tradicional (Colonia Vieja pared con pared)
			_camera.position = Vector3(-65.0, 14.0, -40.0)
			_cam_yaw = 0.85
			_cam_pitch = -0.20
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		4:
			# Fraccionamiento Infonavit (Casas serializadas)
			_camera.position = Vector3(65.0, 16.0, 50.0)
			_cam_yaw = -0.75
			_cam_pitch = -0.25
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		5:
			# Zona Residencial / Las Lomas (Zona X Fincas)
			_camera.position = Vector3(110.0, 22.0, -110.0)
			_cam_yaw = -2.20
			_cam_pitch = -0.25
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _apply_lighting_mode(mode: LightingMode) -> void:
	match mode:
		LightingMode.SUNNY_DAY:
			_sun.rotation_degrees = Vector3(-58.0, 38.0, 0.0)
			_sun.light_color = Color(1.0, 0.96, 0.88)
			_sun.light_energy = 1.35
			_sky_mat.sky_top_color = Color(0.25, 0.45, 0.72)
			_sky_mat.sky_horizon_color = Color(0.74, 0.80, 0.88)
			_world_env.environment.ambient_light_energy = 1.2

		LightingMode.GOLDEN_HOUR:
			_sun.rotation_degrees = Vector3(-18.0, 52.0, 0.0)
			_sun.light_color = Color(1.0, 0.68, 0.38) # Luz dorada/ámbar de atardecer
			_sun.light_energy = 1.55
			_sky_mat.sky_top_color = Color(0.35, 0.28, 0.52) # Violeta / naranja
			_sky_mat.sky_horizon_color = Color(0.92, 0.54, 0.28)
			_world_env.environment.ambient_light_energy = 0.95

		LightingMode.URBAN_NIGHT:
			_sun.rotation_degrees = Vector3(-80.0, 10.0, 0.0)
			_sun.light_color = Color(0.40, 0.48, 0.65) # Luz de luna suave
			_sun.light_energy = 0.15
			_sky_mat.sky_top_color = Color(0.04, 0.06, 0.12)
			_sky_mat.sky_horizon_color = Color(0.10, 0.14, 0.22)
			_world_env.environment.ambient_light_energy = 0.35


func _process(delta: float) -> void:
	if _camera == null:
		return

	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): move -= _camera.transform.basis.z
	if Input.is_physical_key_pressed(KEY_S): move += _camera.transform.basis.z
	if Input.is_physical_key_pressed(KEY_A): move -= _camera.transform.basis.x
	if Input.is_physical_key_pressed(KEY_D): move += _camera.transform.basis.x
	if Input.is_physical_key_pressed(KEY_E): move += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q): move -= Vector3.UP

	if move.length_squared() > 0.001:
		var speed := CAM_MOVE_SPEED * (2.8 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		_camera.position += move.normalized() * speed * delta


func _run_headless_verification() -> void:
	print("[TestMexicanCity] Ejecutando verificación de Ciudad Procedural Mexicana...")

	_city.generate_city()

	# 1. Comprobar que existe el Zócalo
	if _city.zocalo_node == null:
		push_error("Error: Zócalo no generado.")
		get_tree().quit(1)
		return

	var kiosk = _city.zocalo_node.get_node_or_null("KioscoCentral")
	if kiosk == null:
		push_error("Error: Quiosco central no encontrado en Zócalo.")
		get_tree().quit(1)
		return

	var gardens = _city.zocalo_node.get_node_or_null("JardinerasZocalo")
	if gardens == null or gardens.get_child_count() == 0:
		push_error("Error: Jardineras con árboles no encontradas en Zócalo.")
		get_tree().quit(1)
		return

	# 2. Comprobar la generación de casas en las 3 zonas
	var houses := _city._house_generator.generated_houses
	if houses.size() < 50:
		push_error("Error: Conteo insuficiente de casas (%d)." % houses.size())
		get_tree().quit(1)
		return

	var zones_found := {}
	for h in houses:
		var z = h.get("zone_type", -1)
		zones_found[z] = zones_found.get(z, 0) + 1

	print("[TestMexicanCity] Zonas generadas:", zones_found)
	if not zones_found.has(CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA) or \
	   not zones_found.has(CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA) or \
	   not zones_found.has(CityRoadPatterns.NeighborhoodZoneType.ZONA_X):
		push_error("Error: Falta alguna de las 3 tipologías residenciales mexicanas.")
		get_tree().quit(1)
		return

	# 3. Comprobar que las tienditas se hayan generado
	if _city.tienditas_root == null or _city.tienditas_root.get_child_count() == 0:
		push_error("Error: Tienditas de la esquina no generadas.")
		get_tree().quit(1)
		return

	print("[TestMexicanCity] ¡ÉXITO! Ciudad Mexicana generada con Zócalo, Quiosco, Jardineras, %d casas y %d tienditas de esquina." % [
		houses.size(), _city.tienditas_root.get_child_count() / 2
	])
	get_tree().quit(0)
