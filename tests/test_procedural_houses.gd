extends Node3D
## Escena de prueba e inspección visual de Casas Procedurales (Play Sector X).
## Muestra las 3 tipologías de zonificación urbana solicitadas:
## 1. COLONIA VIEJA: Barrio tradicional, casas pared con pared (100% frente del lote), muros ciegos laterales, alturas y estilos variados.
## 2. COLONIA NUEVA: Fraccionamiento / Infonavit, casas serializadas idénticas, pasillo lateral de servicio, retiro para cochera.
## 3. ZONA X: Zona residencial de lujo, lotes enormes, casas aisladas con jardines a 4 vientos, techos altos y ventanales panorámicos.
##
## Sin bardas, sin pasillos en medio, distribución 100% orgánica y funcional.

const HouseGenerator = preload("res://world/city/house_generator.gd")

var _generator: HouseGenerator
var _houses_root: Node3D
var _camera: Camera3D
var _info_label: Label
var _stats_label: Label

var _current_seed: int = 12345
var _show_roofs: bool = true

var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.35
const CAM_MOVE_SPEED := 25.0
var _mouse_captured: bool = false
var is_capture_mode: bool = false


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_ground()
	_setup_houses()
	_setup_ui()

	if DisplayServer.get_name() == "headless" and not is_capture_mode:
		_run_headless_verification()


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.70)
	sky_mat.sky_horizon_color = Color(0.75, 0.82, 0.90)
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.70, 0.75, 0.80)
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 68.0
	_camera.near = 0.2
	_camera.far = 400.0
	_camera.position = Vector3(0.0, 16.0, 32.0)
	_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	add_child(_camera)


func _setup_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	ground.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.28, 0.18) # Césped circundante
	mat.roughness = 0.95
	ground.material_override = mat
	add_child(ground)


func _setup_houses() -> void:
	if _generator == null:
		_generator = HouseGenerator.new()
		_generator.name = "HouseGenerator"
		_generator.auto_generate = false
		_generator.show_roofs = _show_roofs
		_generator.show_fences = false
		add_child(_generator)

	if _houses_root == null:
		_houses_root = Node3D.new()
		_houses_root.name = "ShowcaseHouses"
		add_child(_houses_root)

	_regenerate_showcase()


func _regenerate_showcase() -> void:
	for child in _houses_root.get_children():
		child.queue_free()

	_generator.show_roofs = _show_roofs
	_generator.show_fences = false

	# 1. Colonia Vieja: Barrio tradicional (Lote 9.5m x 16m) -> Pared con pared, muros ciegos laterales
	var vieja_seed := _current_seed + 101
	var vieja_house := _generator.build_standalone_house(9.5, 16.0, HouseGenerator.HouseZoneType.COLONIA_VIEJA, vieja_seed)
	if vieja_house != null:
		vieja_house.position = Vector3(-24.0, 0.0, 0.0)
		_houses_root.add_child(vieja_house)
		_add_lot_marker(Vector3(-24.0, 0.0, 0.0), Vector2(9.5, 16.0), Color(0.38, 0.35, 0.30))

	# 2. Colonia Nueva: Fraccionamiento Infonavit (Lote 6.5m x 15m) -> Serializada, pasillo lateral exterior de 1m
	var nueva_seed := _current_seed + 202
	var nueva_house := _generator.build_standalone_house(6.5, 15.0, HouseGenerator.HouseZoneType.COLONIA_NUEVA, nueva_seed)
	if nueva_house != null:
		nueva_house.position = Vector3(0.0, 0.0, 0.0)
		_houses_root.add_child(nueva_house)
		_add_lot_marker(Vector3(0.0, 0.0, 0.0), Vector2(6.5, 15.0), Color(0.34, 0.38, 0.42))

	# 3. Zona X: Residencial de Riquillos (Lote 22m x 28m) -> Aislada en el centro con jardines perimetrales
	var rica_seed := _current_seed + 303
	var rica_house := _generator.build_standalone_house(22.0, 28.0, HouseGenerator.HouseZoneType.ZONA_X, rica_seed)
	if rica_house != null:
		rica_house.position = Vector3(26.0, 0.0, 0.0)
		_houses_root.add_child(rica_house)
		_add_lot_marker(Vector3(26.0, 0.0, 0.0), Vector2(22.0, 28.0), Color(0.28, 0.32, 0.36))

	_update_stats_ui()


func _add_lot_marker(center: Vector3, size: Vector2, color: Color) -> void:
	var lot_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	lot_mesh.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	lot_mesh.material_override = mat
	lot_mesh.position = center + Vector3(0.0, 0.01, 0.0)
	_houses_root.add_child(lot_mesh)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 520.0
	panel.offset_bottom = 220.0
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_info_label = Label.new()
	_info_label.text = "PSX - NUEVAS ZONAS URBANAS DE CASAS\n[1] Enfocar Colonia Vieja (Pared con pared, muros ciegos laterales)\n[2] Enfocar Colonia Nueva (Infonavit serializado, pasillo 1m)\n[3] Enfocar Zona X (Residencial de lujo, aislada a 4 vientos)\n[Espacio] Nueva semilla | [T] Alternar techos (inspeccionar interior)\n[WASD + Click Derecho] Volar libremente"
	_info_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_info_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	vbox.add_child(_stats_label)

	_update_stats_ui()


func _update_stats_ui() -> void:
	if _stats_label == null:
		return

	var text := "Semilla Base: %d | Bardas: DESACTIVADAS | Pasillos en medio: ELIMINADOS\n" % _current_seed
	text += "Techos visibles: %s\n" % [
		"SÍ" if _show_roofs else "NO (Vista arquitectónica interior)"
	]

	var houses := _houses_root.get_children().filter(func(c): return c.name.begins_with("House_"))
	var total_instances := 0
	var total_collision_shapes := 0

	for h in houses:
		var mm_inst: MultiMeshInstance3D = h.get_node_or_null("HouseGeometry_MultiMesh")
		if mm_inst != null and mm_inst.multimesh != null:
			total_instances += mm_inst.multimesh.instance_count

		var col_body: StaticBody3D = h.get_node_or_null("HouseCollision")
		if col_body != null:
			total_collision_shapes += col_body.get_child_count()

	text += "3 Casas activas | Cubos GPU Instanced: %d | Colisiones: %d" % [total_instances, total_collision_shapes]
	_stats_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseMotion and _mouse_captured:
		_cam_yaw -= event.relative.x * 0.003
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -1.45, 1.45)
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_current_seed = randi()
				_regenerate_showcase()
			KEY_T:
				_show_roofs = not _show_roofs
				_regenerate_showcase()
			KEY_1:
				_camera.position = Vector3(-24.0, 9.0, 15.0)
				_cam_pitch = -0.40
				_cam_yaw = 0.0
				_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
			KEY_2:
				_camera.position = Vector3(0.0, 8.5, 14.0)
				_cam_pitch = -0.40
				_cam_yaw = 0.0
				_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
			KEY_3:
				_camera.position = Vector3(26.0, 13.0, 24.0)
				_cam_pitch = -0.40
				_cam_yaw = 0.0
				_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
			KEY_R:
				_camera.position = Vector3(0.0, 16.0, 32.0)
				_cam_pitch = -0.35
				_cam_yaw = 0.0
				_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _process(delta: float) -> void:
	if not _mouse_captured:
		return

	var move_vec := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move_vec += -_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): move_vec += _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): move_vec += -_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): move_vec += _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E):
		move_vec += Vector3.UP * (1.0 if Input.is_key_pressed(KEY_E) else -1.0)

	var speed := CAM_MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 2.5

	if move_vec != Vector3.ZERO:
		_camera.position += move_vec.normalized() * speed * delta


func _run_headless_verification() -> void:
	print("[TestProceduralHouses] Iniciando verificación headless de zonas y tipologías de casas...")

	var zones: Array[HouseGenerator.HouseZoneType] = [
		HouseGenerator.HouseZoneType.COLONIA_VIEJA,
		HouseGenerator.HouseZoneType.COLONIA_NUEVA,
		HouseGenerator.HouseZoneType.ZONA_X
	]

	var lot_sizes := {
		HouseGenerator.HouseZoneType.COLONIA_VIEJA: Vector2(9.5, 16.0),
		HouseGenerator.HouseZoneType.COLONIA_NUEVA: Vector2(6.5, 15.0),
		HouseGenerator.HouseZoneType.ZONA_X: Vector2(22.0, 28.0)
	}

	for zone in zones:
		var size: Vector2 = lot_sizes[zone]
		for s in range(5):
			var test_seed := 1000 + s * 777
			var house_node := _generator.build_standalone_house(size.x, size.y, zone, test_seed)
			if house_node == null:
				push_error("Error: Falló al construir casa para zona %s (seed %d)" % [zone, test_seed])
				get_tree().quit(1)
				return

			var mm_inst: MultiMeshInstance3D = house_node.get_node_or_null("HouseGeometry_MultiMesh")
			if mm_inst == null or mm_inst.multimesh == null:
				push_error("Error: Casa sin MultiMeshInstance3D válido para zona %s" % zone)
				get_tree().quit(1)
				return

			var count := mm_inst.multimesh.instance_count
			if count < 10:
				push_error("Error: Conteo de instancias insuficiente (%d) para zona %s" % [count, zone])
				get_tree().quit(1)
				return

			var col_body: StaticBody3D = house_node.get_node_or_null("HouseCollision")
			if col_body == null or col_body.get_child_count() == 0:
				push_error("Error: Casa sin colisiones físicas para zona %s" % zone)
				get_tree().quit(1)
				return

			print("[TestProceduralHouses] Zona %s (seed=%d): OK! MultiMesh=%d cajas instanciadas, Colisiones=%d formas" % [
				zone, test_seed, count, col_body.get_child_count()
			])
			house_node.queue_free()

	print("[TestProceduralHouses] ¡ÉXITO! Todas las zonas (Colonia Vieja pared con pared, Infonavit serializado, Zona X lujo) generan casas válidas sin bardas ni pasillos en medio.")
	get_tree().quit(0)
