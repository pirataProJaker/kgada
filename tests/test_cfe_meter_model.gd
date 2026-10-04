extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

var _scene_root: Node3D = null
var _camera: Camera3D = null
var _frames: int = 0
var _shots: Array[Dictionary] = []
var _shot_idx: int = 0

func _init() -> void:
	print("=== PROBANDO MODELO LOW-POLY DE MEDIDORES CFE Y PILAR DE SERVICIO ===")
	_setup_scene()
	_create_test_props()

func _setup_scene() -> void:
	_scene_root = Node3D.new()
	root.add_child(_scene_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.50, 0.65, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.92)
	env.ambient_light_energy = 1.05

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_scene_root.add_child(world_env)

	# Sol
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 45.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_scene_root.add_child(sun)

	# Luz de relleno suave para el lado de los switches (atrás)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -135.0, 0.0)
	fill.light_color = Color(0.85, 0.90, 1.0)
	fill.light_energy = 0.5
	_scene_root.add_child(fill)

	# Banqueta / Suelo de prueba
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	ground.mesh = plane
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.55, 0.55, 0.53) # Concreto de banqueta
	g_mat.roughness = 0.90
	ground.material_override = g_mat
	_scene_root.add_child(ground)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 45.0
	_scene_root.add_child(_camera)

func _create_test_props() -> void:
	# 1. Instanciar Pilar de Medidores Compartido (2 casas: 1 medidor arriba, 1 abajo, switches atrás)
	var ElectricServicePillarScript = load("res://world/electricity/electric_service_pillar.gd")
	if ElectricServicePillarScript:
		var pillar: Node3D = ElectricServicePillarScript.new()
		pillar.name = "PilarCompartido"
		pillar.pillar_mode = 0 # SHARED_DUAL
		pillar.house_id_top = "Casa_Infonavit_Lote1"
		pillar.house_id_bottom = "Casa_Infonavit_Lote2"
		pillar.position = Vector3(-1.0, 0.0, 0.0)
		_scene_root.add_child(pillar)

	# 2. Instanciar Medidor Incrustado en Pared (Colonia Vieja / Fachada en banqueta)
	var wall := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(2.5, 3.0, 0.25)
	wall.mesh = wall_box
	var w_mat := StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.82, 0.72, 0.58) # Cremita rústico
	w_mat.roughness = 0.92
	wall.material_override = w_mat
	wall.position = Vector3(2.0, 1.5, -0.125)
	_scene_root.add_child(wall)

	var ElectricMeterScript = load("res://world/electricity/electric_meter.gd")
	if ElectricMeterScript:
		var embedded_meter: Node3D = ElectricMeterScript.new()
		embedded_meter.name = "MedidorIncrustado"
		embedded_meter.installation_type = 2 # WALL_EMBEDDED
		embedded_meter.assigned_house_id = "Casa_ColoniaVieja_1"
		embedded_meter.position = Vector3(2.0, 1.55, 0.005) # En la cara frontal de la pared
		_scene_root.add_child(embedded_meter)

	# Tomas de cámara
	# Toma 1: Frente del pilar compartido (2 medidores redondos CFE: arriba y abajo)
	_shots.append({
		"name": "test_pillar_front_meters.png",
		"cam_pos": Vector3(-1.0, 1.35, 1.8),
		"look_at": Vector3(-1.0, 1.30, 0.0)
	})

	# Toma 2: Atrás del pilar compartido (Cajas de switches e interruptores)
	_shots.append({
		"name": "test_pillar_back_switches.png",
		"cam_pos": Vector3(-1.0, 1.35, -1.8),
		"look_at": Vector3(-1.0, 1.30, 0.0)
	})

	# Toma 3: Acercamiento directo al medidor digital CFE (vidrio, LCD, logos)
	_shots.append({
		"name": "test_meter_closeup.png",
		"cam_pos": Vector3(-1.0, 1.50, 0.65),
		"look_at": Vector3(-1.0, 1.50, 0.18)
	})

	# Toma 4: Medidor incrustado en pared de fachada
	_shots.append({
		"name": "test_wall_embedded_meter.png",
		"cam_pos": Vector3(2.0, 1.55, 1.2),
		"look_at": Vector3(2.0, 1.55, 0.0)
	})

	# Toma 5: Vista de conjunto con mufa y acometida alta
	_shots.append({
		"name": "test_electrical_infrastructure_overview.png",
		"cam_pos": Vector3(0.5, 2.5, 4.5),
		"look_at": Vector3(0.5, 1.8, 0.0)
	})

func _process(_delta: float) -> bool:
	_frames += 1
	if _shots.is_empty():
		if _frames > 20: quit(0)
		return false

	var shot: Dictionary = _shots[_shot_idx]
	_camera.position = shot["cam_pos"]
	_camera.look_at(shot["look_at"])

	if _frames % 15 == 0:
		var vp := root.get_viewport()
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				var path: String = ARTIFACT_DIR + "/" + str(shot["name"])
				img.save_png(path)
				print("✓ Captura guardada: ", str(shot["name"]))
		_shot_idx += 1
		if _shot_idx >= _shots.size():
			print("✓ Pruebas de medidores completadas con éxito.")
			quit(0)

	return false
