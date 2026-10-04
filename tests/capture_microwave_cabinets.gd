extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D

var _base_closed: Node3D
var _wall_closed: Node3D
var _micro_closed: Node3D

var _base_open: Node3D
var _wall_open: Node3D
var _micro_open: Node3D

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	# Iluminación de estudio
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.24, 0.26, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.70, 0.75)
	env.ambient_light_energy = 1.15
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 32.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -150.0, 0.0)
	fill.light_color = Color(0.72, 0.80, 0.92)
	fill.light_energy = 0.55
	_root.add_child(fill)

	# Piso de exhibición
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(30.0, 0.1, 30.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.36, 0.38)
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
	wall_mat.albedo_color = Color(0.40, 0.42, 0.45)
	wall_mat.roughness = 0.9
	wall_mesh.material_override = wall_mat
	wall_mesh.position = Vector3(0.0, 5.0, -0.45)
	_root.add_child(wall_mesh)

	# =========================================================================
	# SET 1: GABINETES Y MICROONDAS CERRADOS (Izquierda: X = -1.1)
	# =========================================================================
	_base_closed = KitchenCabinetScript.new()
	_base_closed.name = "BaseClosed"
	_base_closed.cabinet_type = KitchenCabinetScript.CabinetType.BASE_COUNTER
	_base_closed.position = Vector3(-1.1, 0.0, 0.0)
	_root.add_child(_base_closed)

	# Microondas sobre la encimera
	_micro_closed = ApplianceMicrowaveScript.new()
	_micro_closed.name = "MicroClosed"
	_micro_closed.position = Vector3(-1.1, 0.86, 0.08)
	_root.add_child(_micro_closed)

	# Alacena aérea superior
	_wall_closed = KitchenCabinetScript.new()
	_wall_closed.name = "WallClosed"
	_wall_closed.cabinet_type = KitchenCabinetScript.CabinetType.WALL_HANGING
	_wall_closed.position = Vector3(-1.1, 1.45, -0.12)
	_root.add_child(_wall_closed)

	# =========================================================================
	# SET 2: GABINETES Y MICROONDAS ABIERTOS (Derecha: X = 1.1)
	# =========================================================================
	_base_open = KitchenCabinetScript.new()
	_base_open.name = "BaseOpen"
	_base_open.cabinet_type = KitchenCabinetScript.CabinetType.BASE_COUNTER
	_base_open.left_door_open_ratio = 0.85
	_base_open.right_door_open_ratio = 0.85
	_base_open.position = Vector3(1.1, 0.0, 0.0)
	_root.add_child(_base_open)

	# Microondas con puerta abierta
	_micro_open = ApplianceMicrowaveScript.new()
	_micro_open.name = "MicroOpen"
	_micro_open.door_open_ratio = 0.90
	_micro_open.position = Vector3(1.1, 0.86, 0.08)
	_root.add_child(_micro_open)

	# Alacena aérea abierta
	_wall_open = KitchenCabinetScript.new()
	_wall_open.name = "WallOpen"
	_wall_open.cabinet_type = KitchenCabinetScript.CabinetType.WALL_HANGING
	_wall_open.left_door_open_ratio = 0.85
	_wall_open.right_door_open_ratio = 0.85
	_wall_open.position = Vector3(1.1, 1.45, -0.12)
	_root.add_child(_wall_open)

	# Cámara
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_root.add_child(_cam)
	_cam.position = Vector3(0.0, 1.30, 3.5)
	_cam.look_at(Vector3(0.0, 1.10, 0.0))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_capture_front_view()
	elif _frames == 8:
		_capture_angle_view()
		quit(0)
		return true
	return false


func _capture_front_view() -> void:
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img and not img.is_empty():
		var out_path := ARTIFACT_DIR + "/verify_microwave_cabinets_showcase.png"
		img.save_png(out_path)
		print("Guardada vista frontal en: ", out_path)

	# Ajustar cámara para vista angular en el siguiente frame
	_cam.position = Vector3(-1.6, 1.35, 2.7)
	_cam.look_at(Vector3(-0.9, 1.05, 0.0))


func _capture_angle_view() -> void:
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img and not img.is_empty():
		var out_path := ARTIFACT_DIR + "/verify_microwave_cabinets_closed_angle.png"
		img.save_png(out_path)
		print("Guardada vista angular en: ", out_path)
