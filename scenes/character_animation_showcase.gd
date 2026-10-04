@tool
extends Node3D

const GLB_PATH := "res://assets/characters/psx_humanoid.glb"
const TEX_PATH := "res://assets/characters/NonOverlapping.png"

const ANIMATIONS := [
	{"name": "idle", "label": "1. IDLE", "desc": "Postura natural bípeda con respiración sutil y hombros relajados."},
	{"name": "walk", "label": "2. WALK", "desc": "Caminata humana fluida con balanceo de brazos y hombros rectificados."},
	{"name": "run", "label": "3. RUN", "desc": "Sprint atlético con torso inclinado y zancada enérgica."},
	{"name": "zombie_walk", "label": "4. ZOMBIE WALK", "desc": "Caminata renqueante PSX con brazos estirados al frente."},
	{"name": "zombie_attack", "label": "5. ATTACK", "desc": "Preparación y zarpazo violento con embestida frontal."},
	{"name": "die", "label": "6. DIE", "desc": "Impacto y caída de espaldas hasta quedar plano en el suelo."}
]

const SPACING := 1.9

var _characters: Array[Node3D] = []
var _anim_players: Array[AnimationPlayer] = []
var _one_shot_timers: Array[float] = []

var _camera: Camera3D

var _target_focus_x: float = 0.0
var _current_focus_x: float = 0.0
var _target_dist: float = 9.8
var _current_dist: float = 9.8
var _target_pitch: float = deg_to_rad(14.0)
var _current_pitch: float = deg_to_rad(14.0)
var _target_yaw: float = 0.0
var _current_yaw: float = 0.0

var _is_orbiting: bool = false
var _auto_rotate: bool = false
var _current_selected_idx: int = -1

var _info_label: Label
var _status_label: Label
var _btn_auto_rotate: Button


func _ready() -> void:
	_clear_stage()
	_setup_environment()
	_setup_stage()
	_setup_characters()
	
	if not Engine.is_editor_hint():
		_setup_camera()
		_setup_ui()
		_focus_character(1)


func _clear_stage() -> void:
	for child in get_children():
		if child.has_meta("showcase_managed"):
			child.queue_free()
	_characters.clear()
	_anim_players.clear()
	_one_shot_timers.clear()


func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	env_node.set_meta("showcase_managed", true)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.85)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.set_meta("showcase_managed", true)
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)


func _setup_stage() -> void:
	var floor_inst := MeshInstance3D.new()
	floor_inst.set_meta("showcase_managed", true)
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(25.0, 0.2, 14.0)
	floor_inst.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.24, 0.26, 0.30)
	floor_mat.roughness = 0.85
	floor_inst.material_override = floor_mat
	floor_inst.position.y = -0.1
	add_child(floor_inst)

	var total_count := ANIMATIONS.size()
	var start_x := -((total_count - 1) * SPACING) * 0.5

	for i in range(total_count):
		var pos_x := start_x + (i * SPACING)
		var podium := MeshInstance3D.new()
		podium.set_meta("showcase_managed", true)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.65
		cyl.bottom_radius = 0.70
		cyl.height = 0.06
		podium.mesh = cyl
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.36, 0.40, 0.45)
		pmat.roughness = 0.7
		podium.material_override = pmat
		podium.position = Vector3(pos_x, 0.03, 0.0)
		add_child(podium)


func _setup_characters() -> void:
	var scn: PackedScene = load(GLB_PATH) as PackedScene
	if scn == null:
		printerr("Error cargando GLB desde ", GLB_PATH)
		return

	var tex: Texture2D = load(TEX_PATH) as Texture2D
	var psx_mat := StandardMaterial3D.new()
	if tex:
		psx_mat.albedo_texture = tex
		psx_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		psx_mat.roughness = 0.8
		psx_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var total_count := ANIMATIONS.size()
	var start_x := -((total_count - 1) * SPACING) * 0.5

	for i in range(total_count):
		var anim_info: Dictionary = ANIMATIONS[i]
		var anim_name: String = str(anim_info["name"])
		var pos_x := start_x + (i * SPACING)

		var char_inst := scn.instantiate() as Node3D
		char_inst.set_meta("showcase_managed", true)
		char_inst.position = Vector3(pos_x, 0.06, 0.0)
		add_child(char_inst)
		_characters.append(char_inst)

		for child in char_inst.find_children("*", "MeshInstance3D"):
			var mi := child as MeshInstance3D
			if mi.name.contains("Overlapping") and not mi.name.contains("NotOverlapping"):
				mi.visible = false
			else:
				mi.material_override = psx_mat

		var label3d := Label3D.new()
		label3d.text = str(anim_info["label"])
		label3d.font_size = 28
		label3d.outline_size = 8
		label3d.outline_modulate = Color.BLACK
		label3d.modulate = Color(1.0, 0.92, 0.45)
		label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label3d.position = Vector3(0.0, 2.15, 0.0)
		char_inst.add_child(label3d)

		var aps := char_inst.find_children("*", "AnimationPlayer")
		if not aps.is_empty():
			var ap := aps[0] as AnimationPlayer
			_anim_players.append(ap)
			_one_shot_timers.append(0.0)
			if ap.has_animation(anim_name):
				var anim := ap.get_animation(anim_name)
				var is_loop := not (anim_name in ["die", "zombie_attack"])
				if is_loop:
					anim.loop_mode = Animation.LOOP_LINEAR
				else:
					anim.loop_mode = Animation.LOOP_NONE
				ap.play(anim_name)
		else:
			_anim_players.append(null)
			_one_shot_timers.append(0.0)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.set_meta("showcase_managed", true)
	_camera.fov = 38.0
	_camera.current = true
	add_child(_camera)
	_update_cam_transform()


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.set_meta("showcase_managed", true)
	add_child(canvas)

	var top_panel := PanelContainer.new()
	top_panel.anchor_right = 1.0
	top_panel.offset_bottom = 50.0
	canvas.add_child(top_panel)

	var top_box := HBoxContainer.new()
	top_panel.add_child(top_box)
	top_box.add_theme_constant_override("separation", 16)

	var title_lbl := Label.new()
	title_lbl.text = " 🎮 VISOR DE ANIMACIONES - BASE HUMANOID PSX (15 HUESOS)"
	title_lbl.add_theme_font_size_override("font_size", 16)
	top_box.add_child(title_lbl)

	var help_lbl := Label.new()
	help_lbl.text = "[1-6] Enfocar  |  [ESPACIO] Ver todos  |  [R] Auto-giro  |  [Arrastra Ratón] Rotar 360°"
	help_lbl.modulate = Color(0.75, 0.85, 1.0)
	help_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_box.add_child(help_lbl)

	var info_panel := PanelContainer.new()
	info_panel.anchor_left = 0.5
	info_panel.anchor_right = 0.5
	info_panel.anchor_top = 1.0
	info_panel.anchor_bottom = 1.0
	info_panel.offset_left = -320.0
	info_panel.offset_top = -125.0
	info_panel.offset_right = 320.0
	info_panel.offset_bottom = -70.0
	canvas.add_child(info_panel)

	var info_box := VBoxContainer.new()
	info_panel.add_child(info_box)

	_status_label = Label.new()
	_status_label.text = "VISTA GENERAL DE TODAS LAS ANIMACIONES"
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.modulate = Color(1.0, 0.85, 0.3)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_box.add_child(_status_label)

	_info_label = Label.new()
	_info_label.text = "6 personajes reproduciendo simultáneamente en tiempo real. 15 huesos por modelo."
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_box.add_child(_info_label)

	var bot_panel := PanelContainer.new()
	bot_panel.anchor_top = 1.0
	bot_panel.anchor_bottom = 1.0
	bot_panel.anchor_right = 1.0
	bot_panel.offset_top = -60.0
	canvas.add_child(bot_panel)

	var bot_box := HBoxContainer.new()
	bot_panel.add_child(bot_box)
	bot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_box.add_theme_constant_override("separation", 8)

	var btn_all := Button.new()
	btn_all.text = "👁️ VER TODOS"
	btn_all.pressed.connect(_focus_overview)
	bot_box.add_child(btn_all)

	for i in range(ANIMATIONS.size()):
		var idx := i
		var btn := Button.new()
		btn.text = str(ANIMATIONS[i]["label"])
		btn.pressed.connect(func(): _focus_character(idx))
		bot_box.add_child(btn)

	_btn_auto_rotate = Button.new()
	_btn_auto_rotate.text = "🔄 Auto-Giro: OFF"
	_btn_auto_rotate.pressed.connect(_toggle_auto_rotate)
	bot_box.add_child(_btn_auto_rotate)


func _focus_overview() -> void:
	_current_selected_idx = -1
	_target_focus_x = 0.0
	_target_dist = 9.8
	_target_pitch = deg_to_rad(14.0)
	_target_yaw = 0.0
	if _status_label:
		_status_label.text = "VISTA GENERAL DE TODAS LAS ANIMACIONES"
	if _info_label:
		_info_label.text = "6 personajes reproduciendo simultáneamente en tiempo real. 15 huesos por modelo."


func _focus_character(idx: int) -> void:
	if idx < 0 or idx >= ANIMATIONS.size():
		return
	_current_selected_idx = idx
	var total_count := ANIMATIONS.size()
	var start_x := -((total_count - 1) * SPACING) * 0.5
	_target_focus_x = start_x + (idx * SPACING)
	_target_dist = 2.6
	_target_pitch = deg_to_rad(8.0)
	_target_yaw = deg_to_rad(35.0)

	var anim_info: Dictionary = ANIMATIONS[idx]
	if _status_label:
		_status_label.text = "ENFOCANDO: " + str(anim_info["label"])
	if _info_label:
		_info_label.text = str(anim_info["desc"])

	if idx < _anim_players.size() and _anim_players[idx] != null:
		var ap := _anim_players[idx]
		var anim_name: String = str(anim_info["name"])
		if ap.has_animation(anim_name):
			ap.seek(0.0)
			ap.play(anim_name)


func _toggle_auto_rotate() -> void:
	_auto_rotate = not _auto_rotate
	if _btn_auto_rotate:
		_btn_auto_rotate.text = "🔄 Auto-Giro: ON" if _auto_rotate else "🔄 Auto-Giro: OFF"


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_0, KEY_SPACE:
				_focus_overview()
			KEY_1:
				_focus_character(0)
			KEY_2:
				_focus_character(1)
			KEY_3:
				_focus_character(2)
			KEY_4:
				_focus_character(3)
			KEY_5:
				_focus_character(4)
			KEY_6:
				_focus_character(5)
			KEY_R:
				_toggle_auto_rotate()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_dist = clampf(_target_dist - 0.4, 1.6, 16.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_dist = clampf(_target_dist + 0.4, 1.6, 16.0)

	elif event is InputEventMouseMotion and _is_orbiting:
		_target_yaw -= event.relative.x * 0.007
		_target_pitch = clampf(_target_pitch + event.relative.y * 0.007, deg_to_rad(-15.0), deg_to_rad(60.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Re-disparar animaciones one-shot (ataque y muerte) tras una breve pausa para observación continua
	for i in range(_anim_players.size()):
		var ap := _anim_players[i]
		if ap == null:
			continue
		var anim_name: String = str(ANIMATIONS[i]["name"])
		if anim_name in ["die", "zombie_attack"]:
			if not ap.is_playing():
				_one_shot_timers[i] += delta
				if _one_shot_timers[i] >= 1.2:
					_one_shot_timers[i] = 0.0
					ap.seek(0.0)
					ap.play(anim_name)

	if _auto_rotate:
		_target_yaw += delta * 0.45

	_current_focus_x = lerpf(_current_focus_x, _target_focus_x, delta * 8.0)
	_current_dist = lerpf(_current_dist, _target_dist, delta * 8.0)
	_current_pitch = lerpf(_current_pitch, _target_pitch, delta * 8.0)
	_current_yaw = lerpf(_current_yaw, _target_yaw, delta * 8.0)

	_update_cam_transform()


func _update_cam_transform() -> void:
	if _camera == null:
		return
	var target_pos := Vector3(_current_focus_x, 0.95, 0.0)
	var cam_offset := Vector3(
		sin(_current_yaw) * cos(_current_pitch) * _current_dist,
		sin(_current_pitch) * _current_dist,
		cos(_current_yaw) * cos(_current_pitch) * _current_dist
	)
	var cam_pos := target_pos + cam_offset
	_camera.look_at_from_position(cam_pos, target_pos)
