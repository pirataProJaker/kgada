class_name MilitaryBaseShowcase
extends Node3D

## Escenario de Demostración y Prueba de la Base Militar Procedural (Play Sector X).
## Integra el motor nativo de Rust (`FacilityEngine`) con texturas militares,
## calcomanías y recetas del ObjectEngine.
##
## Controles:
## • R: Regenerar la base con una nueva semilla aleatoria instantáneamente.
## • WASD: Moverse | Shift: Correr rápido | Espacio/Ctrl: Subir/Bajar.
## • Ratón: Mirar libremente (Click para capturar, ESC para liberar).
## • [0]: Vista Aérea Panorámica | [1]: Portón de Acceso | [2]: Hangares | [3]: Barracones | [4]: Búnker.

const FacilityCompoundControllerScript = preload("res://world/facility/facility_compound_controller.gd")

const MOVE_SPEED := 18.0
const SPRINT_SPEED := 45.0
const MOUSE_SENSITIVITY := 0.0025
const PITCH_LIMIT := 1.45

var _compound: FacilityCompoundController = null
var _camera: Camera3D = null
var _mouse_captured: bool = true
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _hud_label: Label = null
var _seed_label: Label = null
var _current_seed: int = 54321


func _ready() -> void:
	print("=======================================================================")
	print("=== ESCAPARATE DE BASE MILITAR PROCEDURAL (FACILITY ENGINE - RUST) ===")
	print("=======================================================================")

	_setup_lighting_and_environment()
	_setup_compound()
	_setup_camera()
	_create_hud()


func _setup_lighting_and_environment() -> void:
	# Sol militar táctico con sombras nítidas
	var light := DirectionalLight3D.new()
	light.name = "MilitarySun"
	light.rotation_degrees = Vector3(-42.0, 48.0, 0.0)
	light.light_energy = 1.65
	light.light_color = Color(1.0, 0.96, 0.90)
	light.shadow_enabled = true
	add_child(light)

	# Entorno con cielo procedimental militar y horizonte despejado
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.38, 0.46)
	sky_mat.sky_horizon_color = Color(0.58, 0.60, 0.62)
	sky_mat.ground_bottom_color = Color(0.18, 0.18, 0.18)
	sky_mat.ground_horizon_color = Color(0.48, 0.50, 0.52)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 1.10
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.55, 0.58)
	env.fog_density = 0.0006 # Niebla atmosférica suave en el horizonte
	env_node.environment = env
	add_child(env_node)


func _setup_compound() -> void:
	_compound = FacilityCompoundControllerScript.new()
	_compound.name = "MilitaryCompound"
	_compound.width_m = 80.0
	_compound.depth_m = 96.0
	_compound.facility_type = 0 # 0 = Base Militar
	_compound.rng_seed = _current_seed
	add_child(_compound)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.fov = 68.0
	_camera.current = true
	add_child(_camera)

	# Ubicación inicial: Frente al portón de acceso
	_teleport_to_preset(1)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ShowcaseHUD"
	add_child(canvas)

	# Panel Superior Derecho (Controles)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -380
	panel.offset_top = 16
	panel.offset_right = -16

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.09, 0.88)
	style.border_color = Color(0.35, 0.42, 0.32) # Borde verde militar
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	_seed_label = Label.new()
	_seed_label.text = "🎖️ BASE MILITAR PROCEDURAL (RUST)\nSemilla actual: %d" % _current_seed
	_seed_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	_seed_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_seed_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_hud_label = Label.new()
	_hud_label.text = "• [R]: REGENERAR CON NUEVA SEMILLA\n" + \
		"• WASD: Moverse | Shift: Correr rápido\n" + \
		"• Espacio: Subir | Ctrl: Bajar\n" + \
		"• Ratón: Mirar libremente | ESC: Cursor\n" + \
		"• Puntos de Vista Rápidos:\n" + \
		"  [1] Portón Principal & Garita\n" + \
		"  [2] Hangares & Helipuerto Táctico\n" + \
		"  [3] Bloque de Barracones de Tropa\n" + \
		"  [4] Cuartel General & Acceso a Búnker\n" + \
		"  [0] Vista Aérea Panorámica (Cenital)"
	_hud_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.88))
	_hud_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_hud_label)

	canvas.add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	# Tecla R: Regenerar con nueva semilla
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_regenerate_base()
		return

	# Teclas numéricas para teletransporte de cámara
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_0: _teleport_to_preset(0)
			KEY_1: _teleport_to_preset(1)
			KEY_2: _teleport_to_preset(2)
			KEY_3: _teleport_to_preset(3)
			KEY_4: _teleport_to_preset(4)

	# Liberar / capturar cursor
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and not _mouse_captured:
		_mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# Control de cámara con mouse
	if _mouse_captured and event is InputEventMouseMotion:
		_cam_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		_update_cam_rotation()


func _regenerate_base() -> void:
	_current_seed = int(randi() % 1000000 + 1)
	if _compound != null:
		_compound.generate_compound(_current_seed)
	if _seed_label != null:
		_seed_label.text = "🎖️ BASE MILITAR PROCEDURAL (RUST)\nSemilla actual: %d" % _current_seed
	print("[MilitaryBaseShowcase] Base regenerada con semilla: %d" % _current_seed)


func _teleport_to_preset(index: int) -> void:
	if _camera == null:
		return

	var half_w := _compound.width_m * 0.5 if _compound != null else 100.0
	var half_d := _compound.depth_m * 0.5 if _compound != null else 130.0

	var cam_pos := Vector3.ZERO
	var target_pos := Vector3.ZERO

	match index:
		0: # Vista Aérea Panorámica (Isométrica 3D amplia de todo el complejo)
			cam_pos = Vector3(-45.0, 52.0, -52.0)
			target_pos = Vector3(6.0, 2.0, 4.0)
		1: # Portón Principal, Garita, Pluma y Franjas de advertencia
			var gate_pos := _compound.checkpoint_gate_position if _compound != null else Vector3(0.0, 0.0, -half_d)
			cam_pos = gate_pos + Vector3(0.0, 2.0, -9.0)
			target_pos = gate_pos + Vector3(0.8, 1.4, 6.0)
		2: # Hangares y Helipuerto Táctico (Mirando hacia el sector oeste desde el bulevar)
			cam_pos = Vector3(-4.0, 8.0, -35.0)
			target_pos = Vector3(-22.0, 4.0, -16.0)
		3: # Sector de Cuarteles y Barracones de tropa (Mirando hacia los bloques de cuarteles)
			cam_pos = Vector3(-2.0, 6.0, -30.0)
			target_pos = Vector3(18.0, 3.0, -15.0)
		4: # Cuartel General & Acceso a Búnker
			var b_pos := _compound.bunker_entrance_position if _compound != null else Vector3(0.0, 0.0, half_d * 0.7)
			cam_pos = b_pos + Vector3(3.2, 2.2, -4.5)
			target_pos = b_pos + Vector3(0.0, 0.4, 0.0)

	_camera.look_at_from_position(cam_pos, target_pos, Vector3.UP)
	_cam_yaw = _camera.rotation.y
	_cam_pitch = _camera.rotation.x


func _process(delta: float) -> void:
	if not _mouse_captured or _camera == null:
		return

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else MOVE_SPEED
	var input_vec := Vector3.ZERO

	if Input.is_key_pressed(KEY_W): input_vec.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_vec.z += 1.0
	if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E): input_vec.y += 1.0
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q): input_vec.y -= 1.0

	if input_vec.length_squared() > 0.001:
		input_vec = input_vec.normalized()
		var forward := -_camera.global_transform.basis.z
		var right := _camera.global_transform.basis.x
		var up := Vector3.UP

		var move_dir := (forward * -input_vec.z + right * input_vec.x + up * input_vec.y).normalized()
		_camera.position += move_dir * speed * delta


func _update_cam_rotation() -> void:
	if _camera == null:
		return
	var b := Basis(Vector3.UP, _cam_yaw)
	b = b.rotated(b.x, _cam_pitch)
	_camera.basis = b
