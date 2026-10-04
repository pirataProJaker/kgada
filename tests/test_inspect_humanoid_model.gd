extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

var _frames := 0
var _root: Node3D
var _cam: Camera3D
var _anim_player: AnimationPlayer
var _model_inst: Node3D

func _init() -> void:
	print("=== INICIANDO VISUALIZADOR DE ANIMACIONES PSX HUMANOID ===")
	_root = Node3D.new()
	root.add_child(_root)

	# Entorno de iluminación
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
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_root.add_child(sun)

	# Piso cuadriculado estilo PSX
	var floor_inst := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(10.0, 0.1, 10.0)
	floor_inst.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.30, 0.33)
	floor_mat.roughness = 0.85
	floor_inst.material_override = floor_mat
	floor_inst.position.y = -0.05
	_root.add_child(floor_inst)

	# Cargar modelo GLB
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("res://assets/characters/psx_humanoid.glb", state)
	if err != OK:
		printerr("ERROR: No se pudo cargar psx_humanoid.glb")
		quit(1)
		return

	_model_inst = doc.generate_scene(state) as Node3D
	_root.add_child(_model_inst)

	# Cargar textura NonOverlapping.png
	var tex: Texture2D = load("res://assets/characters/NonOverlapping.png")
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.75
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for child in _model_inst.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		if mi.name.contains("Overlapping") and not mi.name.contains("NotOverlapping"):
			mi.visible = false
		else:
			mi.material_override = mat

	# Inspeccionar AnimationPlayer
	var anim_players := _model_inst.find_children("*", "AnimationPlayer")
	if not anim_players.is_empty():
		_anim_player = anim_players[0] as AnimationPlayer
		var anim_list := _anim_player.get_animation_list()
		print("✓ AnimationPlayer listo con %d animaciones: %s" % [anim_list.size(), str(anim_list)])
		_anim_player.play("idle")
		_anim_player.seek(0.5, true)

	# Cámara en perspectiva 3/4
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 36.0
	_cam.position = Vector3(1.1, 1.15, 2.7)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.95, 0.0))
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# 1. Idle (Frame 10)
	if _frames == 10:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/psx_humanoid_idle.png")
				print("✓ Captura 1 guardada: psx_humanoid_idle.png")

	# 2. Walk (Frame 15)
	elif _frames == 15:
		if _anim_player and _anim_player.has_animation("walk"):
			_anim_player.play("walk")
			_anim_player.seek(0.4, true)

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/psx_humanoid_walk.png")
				print("✓ Captura 2 guardada: psx_humanoid_walk.png")

	# 3. Run (Frame 30)
	elif _frames == 30:
		if _anim_player and _anim_player.has_animation("run"):
			_anim_player.play("run")
			_anim_player.seek(0.2, true)

	elif _frames == 40:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/psx_humanoid_run.png")
				print("✓ Captura 3 guardada: psx_humanoid_run.png")

	# 4. Zombie Walk (Frame 45)
	elif _frames == 45:
		if _anim_player and _anim_player.has_animation("zombie_walk"):
			_anim_player.play("zombie_walk")
			_anim_player.seek(0.6, true)

	elif _frames == 55:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/psx_humanoid_zombie_walk.png")
				print("✓ Captura 4 guardada: psx_humanoid_zombie_walk.png")

	# 5. Zombie Attack (Frame 60)
	elif _frames == 60:
		if _anim_player and _anim_player.has_animation("zombie_attack"):
			_anim_player.play("zombie_attack")
			_anim_player.seek(0.55, true)

	elif _frames == 70:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/psx_humanoid_attack.png")
				print("✓ Captura 5 guardada: psx_humanoid_attack.png")

	# 6. Die (Frame 75)
	elif _frames == 75:
		if _cam:
			_cam.position = Vector3(1.6, 1.5, 2.0)
			_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.2, 0.0))
		if _anim_player and _anim_player.has_animation("die"):
			_anim_player.play("die")
			_anim_player.seek(1.2, true)

	elif _frames == 85:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/psx_humanoid_die.png")
				print("✓ Captura 6 guardada: psx_humanoid_die.png")

	elif _frames >= 90:
		print(">>> ¡TODAS LAS CAPTURAS COMPLETADAS EXITOSAMENTE! <<<")
		quit(0)

	return false
