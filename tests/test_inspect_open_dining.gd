extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const DiningSetScript = preload("res://world/furniture/dining_set.gd")
const CityTextureManager = preload("res://world/city/city_texture_manager.gd")
const ApplianceRefrigeratorScript = preload("res://world/furniture/appliance_refrigerator.gd")
const ApplianceStoveScript = preload("res://world/furniture/appliance_stove.gd")
const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")
const HouseFurniturePlannerScript = preload("res://world/furniture/house_furniture_planner.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D
var _house_node: Node3D = null
var _engine = null

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	CityTextureManager.ensure_initialized()

	if ClassDB.class_exists("ProceduralHouseEngine"):
		_engine = ClassDB.instantiate("ProceduralHouseEngine")
		print("✓ ProceduralHouseEngine cargado con éxito.")
	else:
		printerr("ERROR: ProceduralHouseEngine no encontrado.")
		quit(1)
		return

	# Iluminación de estudio
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.86, 0.89, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.81, 0.85)
	env.ambient_light_energy = 1.35
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	_root.add_child(sun)

	# Luz de relleno frontal para iluminar el interior a través de los vanos
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, -145.0, 0.0)
	fill.light_color = Color(0.85, 0.88, 0.95)
	fill.light_energy = 0.8
	_root.add_child(fill)

	var ground := MeshInstance3D.new()
	var ground_box := BoxMesh.new()
	ground_box.size = Vector3(50.0, 0.1, 50.0)
	ground.mesh = ground_box
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.85, 0.85, 0.82)
	ground.material_override = gmat
	ground.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(ground)

	_cam = Camera3D.new()
	_cam.current = true
	_root.add_child(_cam)

	# 1. Construir Colonia Vieja de 1 piso (10x16m, seed=2024, sin techos)
	_build_house(10, 16, 0, 2024)

func _build_house(w: int, d: int, zone: int, house_seed: int) -> void:
	if _house_node != null:
		_house_node.queue_free()

	_house_node = Node3D.new()
	_house_node.name = "InspectedHouse"
	_root.add_child(_house_node)

	var res: Dictionary = _engine.generate_house(w, d, zone, house_seed, false)

	var mat_solid := StandardMaterial3D.new()
	mat_solid.vertex_color_use_as_albedo = true
	mat_solid.roughness = 0.88
	mat_solid.cull_mode = BaseMaterial3D.CULL_BACK

	var mat_glass := StandardMaterial3D.new()
	mat_glass.vertex_color_use_as_albedo = true
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.albedo_color = Color(0.25, 0.45, 0.65, 0.65)

	var ext_walls_mm: MultiMesh = res.get("ext_walls_multimesh", null)
	if ext_walls_mm:
		var ext_inst := MultiMeshInstance3D.new()
		ext_inst.multimesh = ext_walls_mm
		ext_inst.material_override = CityTextureManager.get_walls_shared_material()
		ext_inst.set_instance_shader_parameter("wall_layer", 0)
		_house_node.add_child(ext_inst)

	var solid_mm: MultiMesh = res.get("solid_multimesh", null)
	if solid_mm:
		var solid_inst := MultiMeshInstance3D.new()
		solid_inst.multimesh = solid_mm
		solid_inst.material_override = mat_solid
		_house_node.add_child(solid_inst)

	var glass_mm: MultiMesh = res.get("glass_multimesh", null)
	if glass_mm:
		var glass_inst := MultiMeshInstance3D.new()
		glass_inst.multimesh = glass_mm
		glass_inst.material_override = mat_glass
		_house_node.add_child(glass_inst)

	# Amueblar Comedor
	var rooms_data: Array = res.get("rooms", [])
	print("--- Habitaciones Casa (Zona %d, Seed %d) ---" % [zone, house_seed])
	for r_dict in rooms_data:
		print("  Cuarto: ", r_dict.get("name"), " Piso: ", r_dict.get("floor"),
			" X: [", r_dict.get("x_min"), "..", r_dict.get("x_max"),
			"] Z: [", r_dict.get("z_min"), "..", r_dict.get("z_max"), "]")

		if r_dict.get("name", "") == "Comedor" and r_dict.get("floor", 1) == 1:
			var dining_plan: Dictionary = HouseFurniturePlannerScript.plan_dining_set(res, r_dict, float(w), float(d))
			var dining := DiningSetScript.new()
			dining.name = "DiningSet"
			dining.finish = 0 # REFINED_LIGHT
			dining.chairs_count = 4
			dining.position = dining_plan["position"]
			dining.rotation.y = dining_plan["rotation_y"]
			_house_node.add_child(dining)
			print("  -> DiningSet en Comedor pos local: ", dining.position)

		elif r_dict.get("name", "") == "Cocina" and r_dict.get("floor", 1) == 1:
			var kitchen_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_kitchen_furniture(res, r_dict, float(w), float(d))
			for item in kitchen_items:
				var scr = item["script"]
				var node: Node3D = scr.new()
				node.name = item["name"]
				if item.has("cabinet_type") and "cabinet_type" in node:
					node.cabinet_type = item["cabinet_type"]
				node.position = item["position"]
				node.rotation.y = item["rotation_y"]
				_house_node.add_child(node)
				print("  -> Cocina Item: %s en %s rot_y=%.2f" % [node.name, str(node.position), node.rotation.y])

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Colonia Vieja - Vista Aérea Cortada / Floor Plan 3D de Frente
	# Cámara ubicada al frente de la casa (Z negativo) mirando hacia el interior (Z positivo)
	if _frames == 10:
		_cam.position = Vector3(0.0, 7.5, -13.0)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.8, -5.0))

	elif _frames == 14:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_colonia_vieja_open_dining_overview.png")
				print("✓ 1. Colonia Vieja - Vista Aérea Cortada guardada")

	# Frame 17: Colonia Vieja - Vista en ángulo cercano sobre Sala, Comedor y Cocina
	elif _frames == 17:
		_cam.position = Vector3(-1.0, 4.2, -10.5)
		_cam.look_at_from_position(_cam.position, Vector3(0.5, 0.8, -5.5))

	elif _frames == 21:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_colonia_vieja_isometric_interior.png")
				print("✓ 2. Colonia Vieja - Isométrica Interior guardada")

	# Frame 24: Colonia Vieja - Ojo Humano dentro de la Sala mirando al Comedor y Cocina
	elif _frames == 24:
		_cam.position = Vector3(-2.8, 1.35, -6.5)
		_cam.look_at_from_position(_cam.position, Vector3(2.0, 1.0, -5.5))

	elif _frames == 28:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_colonia_vieja_living_to_dining_eye.png")
				print("✓ 3. Colonia Vieja - Ojo Humano Comedor y Cocina guardado")

	# Frame 31: Cambiar a Infonavit de 1 piso (7x15m, seed=1009)
	elif _frames == 31:
		_build_house(7, 15, 1, 1009)

	# Frame 35: Infonavit - Vista Aérea Cortada de Frente
	elif _frames == 35:
		_cam.position = Vector3(0.0, 6.8, -11.5)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.8, -3.5))

	elif _frames == 39:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_infonavit_open_dining_overview.png")
				print("✓ 4. Infonavit - Vista Aérea Cortada guardada")

	# Frame 42: Infonavit - Ojo Humano dentro de la Sala mirando al Comedor y Cocina
	elif _frames == 42:
		_cam.position = Vector3(-0.8, 1.30, -3.0)
		_cam.look_at_from_position(_cam.position, Vector3(2.0, 0.95, -2.5))

	elif _frames == 46:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_infonavit_living_to_dining_eye.png")
				print("✓ 5. Infonavit - Ojo Humano Comedor y Cocina guardado")

	elif _frames >= 50:
		quit(0)

	return false
