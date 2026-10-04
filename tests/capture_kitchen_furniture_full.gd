extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const ApplianceRefrigeratorScript = preload("res://world/furniture/appliance_refrigerator.gd")
const ApplianceStoveScript = preload("res://world/furniture/appliance_stove.gd")
const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	# Iluminación de estudio
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.27, 0.31)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.70, 0.75)
	env.ambient_light_energy = 1.15
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -150.0, 0.0)
	fill.light_color = Color(0.72, 0.80, 0.92)
	fill.light_energy = 0.55
	_root.add_child(fill)

	# Suelo neutral
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(30.0, 0.1, 30.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.32, 0.33, 0.35)
	floor_mat.roughness = 0.75
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(floor_mesh)

	# Pared de fondo
	var wall_mesh := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(30.0, 10.0, 0.1)
	wall_mesh.mesh = wall_box
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.38, 0.40, 0.43)
	wall_mat.roughness = 0.9
	wall_mesh.material_override = wall_mat
	wall_mesh.position = Vector3(0.0, 5.0, -0.45)
	_root.add_child(wall_mesh)

	# =========================================================================
	# SUITE 1: COCINA COMPLETA CERRADA (X centrado en -1.7)
	# =========================================================================
	var suite1 := Node3D.new()
	suite1.name = "KitchenClosedSuite"
	suite1.position = Vector3(-1.7, 0.0, 0.0)
	_root.add_child(suite1)

	# 1. Estufa cerrada
	var stove1 = ApplianceStoveScript.new()
	stove1.name = "Stove1"
	stove1.position = Vector3(-0.85, 0.0, 0.0)
	suite1.add_child(stove1)

	# 2. Gabinete Bajo con Granito cerrado
	var cab_base1 = KitchenCabinetScript.new()
	cab_base1.name = "CabinetBase1"
	cab_base1.cabinet_type = KitchenCabinetScript.CabinetType.BASE_COUNTER
	cab_base1.position = Vector3(0.0, 0.0, 0.0)
	suite1.add_child(cab_base1)

	# 3. Microondas cerrado sobre la encimera de granito
	var micro1 = ApplianceMicrowaveScript.new()
	micro1.name = "Micro1"
	micro1.position = Vector3(0.0, 0.86, 0.06)
	suite1.add_child(micro1)

	# 4. Alacena Aérea cerrada arriba
	var cab_wall1 = KitchenCabinetScript.new()
	cab_wall1.name = "CabinetWall1"
	cab_wall1.cabinet_type = KitchenCabinetScript.CabinetType.WALL_HANGING
	cab_wall1.position = Vector3(0.0, 1.45, -0.12)
	suite1.add_child(cab_wall1)

	# 5. Refrigerador cerrado a la derecha
	var refri1 = ApplianceRefrigeratorScript.new()
	refri1.name = "Refri1"
	refri1.position = Vector3(0.85, 0.0, 0.0)
	suite1.add_child(refri1)

	# =========================================================================
	# SUITE 2: COCINA COMPLETA ABIERTA (X centrado en +1.7)
	# =========================================================================
	var suite2 := Node3D.new()
	suite2.name = "KitchenOpenSuite"
	suite2.position = Vector3(1.7, 0.0, 0.0)
	_root.add_child(suite2)

	# 1. Estufa con Horno Abierto hacia abajo
	var stove2 = ApplianceStoveScript.new()
	stove2.name = "Stove2"
	stove2.oven_open_ratio = 0.95
	stove2.position = Vector3(-0.85, 0.0, 0.0)
	suite2.add_child(stove2)

	# 2. Gabinete Bajo con puertas abiertas mostrando repisa interior
	var cab_base2 = KitchenCabinetScript.new()
	cab_base2.name = "CabinetBase2"
	cab_base2.cabinet_type = KitchenCabinetScript.CabinetType.BASE_COUNTER
	cab_base2.left_door_open_ratio = 0.85
	cab_base2.right_door_open_ratio = 0.85
	cab_base2.position = Vector3(0.0, 0.0, 0.0)
	suite2.add_child(cab_base2)

	# 3. Microondas abierto mostrando cavidad y plato giratorio
	var micro2 = ApplianceMicrowaveScript.new()
	micro2.name = "Micro2"
	micro2.door_open_ratio = 0.90
	micro2.position = Vector3(0.0, 0.86, 0.06)
	suite2.add_child(micro2)

	# 4. Alacena Aérea con ambas puertas abiertas
	var cab_wall2 = KitchenCabinetScript.new()
	cab_wall2.name = "CabinetWall2"
	cab_wall2.cabinet_type = KitchenCabinetScript.CabinetType.WALL_HANGING
	cab_wall2.left_door_open_ratio = 0.85
	cab_wall2.right_door_open_ratio = 0.85
	cab_wall2.position = Vector3(0.0, 1.45, -0.12)
	suite2.add_child(cab_wall2)

	# 5. Refrigerador con congelador y puerta principal abiertos
	var refri2 = ApplianceRefrigeratorScript.new()
	refri2.name = "Refri2"
	refri2.freezer_open_ratio = 0.85
	refri2.main_door_open_ratio = 0.90
	refri2.position = Vector3(0.85, 0.0, 0.0)
	suite2.add_child(refri2)

	# Cámara
	_cam = Camera3D.new()
	_cam.fov = 46.0
	_root.add_child(_cam)
	_cam.position = Vector3(0.0, 1.35, 4.3)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# Frame 6: Vista panorámica frontal de ambas cocinas (cerrada y abierta)
	if _frames == 6:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_kitchen_suite_full_overview.png")
				print("✓ 1. Vista Panorámica Cocinas Cerrada y Abierta guardada")

		# Preparar cámara ángulo 3/4 para la cocina cerrada (idéntico al reference image 3)
		_cam.position = Vector3(-2.8, 1.45, 2.9)
		_cam.look_at_from_position(_cam.position, Vector3(-1.7, 1.05, 0.0), Vector3.UP)

	elif _frames == 10:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_kitchen_suite_closed_angle.png")
				print("✓ 2. Vista Ángulo 3D Cocina Cerrada guardada")

		# Preparar cámara ángulo 3/4 para la cocina abierta
		_cam.position = Vector3(0.6, 1.45, 2.9)
		_cam.look_at_from_position(_cam.position, Vector3(1.7, 1.05, 0.0), Vector3.UP)

	elif _frames == 14:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_kitchen_suite_open_angle.png")
				print("✓ 3. Vista Ángulo 3D Cocina Abierta guardada")

	elif _frames >= 18:
		quit(0)
		return true

	return false
