extends SceneTree

const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")

var _frames: int = 0
var _cam: Camera3D

func _init() -> void:
	print("--- Inicializando captura de variantes de BedSingleOak ---")
	
	# WorldEnvironment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.15, 0.18, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.62, 0.65)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	root.add_child(env_node)

	# Luz direccional
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 40, 0)
	light.light_color = Color(1.0, 0.98, 0.92)
	light.light_energy = 1.2
	light.shadow_enabled = true
	root.add_child(light)

	# Suelo
	var floor_m := PlaneMesh.new()
	floor_m.size = Vector2(20, 20)
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_m
	var fl_mat := StandardMaterial3D.new()
	fl_mat.albedo_color = Color(0.24, 0.21, 0.18)
	fl_mat.roughness = 0.75
	floor_inst.material_override = fl_mat
	root.add_child(floor_inst)

	# Configuración de 5 camas en exposición usando directamente la clase BedSingleOak:
	# 0: Cama tendida con cobertor del lobo (San Marcos blanket 12), sábana celeste (sheet 2), almohada blanca limpia
	# 1: Cama destendida con cobertor tartán café (blanket 1), sábana a rayas (sheet 8), almohada ladeada
	# 2: Cama sin cobija (STRIPPED), solo sábana de azul marino (sheet 6), con almohada
	# 3: Cama sin sábana (BARE_MATTRESS), colchón vintage rayado, sin cobija, sin almohada
	# 4: Cama con cobertor de leopardo (blanket 14), sábana percudida con 70% de suciedad
	var configs := [
		{ "x": -4.6, "state": BedSingleOakScript.BedState.MADE, "sheet": 2, "blanket": 12, "pillow": true, "dirt": 0.0 },
		{ "x": -2.3, "state": BedSingleOakScript.BedState.UNMADE, "sheet": 8, "blanket": 1, "pillow": true, "dirt": 0.0 },
		{ "x": 0.0, "state": BedSingleOakScript.BedState.STRIPPED, "sheet": 6, "blanket": 0, "pillow": true, "dirt": 0.0 },
		{ "x": 2.3, "state": BedSingleOakScript.BedState.BARE_MATTRESS, "sheet": 0, "blanket": 0, "pillow": false, "dirt": 0.0 },
		{ "x": 4.6, "state": BedSingleOakScript.BedState.MADE, "sheet": 1, "blanket": 14, "pillow": true, "dirt": 0.70 }
	]

	for cfg in configs:
		var bed := BedSingleOakScript.new()
		bed.position = Vector3(cfg["x"], 0.0, 0.0)
		bed.bed_state = cfg["state"]
		bed.sheet_pattern_id = cfg["sheet"]
		bed.blanket_pattern_id = cfg["blanket"]
		bed.has_pillow = cfg["pillow"]
		bed.dirt_pct = cfg["dirt"]
		root.add_child(bed)

	# Cámara panorámica
	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, 3.4, 5.4)
	root.add_child(_cam)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.45, 0.0), Vector3.UP)
	_cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()
	
	if _frames == 5:
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.45, 0.0), Vector3.UP)
	elif _frames == 15:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				var out_dir := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"
				var out_path := "%s/bed_variants_showcase.png" % out_dir
				img.save_png(out_path)
				print("✓ Captura guardada en: ", out_path)
	elif _frames == 20:
		# Acercamiento a la cama con cobertor del lobo (San Marcos) y cama destendida
		_cam.position = Vector3(-3.5, 2.0, 2.8)
		_cam.look_at_from_position(_cam.position, Vector3(-3.5, 0.55, 0.0), Vector3.UP)
	elif _frames == 25:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				var out_dir := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"
				var out_path := "%s/bed_variants_wolf_unmade_closeup.png" % out_dir
				img.save_png(out_path)
				print("✓ Captura closeup guardada en: ", out_path)
	elif _frames == 30:
		# Acercamiento a la cama con sábana bajera azul marino, colchón desnudo y cama sucia de leopardo
		_cam.position = Vector3(2.4, 2.0, 2.8)
		_cam.look_at_from_position(_cam.position, Vector3(2.4, 0.55, 0.0), Vector3.UP)
	elif _frames == 35:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				var out_dir := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"
				var out_path := "%s/bed_variants_bare_dirty_closeup.png" % out_dir
				img.save_png(out_path)
				print("✓ Captura closeup guardada en: ", out_path)
	elif _frames >= 40:
		print("✓ Sesión de capturas completada.")
		quit(0)
	return false
