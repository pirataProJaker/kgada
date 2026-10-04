extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const WoodenChairScript = preload("res://world/furniture/wooden_chair.gd")
const WoodenTableScript = preload("res://world/furniture/wooden_table.gd")
const DiningSetScript = preload("res://world/furniture/dining_set.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	FurnitureTextureManagerScript.ensure_initialized()

	# Iluminación de estudio
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.84, 0.87)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.72, 0.76)
	env.ambient_light_energy = 1.15
	env_node.environment = env
	_root.add_child(env_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	key_light.light_color = Color(1.0, 0.98, 0.92)
	key_light.light_energy = 1.3
	key_light.shadow_enabled = true
	_root.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill_light.light_color = Color(0.75, 0.80, 0.90)
	fill_light.light_energy = 0.5
	_root.add_child(fill_light)

	# Suelo de estudio neutral
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(40.0, 0.1, 40.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.90, 0.89, 0.86)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(floor_mesh)

	# =========================================================================
	# ZONA 1: MultiMesh de Sillas mostrando los 4 Acabados de Madera (X = -3.5 a +3.5)
	# =========================================================================
	var chairs_sys := FurnitureMultiMeshSystemScript.new()
	chairs_sys.name = "ShowcaseFinishesMultiMesh"
	_root.add_child(chairs_sys)

	# 4 sillas con los 4 acabados: Roble, Nogal, Caoba, Pino
	var x_pos := [-3.0, -1.0, 1.0, 3.0]
	for idx in range(4):
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), Vector3(x_pos[idx], 0.0, 1.0))
		chairs_sys.add_chair(t, idx)

	# 2 mesas mostrando acabados Roble y Nogal
	var t_table0 := Transform3D(Basis(Vector3.UP, deg_to_rad(10.0)), Vector3(-2.0, 0.0, 3.2))
	chairs_sys.add_table(t_table0, 0) # Roble claro
	var t_table1 := Transform3D(Basis(Vector3.UP, deg_to_rad(-10.0)), Vector3(2.0, 0.0, 3.2))
	chairs_sys.add_table(t_table1, 1) # Nogal oscuro

	chairs_sys.build(true)

	# =========================================================================
	# ZONA 2: Comedor Completo GPU MultiMesh (Mesa + 6 Sillas a juego en Z = -3.5)
	# =========================================================================
	var dining_sys := FurnitureMultiMeshSystemScript.new()
	dining_sys.name = "FullDiningMultiMesh"
	_root.add_child(dining_sys)
	
	var dining_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -3.5))
	dining_sys.add_dining_set(dining_transform, 0, 6, 0.48) # 6 sillas, Roble claro
	dining_sys.build(true)

	# Cámara interactiva
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Acercamiento a los 4 acabados de madera (Roble, Nogal, Caoba, Pino)
	if _frames == 10:
		_cam.position = Vector3(0.0, 1.3, 4.6)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.5, 1.5), Vector3.UP)

	elif _frames == 16:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_multimesh_wood_finishes.png")
				print("✓ Captura Acabados de Madera MultiMesh: verify_multimesh_wood_finishes.png")

	# Frame 20: Acercamiento angular al Comedor Completo GPU MultiMesh
	elif _frames == 20:
		_cam.position = Vector3(2.4, 1.7, -1.6)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.6, -3.5), Vector3.UP)

	elif _frames == 26:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_multimesh_dining_set.png")
				print("✓ Captura Comedor GPU MultiMesh (1 Draw Call Mesa + 1 Sillas): verify_multimesh_dining_set.png")

	# Frame 30: Vista general del estudio completo
	elif _frames == 30:
		_cam.position = Vector3(4.5, 4.0, 4.5)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.5, -0.5), Vector3.UP)

	elif _frames == 36:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_furniture_instancing_overview.png")
				print("✓ Captura Vista General Estudio Mobiliario: verify_furniture_instancing_overview.png")

	elif _frames >= 40:
		quit(0)

	return false
