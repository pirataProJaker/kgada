extends Node3D

## Escena Showcase del Vehículo Modular Retro PSX (Play Sector X).
## Demuestra el Sedán 80s con:
## - Mallas paramétricas y Atlas Inteligente de 256x256 (0 mallas FBX).
## - Chasis unibody sólido (puertas y carrocería unificadas) y capó practicable con bisagra real.
## - Vano motor en 3D con motor modular, batería LTH, radiador de aluminio y varilla de aceite.
## - Desmontaje / swap de motor en tiempo real.
## - Conducción física real VehicleBody3D (conducir con WASD / Espacio).

const Sedan80sScript = preload("res://vehicles/models/sedan_80s/sedan_80s.gd")
const ModularEngineScript = preload("res://vehicles/parts/shared/modular_engine.gd")
const BatteryPartScript = preload("res://vehicles/parts/shared/battery_part.gd")
const WheelPartScript = preload("res://vehicles/parts/shared/wheel_part.gd")
const PlayerScene = preload("res://player/player.tscn")

const BASE_Y := 10.0

var _car: Sedan80s = null
var _player: CharacterBody3D = null
var _hud_label: Label = null
var _status_banner: Label = null
var _interaction_prompt: Label = null
var _banner_timer: float = 0.0

var _car_camera: Camera3D = null
var _is_driving: bool = false

# Variables de la cámara de conducción libre (Orbital 3ra persona y Cabina 1ra persona)
var _cam_yaw_offset: float = 0.0
var _cam_pitch: float = deg_to_rad(-14.0)
var _cam_dist: float = 4.90
var _cam_height: float = 1.45
var _mouse_idle_timer: float = 0.0
var _camera_mode: int = 0 # 0 = 3ra persona orbital libre, 1 = 1ra persona interior cabina
var _head_yaw: float = 0.0
var _head_pitch: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_environment()
	_setup_car()
	_setup_spare_parts_bench()
	_setup_player()
	_setup_ui()


func _unhandled_input(event: InputEvent) -> void:
	# 1. Movimiento del ratón para mirar libremente alrededor del coche mientras conduces
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _is_driving:
			_mouse_idle_timer = 0.0
			var sens := 0.0035
			if _camera_mode == 0:
				# 3ra persona: rotar 360 grados alrededor del vehículo
				_cam_yaw_offset -= event.relative.x * sens
				_cam_pitch = clampf(_cam_pitch - event.relative.y * sens, deg_to_rad(-45.0), deg_to_rad(20.0))
			else:
				# 1ra persona: girar la cabeza del conductor dentro de la cabina
				_head_yaw = clampf(_head_yaw - event.relative.x * sens, deg_to_rad(-85.0), deg_to_rad(85.0))
				_head_pitch = clampf(_head_pitch - event.relative.y * sens, deg_to_rad(-35.0), deg_to_rad(35.0))
			return

	# 2. Clics y rueda de ratón para zoom
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _is_driving and _camera_mode == 0:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cam_dist = clampf(_cam_dist - 0.35, 2.8, 8.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cam_dist = clampf(_cam_dist + 0.35, 2.8, 8.0)

	# 3. Teclado
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_C:
			_toggle_driving()
		elif _is_driving and event.keycode == KEY_V:
			_camera_mode = 1 if _camera_mode == 0 else 0
			_show_banner("Vista de Cámara: %s" % ("Cabina (1ra Persona)" if _camera_mode == 1 else "Orbital (3ra Persona)"), 2.0)
		elif not _is_driving and _player != null:
			if event.keycode == KEY_E:
				_handle_general_interaction(_player.global_position)
			elif event.keycode == KEY_R:
				_handle_oil_check()
			elif event.keycode == KEY_X:
				_handle_engine_swap()


func _process(delta: float) -> void:
	if _is_driving and _car != null and _car_camera != null:
		_update_car_camera(delta)
	_update_ui(delta)




func _setup_environment() -> void:
	# Sol principal PSX iluminando directamente el lateral y morro del auto
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-35.0, -45.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	add_child(sun)

	# Luz de relleno ambiente
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(45.0, 135.0, 0.0)
	fill.light_color = Color(0.70, 0.82, 0.98)
	fill.light_energy = 0.70
	add_child(fill)

	# Pista de pruebas de asfalto (80m x 80m)
	var floor_body := StaticBody3D.new()
	floor_body.name = "AsphaltTrack"
	floor_body.position = Vector3(0.0, BASE_Y, 0.0)

	var floor_mesh := MeshInstance3D.new()
	var box_m := BoxMesh.new()
	box_m.size = Vector3(80.0, 0.4, 80.0)
	floor_mesh.mesh = box_m

	var mat_floor := StandardMaterial3D.new()
	mat_floor.albedo_color = Color(0.24, 0.25, 0.27)
	mat_floor.roughness = 0.90
	floor_mesh.material_override = mat_floor
	floor_body.add_child(floor_mesh)

	var floor_col := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(80.0, 0.4, 80.0)
	floor_col.shape = col_box
	floor_body.add_child(floor_col)
	add_child(floor_body)


func _setup_car() -> void:
	_car = Sedan80sScript.new()
	_car.name = "Sedan80s_Showcase"
	_car.position = Vector3(0.0, BASE_Y + 0.65, 0.0)
	_car.paint_color = Color(0.18, 0.32, 0.62)
	add_child(_car)

	# Cámara de conducción libre (Orbital 3ra persona y Cabina 1ra persona)
	_car_camera = Camera3D.new()
	_car_camera.name = "CarFollowCamera"
	_car_camera.current = false
	add_child(_car_camera)



func _setup_spare_parts_bench() -> void:
	var bench_body := StaticBody3D.new()
	bench_body.name = "WorkshopBench"
	bench_body.position = Vector3(3.8, BASE_Y + 0.45, -1.5)

	var bench_mesh := MeshInstance3D.new()
	var box_m := BoxMesh.new()
	box_m.size = Vector3(2.2, 0.9, 1.2)
	bench_mesh.mesh = box_m
	var mat_bench := StandardMaterial3D.new()
	mat_bench.albedo_color = Color(0.35, 0.25, 0.18)
	bench_mesh.material_override = mat_bench
	bench_body.add_child(bench_mesh)

	var bench_col := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(2.2, 0.9, 1.2)
	bench_col.shape = col_box
	bench_body.add_child(bench_col)
	add_child(bench_body)

	# Motor de repuesto potenciado sobre la mesa
	var spare_eng := ModularEngineScript.new()
	spare_eng.name = "SpareEngine_HighPerf"
	spare_eng.position = Vector3(3.8, BASE_Y + 0.95, -1.5)
	if spare_eng.data:
		spare_eng.data.display_name = "Motor Potenciado 2.0L V6"
		spare_eng.data.horse_power = 150.0
		spare_eng.data.max_rpm = 7200.0
	add_child(spare_eng)

	# Rueda de repuesto apoyada en el suelo
	var spare_wheel := WheelPartScript.new()
	spare_wheel.name = "SpareWheel_Floor"
	spare_wheel.position = Vector3(3.8, BASE_Y + 0.35, 0.0)
	spare_wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	add_child(spare_wheel)


func _setup_player() -> void:
	_player = PlayerScene.instantiate()
	_player.name = "Player"
	_player.position = Vector3(2.8, BASE_Y + 0.5, -2.8)
	_player.rotation_degrees = Vector3(0.0, 140.0, 0.0) # Vista 3/4 frontal-lateral
	add_child(_player)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ShowcaseHUD"

	_hud_label = Label.new()
	_hud_label.name = "InstructionsLabel"
	_hud_label.position = Vector2(24, 24)
	_hud_label.text = "PLAY SECTOR X - SEDÁN 80s (VANO MOTOR PRACTICABLE)\n" + \
		"--------------------------------------------------\n" + \
		"[E] Abrir / Cerrar Capó (Frente al auto para ver el motor)\n" + \
		"[R] Medir Nivel y Calidad de Aceite con la Varilla\n" + \
		"[C] Subirse / Conducir el Auto (WASD / Espacio)\n" + \
		"[X] Desmontar / Swap Motor Completo (Mesa de Taller)\n" + \
		"[ESC] Liberar Cursor del Ratón"
	_hud_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_hud_label)

	_interaction_prompt = Label.new()
	_interaction_prompt.name = "InteractionPrompt"
	_interaction_prompt.position = Vector2(400, 360)
	_interaction_prompt.text = ""
	_interaction_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_interaction_prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_interaction_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_interaction_prompt.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_interaction_prompt)

	_status_banner = Label.new()
	_status_banner.name = "StatusBanner"
	_status_banner.position = Vector2(280, 520)
	_status_banner.text = ""
	_status_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.20))
	_status_banner.add_theme_font_size_override("font_size", 18)
	canvas.add_child(_status_banner)

	add_child(canvas)


func _update_ui(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_status_banner.text = ""

	if _is_driving and _car != null:
		var speed_kmh: float = _car.linear_velocity.length() * 3.6
		var eng: ModularEngine = _car.get_installed_engine()
		var eng_info := "Motor: %s (%.0f HP)" % [eng.data.display_name, eng.data.horse_power] if eng else "SIN MOTOR"
		_hud_label.text = "MODO CONDUCCIÓN:\n" + \
			"Velocidad: %03.0f km/h | %s\n" % [speed_kmh, eng_info] + \
			"[W/S] Acelerar / Reversa | [A/D] Girar | [Espacio] Freno\n" + \
			"[Ratón] Mirar Alrededor Libremente | [Rueda] Zoom | [V] Cambiar Vista (3ra/1ra)\n" + \
			"[C] Bajarse del auto"
		_interaction_prompt.text = ""
	elif not _is_driving and _player != null and _car != null:
		var dist := _player.global_position.distance_to(_car.global_position)
		if dist < 4.5:
			var to_car := _car.to_local(_player.global_position)
			if to_car.z < -0.6:
				_interaction_prompt.text = "[E] Abrir/Cerrar Capó | [R] Medir Varilla Aceite"
			else:
				_interaction_prompt.text = "[C] Entrar a Conducir"
		else:
			_interaction_prompt.text = ""


func _show_banner(text: String, duration: float = 3.5) -> void:
	_status_banner.text = text
	_banner_timer = duration


func _toggle_driving() -> void:
	if _car == null:
		return

	if not _is_driving:
		# Solo permitir subir si está a una distancia razonable
		if _player != null and _player.global_position.distance_to(_car.global_position) > 5.5:
			_show_banner("Acércate más al auto para subirte.", 2.0)
			return

		_is_driving = true
		_car.enter_driver_seat(_player)
		_player.visible = false
		_player.process_mode = Node.PROCESS_MODE_DISABLED

		# Inicializar cámara libre detrás del auto
		_cam_yaw_offset = 0.0
		_cam_pitch = deg_to_rad(-14.0)
		_mouse_idle_timer = 0.0
		_head_yaw = 0.0
		_head_pitch = 0.0

		var car_forward := -_car.global_transform.basis.z
		var car_base_yaw := atan2(car_forward.x, car_forward.z)
		var h_dist := _cam_dist * cos(_cam_pitch)
		var v_dist := _cam_dist * sin(-_cam_pitch)
		var target_pos := _car.global_position + Vector3(0.0, _cam_height, 0.0)
		_car_camera.global_position = target_pos + Vector3(-h_dist * sin(car_base_yaw), v_dist, -h_dist * cos(car_base_yaw))
		_car_camera.look_at(target_pos + Vector3(0.0, 0.25, 0.0), Vector3.UP)
		_car_camera.current = true

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_show_banner("¡Al volante! Mueve el ratón para mirar alrededor | [V] Cambiar vista.", 4.0)
	else:
		_is_driving = false
		_car.exit_driver_seat()
		_player.visible = true
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		_player.global_position = _car.global_position + _car.global_transform.basis * Vector3(1.8, 0.1, 0.0)
		_car_camera.current = false
		if _player.camera:
			_player.camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_show_banner("Te has bajado del vehículo.", 2.5)


func _update_car_camera(delta: float) -> void:
	if _car == null or _car_camera == null:
		return

	if _camera_mode == 0:
		# --- 1. MODO TERCERA PERSONA (ORBITAL LIBRE 360°) ---
		var target_pos := _car.global_position + Vector3(0.0, _cam_height, 0.0)

		# Auto-centrado suave hacia la trasera del coche si va en marcha (> 2.5 m/s) y no se mueve el ratón
		_mouse_idle_timer += delta
		var speed := _car.linear_velocity.length()
		if _mouse_idle_timer > 1.2 and speed > 2.5:
			_cam_yaw_offset = lerp_angle(_cam_yaw_offset, 0.0, delta * 2.8)

		# Orientación base del vehículo (-Z es el frente, por lo que +Z es la trasera)
		var car_forward := -_car.global_transform.basis.z
		var car_base_yaw := atan2(car_forward.x, car_forward.z)
		var total_yaw := car_base_yaw + _cam_yaw_offset

		# Coordenadas esféricas de la cámara respecto al pivote del auto
		var h_dist := _cam_dist * cos(_cam_pitch)
		var v_dist := _cam_dist * sin(-_cam_pitch)

		var cam_offset := Vector3(
			-h_dist * sin(total_yaw),
			v_dist,
			-h_dist * cos(total_yaw)
		)

		var target_cam_pos := target_pos + cam_offset
		# Interpolación suave para amortiguar baches
		if _car_camera.global_position.distance_squared_to(target_cam_pos) < 300.0:
			_car_camera.global_position = _car_camera.global_position.lerp(target_cam_pos, delta * 22.0)
		else:
			_car_camera.global_position = target_cam_pos
		_car_camera.look_at(target_pos + Vector3(0.0, 0.25, 0.0), Vector3.UP)

	else:
		# --- 2. MODO PRIMERA PERSONA (INTERIOR DE CABINA / ASIENTO DEL CONDUCTOR) ---
		var driver_seat_local := Vector3(-0.35, 1.05, -0.15)
		var head_pos := _car.to_global(driver_seat_local)
		_car_camera.global_position = head_pos

		var base_basis := _car.global_transform.basis
		var head_rot := Basis(Vector3.UP, _head_yaw) * Basis(Vector3.RIGHT, _head_pitch)
		_car_camera.global_transform.basis = base_basis * head_rot



func _handle_general_interaction(p_pos: Vector3) -> void:
	if _car == null:
		return

	var to_car := _car.to_local(p_pos)

	# Capó frontal practicable con bisagra real al cowl
	if to_car.z < -0.4 and abs(to_car.x) < 1.6:
		var hood_socket: PartSocket = _car.sockets.get(VehiclePartData.SlotType.HOOD)
		if hood_socket and hood_socket.installed_part:
			hood_socket.installed_part.toggle_open()
			var st: String = "ABIERTO" if hood_socket.installed_part.is_open else "CERRADO"
			_show_banner("Capó frontal %s (Vano motor e inspección mecánica actualizados)." % st)
	else:
		# Si está en los costados o cerca de la cabina, invitar a conducir
		_toggle_driving()


func _handle_oil_check() -> void:
	var eng: ModularEngine = _car.get_installed_engine()
	if eng == null:
		_show_banner("¡No hay motor instalado en el vehículo!", 2.5)
		return

	var res := eng.check_oil()
	_show_banner("VARILLA DE ACEITE: Nivel %.0f%% | %s" % [res["level"] * 100.0, res["status_text"]], 4.0)


func _handle_engine_swap() -> void:
	var eng_socket: PartSocket = _car.sockets.get(VehiclePartData.SlotType.ENGINE_BAY)
	if eng_socket == null:
		return

	var cur_eng := eng_socket.installed_part as ModularEngine
	if cur_eng != null:
		var removed := eng_socket.uninstall() as ModularEngine
		removed.reparent(self)
		removed.global_position = _car.global_position + Vector3(2.5, 0.35, -1.5)
		_show_banner("¡Motor %s extraído del vehículo!" % removed.data.display_name, 4.0)
	else:
		var spare: ModularEngine = get_node_or_null("SpareEngine_HighPerf")
		if spare != null:
			spare.reparent(self)
			eng_socket.install(spare)
			_show_banner("¡SWAP REALIZADO! Motor Potenciado 2.0L V6 instalado en el Sedán.", 4.5)
