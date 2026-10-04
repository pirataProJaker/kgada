extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const ApplianceRefrigeratorScript = preload("res://world/furniture/appliance_refrigerator.gd")
const ApplianceStoveScript = preload("res://world/furniture/appliance_stove.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D

var _refri_closed: Node3D
var _refri_open: Node3D
var _stove_closed: Node3D
var _stove_open: Node3D

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	# Iluminación de estudio para apreciar los detalles esmaltados y texturas
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.85, 0.87, 0.90)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 1.2
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -145.0, 0.0)
	fill.light_color = Color(0.80, 0.85, 0.95)
	fill.light_energy = 0.6
	_root.add_child(fill)

	# Suelo neutral
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(30.0, 0.1, 30.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.88, 0.87, 0.84)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(floor_mesh)

	# =========================================================================
	# 1. Refrigerador Cerrado (X = -2.2)
	# =========================================================================
	_refri_closed = ApplianceRefrigeratorScript.new()
	_refri_closed.name = "RefriClosed"
	_refri_closed.position = Vector3(-2.2, 0.0, 0.0)
	_refri_closed.rotation_degrees.y = 15.0
	_root.add_child(_refri_closed)

	# =========================================================================
	# 2. Refrigerador Abierto mostrando interior, repisas y congelador (X = -0.7)
	# =========================================================================
	_refri_open = ApplianceRefrigeratorScript.new()
	_refri_open.name = "RefriOpen"
	_refri_open.freezer_open_ratio = 0.85
	_refri_open.main_door_open_ratio = 0.90
	_refri_open.position = Vector3(-0.7, 0.0, 0.0)
	_refri_open.rotation_degrees.y = -10.0
	_root.add_child(_refri_open)

	# =========================================================================
	# 3. Estufa Cerrada (X = 0.9)
	# =========================================================================
	_stove_closed = ApplianceStoveScript.new()
	_stove_closed.name = "StoveClosed"
	_stove_closed.position = Vector3(0.9, 0.0, 0.0)
	_stove_closed.rotation_degrees.y = 15.0
	_root.add_child(_stove_closed)

	# =========================================================================
	# 4. Estufa con Horno Abierto mostrando cavidad y rejilla (X = 2.2)
	# =========================================================================
	_stove_open = ApplianceStoveScript.new()
	_stove_open.name = "StoveOpen"
	_stove_open.oven_open_ratio = 0.95
	_stove_open.position = Vector3(2.2, 0.0, 0.0)
	_stove_open.rotation_degrees.y = -15.0
	_root.add_child(_stove_open)

	_cam = Camera3D.new()
	_cam.fov = 48.0
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Acercamiento al Refrigerador Cerrado y Abierto
	if _frames == 10:
		_cam.position = Vector3(-1.45, 1.35, 2.4)
		_cam.look_at_from_position(_cam.position, Vector3(-1.45, 0.90, 0.0), Vector3.UP)

	elif _frames == 16:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_refrigerator_showcase.png")
				print("✓ Captura Refrigerador Cerrado y Abierto: verify_refrigerator_showcase.png")

	# Frame 20: Acercamiento a la Estufa Cerrada y con Horno Abierto
	elif _frames == 20:
		_cam.position = Vector3(1.55, 1.25, 2.2)
		_cam.look_at_from_position(_cam.position, Vector3(1.55, 0.65, 0.0), Vector3.UP)

	elif _frames == 26:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_stove_showcase.png")
				print("✓ Captura Estufa Quemadores y Horno Abierto: verify_stove_showcase.png")

	# Frame 30: Vista general de la cocina completa con ambos electrodomésticos
	elif _frames == 30:
		_cam.position = Vector3(0.0, 2.2, 4.2)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.85, 0.0), Vector3.UP)

	elif _frames == 36:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_appliances_kitchen_overview.png")
				print("✓ Captura Vista General Cocina Electrodomésticos: verify_appliances_kitchen_overview.png")

	elif _frames >= 40:
		quit(0)

	return false
