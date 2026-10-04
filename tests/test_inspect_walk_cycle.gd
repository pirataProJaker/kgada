extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

var _frames := 0
var _root: Node3D
var _cam: Camera3D
var _anim_player: AnimationPlayer
var _model: Node3D

func _init() -> void:
	print("=== INSPECCIONANDO CICLO DE CAMINATA BIOMECÁNICO ===")
	_root = Node3D.new()
	root.add_child(_root)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.85)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	_root.add_child(sun)

	var floor_inst := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(10.0, 0.1, 10.0)
	floor_inst.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.30, 0.33)
	floor_inst.material_override = floor_mat
	floor_inst.position.y = -0.05
	_root.add_child(floor_inst)

	var scn: PackedScene = load("res://assets/characters/psx_humanoid.glb")
	_model = scn.instantiate() as Node3D
	_root.add_child(_model)

	var tex: Texture2D = load("res://assets/characters/NonOverlapping.png")
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for child in _model.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		if mi.name.contains("Overlapping") and not mi.name.contains("NotOverlapping"):
			mi.visible = false
		else:
			mi.material_override = mat

	_anim_player = _model.find_child("AnimationPlayer") as AnimationPlayer
	_anim_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_MANUAL
	_anim_player.play("walk")

	# Cámara
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.current = true
	_cam.position = Vector3(-2.8, 1.05, 2.2)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.85, 0.0))
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()
	var total_dur := _anim_player.get_animation("walk").length

	# 1. Contacto / Heel Strike en perspectiva 3/4 (Frame 1 -> t = 0.0s)
	if _frames == 2:
		_cam.position = Vector3(-2.8, 1.05, 2.2)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.85, 0.0))
		_anim_player.seek(0.0, true)
	elif _frames == 5:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/walk_persp_contact.png")
				print("✓ Captura 1: Contacto (Heel Strike) perspectiva 3/4")

	# 1b. Contacto de perfil
	elif _frames == 6:
		_cam.position = Vector3(-2.8, 0.9, 0.0)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.85, 0.0))
	elif _frames == 9:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/walk_profile_contact.png")
				print("✓ Captura 1b: Contacto (Heel Strike) de perfil")

	# 2. Amortiguación de rodilla (Frame 5 -> t = 4/32 * total_dur)
	elif _frames == 10:
		_anim_player.seek(total_dur * (4.0 / 32.0), true)
	elif _frames == 13:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/walk_profile_absorption.png")
				print("✓ Captura 2: Amortiguación de rodilla de perfil")

	# 3. Paso / Passing con flexión de rodilla (Frame 9 -> t = 8/32 * total_dur)
	elif _frames == 14:
		_cam.position = Vector3(-2.8, 1.05, 2.2)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.85, 0.0))
		_anim_player.seek(total_dur * (8.0 / 32.0), true)
	elif _frames == 17:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/walk_persp_passing.png")
				print("✓ Captura 3: Paso / Passing rodilla flexionada 3/4")

	# 4. Contacto opuesto (Frame 17 -> t = 16/32 * total_dur)
	elif _frames == 18:
		_anim_player.seek(total_dur * (16.0 / 32.0), true)
	elif _frames == 21:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/walk_persp_contact_mirror.png")
				print("✓ Captura 4: Contacto opuesto (Heel Strike Derecho) 3/4")

	elif _frames >= 24:
		print(">>> CAPTURAS COMPLETADAS <<<")
		quit(0)

	return false

	return false
