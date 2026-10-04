extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const HouseFurniturePlannerScript = preload("res://world/furniture/house_furniture_planner.gd")
const CityTextureManager = preload("res://world/city/city_texture_manager.gd")
const ElectricMeterScript = preload("res://world/electricity/electric_meter.gd")
const DiningSetScript = preload("res://world/furniture/dining_set.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D
var _house_node: Node3D
var _engine = null

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	CityTextureManager.ensure_initialized()

	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ERROR: ProceduralHouseEngine no existe.")
		quit(1)
		return

	_engine = ClassDB.instantiate("ProceduralHouseEngine")

	# Generar la casa de Colonia Vieja (10x16m, seed 1009) que antes tenía el medidor en la ventana
	var w := 10
	var d := 16
	var zone := 0
	var house_seed := 1009
	var res: Dictionary = _engine.generate_house(w, d, zone, house_seed, false)

	# Iluminación de estudio
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.80, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.72, 0.76)
	env.ambient_light_energy = 1.15
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	_root.add_child(sun)

	# Casa
	_house_node = Node3D.new()
	_house_node.name = "House_ColoniaVieja"
	_house_node.position = Vector3(-12.0, 0.16, -15.0)
	_house_node.rotation.y = PI
	_root.add_child(_house_node)

	var mat_solid := StandardMaterial3D.new()
	mat_solid.vertex_color_use_as_albedo = true
	mat_solid.roughness = 0.88

	var mat_glass := StandardMaterial3D.new()
	mat_glass.vertex_color_use_as_albedo = true
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.albedo_color = Color(0.25, 0.45, 0.65, 0.65)

	var ext_walls_mm: MultiMesh = res.get("ext_walls_multimesh", null)
	if ext_walls_mm:
		var ext_inst := MultiMeshInstance3D.new()
		ext_inst.multimesh = ext_walls_mm
		ext_inst.material_override = CityTextureManager.get_walls_shared_material()
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

	# 1. PLANIFICAR MEDIDOR CFE CON LAS NUEVAS REGLAS ARQUITECTÓNICAS
	var meter_plan: Dictionary = HouseFurniturePlannerScript.find_safe_facade_meter_position(res, _house_node.transform, float(w), float(d))
	print("Plan Medidor CFE: ", meter_plan)

	var meter := ElectricMeterScript.new()
	meter.name = "SafeMeter_CFE"
	meter.installation_type = ElectricMeterScript.InstallationType.WALL_EMBEDDED
	meter.position = meter_plan.meter_world_pos
	meter.rotation.y = meter_plan.rotation_y
	_root.add_child(meter)

	meter.build_switch_box(_root, meter_plan.switch_world_pos, meter_plan.rotation_y)

	# 2. PLANIFICAR COMEDOR Y COCINA
	for r in res.get("rooms", []):
		if r.name == "Comedor" and r.floor == 1:
			var dining_plan: Dictionary = HouseFurniturePlannerScript.plan_dining_set(res, r, float(w), float(d))
			print("Plan Comedor: ", dining_plan)
			var dining := DiningSetScript.new()
			dining.name = "SafeDiningSet"
			dining.position = dining_plan.position
			dining.rotation.y = dining_plan.rotation_y
			dining.finish = 0
			dining.chairs_count = 4
			_house_node.add_child(dining)

		elif r.name == "Cocina" and r.floor == 1:
			var kitchen_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_kitchen_furniture(res, r, float(w), float(d))
			print("Plan Cocina items generados: ", kitchen_items.size())
			for item in kitchen_items:
				var script_ref = item["script"]
				var inst: Node3D = script_ref.new()
				inst.name = item["name"]
				inst.position = item["position"]
				inst.rotation.y = item["rotation_y"]
				if item.has("cabinet_type"):
					inst.set("cabinet_type", item["cabinet_type"])
				_house_node.add_child(inst)
				print("  -> Mueble instalado: %s en pos local %s (rot Y: %.2f)" % [inst.name, inst.position, inst.rotation.y])

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_root.add_child(_cam)
	_cam.position = Vector3(-12.0, 1.60, -4.8)
	_cam.look_at_from_position(_cam.position, Vector3(-12.0, 1.55, -7.0), Vector3.UP)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# Frame 6: Acercamiento a la fachada exterior donde está el Medidor CFE y Switch (demostrando que NO toca ventanas)
	if _frames == 6:
		_cam.position = Vector3(-12.0, 1.60, -4.8)
		_cam.look_at_from_position(_cam.position, Vector3(-12.0, 1.55, -7.0), Vector3.UP)

	elif _frames == 10:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_safe_meter_facade.png")
				print("✓ 1. Captura Medidor en Fachada Sólida guardada")

		# Frame 11: Vista interior hacia la cocina equipada (mostrando muebles adosados a la pared este sin penetración)
		# En coordenadas mundiales, la pared este está en X = -17.0, mirando hacia +X
		_cam.position = Vector3(-14.2, 1.35, -11.5)
		_cam.look_at_from_position(_cam.position, Vector3(-16.8, 1.10, -11.5), Vector3.UP)

	elif _frames == 16:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_safe_kitchen_placement.png")
				print("✓ 2. Captura Cocina sin penetración en muros guardada")

		# Frame 17: Vista desde el comedor hacia la cocina, mostrando que el vano abierto y las puertas están 100% libres
		_cam.position = Vector3(-15.0, 1.40, -8.0)
		_cam.look_at_from_position(_cam.position, Vector3(-15.0, 1.10, -12.0), Vector3.UP)

	elif _frames == 22:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_safe_doors_free_transit.png")
				print("✓ 3. Captura Tránsito Libre de Puertas y Pasos guardada")

	elif _frames >= 26:
		quit(0)
		return true

	return false
