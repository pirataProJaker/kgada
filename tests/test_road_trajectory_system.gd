extends Node3D
## Escena de prueba del Sistema de Carreteras por Trayectorias y Banquetas Paralelas.
## Permite definir trayectorias con el Plano de Carretera, construir tramos continuos
## a cualquier ángulo y colocar banquetas independientes en las orillas.

const RoadTrajectorySystem = preload("res://world/city/road_trajectory_system.gd")
const RoadBlueprintTool = preload("res://world/city/road_blueprint_tool.gd")

var _road_system: RoadTrajectorySystem
var _tool: RoadBlueprintTool
var _camera: Camera3D
var _mode_label: Label
var _stats_label: Label

# Control de cámara libre
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.50
const CAM_MOVE_SPEED := 24.0
var _mouse_captured: bool = false
var is_capture_mode: bool = false


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_road_system = RoadTrajectorySystem.new()
	_road_system.name = "RoadTrajectorySystem"
	add_child(_road_system)

	_tool = RoadBlueprintTool.new()
	_tool.name = "BlueprintTool"
	_tool.road_system = _road_system
	add_child(_tool)

	_setup_ui()

	# Crear trazado inicial de ejemplo
	_build_starter_network()

	if DisplayServer.get_name() == "headless" and not is_capture_mode:
		_run_headless_verification()


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.44, 0.60)
	sky_mat.sky_horizon_color = Color(0.70, 0.75, 0.82)
	sky_mat.ground_bottom_color = Color(0.16, 0.18, 0.20)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.65, 0.70, 0.75)
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	# Plano de suelo de referencia (hierba/tierra suave para resaltar el asfalto)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300.0, 300.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.32, 0.40, 0.28) # Verde pasto suave
	floor_mat.roughness = 0.95
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "InspectCamera"
	_camera.current = true
	_camera.fov = 65.0
	_camera.position = Vector3(0.0, 25.0, 35.0)
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(460, 260)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PLANOS DE CARRETERA Y TRAYECTORIAS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 14)
	_mode_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	vbox.add_child(_mode_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vbox.add_child(_stats_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var help := Label.new()
	help.text = "[1] Modo Plano (Dirección) | [2] Modo Constructor | [3] Herramienta Banqueta\n[Rueda / Flechas] Girar ángulo ±15°\n[Click Izquierdo] Confirmar dirección / Construir tramo / Poner banqueta\n[WASD/Shift] Volar libremente | [Q/E] Subir/Bajar | [Click/ESC] Mouse"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.65, 0.80, 1.0))
	vbox.add_child(help)

	_update_ui_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_tool.current_mode = RoadBlueprintTool.ToolMode.BLUEPRINT_DIRECTION
				_update_ui_labels()
			KEY_2:
				_tool.current_mode = RoadBlueprintTool.ToolMode.ROAD_BUILDER
				_update_ui_labels()
			KEY_3:
				_tool.current_mode = RoadBlueprintTool.ToolMode.SIDEWALK_PLACER
				_update_ui_labels()
			KEY_R:
				_build_starter_network()
			KEY_LEFT:
				_tool.rotate_direction(-15.0)
				_update_ui_labels()
			KEY_RIGHT:
				_tool.rotate_direction(15.0)
				_update_ui_labels()
			KEY_ESCAPE:
				_mouse_captured = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_tool.rotate_direction(15.0)
			_update_ui_labels()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_tool.rotate_direction(-15.0)
			_update_ui_labels()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var world_hit := _get_ground_cursor_pos()
			var used := _tool.handle_action_click(world_hit)
			if used:
				_update_ui_labels()
			else:
				_mouse_captured = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		if _mouse_captured:
			_cam_yaw -= event.relative.x * 0.003
			_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -1.4, 1.4)
			_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
		else:
			var hit_pos := _get_ground_cursor_pos()
			_tool.handle_cursor_hover(hit_pos)


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


func _get_ground_cursor_pos() -> Vector3:
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var from := _camera.project_ray_origin(mouse_pos)
	var dir := _camera.project_ray_normal(mouse_pos)

	if absf(dir.y) < 0.001:
		return from + dir * 20.0

	var t := -from.y / dir.y
	return from + dir * t


func _build_starter_network() -> void:
	_road_system.clear()

	# Tramo 1: Carretera recta inicial (sur a norte, 2 carriles estándar = 6.50m)
	var standard_w := 2.0 * RoadTrajectorySystem.STANDARD_LANE_WIDTH
	var ep0: RoadTrajectorySystem.RoadEndpoint = _road_system.add_endpoint(Vector3(0.0, 0.0, 20.0), Vector3.FORWARD, standard_w)
	var seg1: RoadTrajectorySystem.RoadSegment = _road_system.extend_road(ep0.id, 20.0)
	_road_system.toggle_sidewalk(seg1.id, true)  # Banqueta izquierda
	_road_system.toggle_sidewalk(seg1.id, false) # Banqueta derecha

	# Tramo 2: Extensión en diagonal (45 grados hacia la derecha / Noreste)
	var ep1: RoadTrajectorySystem.RoadEndpoint = _road_system.get_endpoint(seg1.end_endpoint_id)
	var dir_45 := Vector3(1.0, 0.0, -1.0).normalized()
	_road_system.set_endpoint_direction(ep1.id, dir_45)
	var seg2: RoadTrajectorySystem.RoadSegment = _road_system.extend_road(ep1.id, 18.0)
	_road_system.toggle_sidewalk(seg2.id, true)  # Banqueta izquierda
	_road_system.toggle_sidewalk(seg2.id, false) # Banqueta derecha

	# Tramo 3: Bifurcación en diagonal hacia la izquierda (-45 grados / Noroeste) desde el mismo cruce
	var dir_minus_45 := Vector3(-1.0, 0.0, -1.0).normalized()
	var seg3: RoadTrajectorySystem.RoadSegment = _road_system.extend_road(ep1.id, 18.0, dir_minus_45)
	_road_system.toggle_sidewalk(seg3.id, true)  # Banqueta izquierda
	_road_system.toggle_sidewalk(seg3.id, false) # Banqueta derecha

	_tool.selected_endpoint_id = seg2.end_endpoint_id
	var ep_end := _road_system.get_endpoint(seg2.end_endpoint_id)
	if ep_end != null:
		_tool.proposed_angle_degrees = RoadBlueprintTool.direction_to_angle(ep_end.direction)
	_update_ui_labels()
	print("[TestRoadTrajectory] Red de inicio construida con esquinas unidas y calzadas despejadas.")


func _update_ui_labels() -> void:
	if _mode_label == null:
		return

	var mode_text := ""
	match _tool.current_mode:
		RoadBlueprintTool.ToolMode.BLUEPRINT_DIRECTION:
			mode_text = "MODO ACTIVO: 📐 PLANO DE DIRECCIÓN"
		RoadBlueprintTool.ToolMode.ROAD_BUILDER:
			mode_text = "MODO ACTIVO: 🔨 CONSTRUCTOR DE CARRETERA"
		RoadBlueprintTool.ToolMode.SIDEWALK_PLACER:
			mode_text = "MODO ACTIVO: 🚶 HERRAMIENTA DE BANQUETA"

	_mode_label.text = mode_text
	_stats_label.text = "Ángulo Propuesto: %.1f°\nExtremo Seleccionado: #%d\nTotal Tramos Construidos: %d\nTotal Endpoints Abiertos: %d" % [
		_tool.proposed_angle_degrees,
		_tool.selected_endpoint_id,
		_road_system.get_all_segments().size(),
		_road_system.get_all_endpoints().size()
	]


func _run_headless_verification() -> void:
	print("[TestRoadTrajectory] Ejecutando verificación headless...")
	var segments := _road_system.get_all_segments()
	if segments.size() < 3:
		push_error("Error: Tramos insuficientes generados: %d" % segments.size())
		get_tree().quit(1)
		return

	# Verificar colisiones generadas
	var col_count := 0
	for child in _road_system._static_body.get_children():
		if child is CollisionShape3D:
			col_count += 1

	if col_count < 3:
		push_error("Error: Colisiones insuficientes generadas: %d" % col_count)
		get_tree().quit(1)
		return

	print("[TestRoadTrajectory] Éxito: %d tramos y %d colisiones verificadas." % [segments.size(), col_count])
	get_tree().quit(0)
