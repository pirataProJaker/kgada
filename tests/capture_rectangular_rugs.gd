extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")
const NightstandOakScript = preload("res://world/furniture/nightstand_oak.gd")
const CoffeeTableScript = preload("res://world/furniture/coffee_table.gd")
const ArmchairLeatherScript = preload("res://world/furniture/armchair_leather.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	FurnitureTextureManagerScript.ensure_initialized()

	# Entorno de iluminación
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.85, 0.88, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.77, 0.80)
	env.ambient_light_energy = 1.2
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_root.add_child(sun)

	# Suelo general
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(30.0, 0.1, 30.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.88, 0.86, 0.82)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(floor_mesh)

	# Sistema MultiMesh para todas las alfombras
	var mm_sys := FurnitureMultiMeshSystemScript.new()
	_root.add_child(mm_sys)

	# 1. Galería de las 20 alfombras en cuadrícula de 5 columnas x 4 filas
	# Cada una con su W=1.75m, L=1.20m rectangular
	for id in range(20):
		var col := id % 5
		var row := id / 5
		var x := float(col - 2) * 2.3
		var z := float(row - 1.5) * 1.7 - 4.0
		var t := Transform3D(Basis.IDENTITY, Vector3(x, 0.005, z))
		mm_sys.add_rug_rectangular(t, id)

	# 2. Escena Recámara: Cama + Buró + Alfombra Rectangular #1 (Persa Granate)
	var bed_pos := Vector3(-3.0, 0.0, 2.5)
	mm_sys.add_bed_single(Transform3D(Basis.IDENTITY, bed_pos), BedSingleOakScript.BedState.MADE, 2, 7, true, 0.0)
	mm_sys.add_nightstand(Transform3D(Basis.IDENTITY, bed_pos + Vector3(-0.95, 0.0, -0.6)))
	mm_sys.add_rug_rectangular(Transform3D(Basis.IDENTITY, bed_pos + Vector3(1.35, 0.005, 0.3)), 1) # Rug #1 Persa Granate

	# 3. Escena Sala: Mesa de Centro + Sillón + Alfombra Rectangular #11 (Celosía Marino)
	var living_pos := Vector3(3.0, 0.0, 2.5)
	mm_sys.add_coffee_table(Transform3D(Basis.IDENTITY, living_pos))
	mm_sys.add_armchair(Transform3D(Basis(Vector3.UP, PI), living_pos + Vector3(0.0, 0.0, 1.25)))
	mm_sys.add_rug_rectangular(Transform3D(Basis.IDENTITY, living_pos + Vector3(0.0, 0.005, 0.0)), 11) # Rug #11 Celosía Marino

	# Compilar todo el sistema MultiMesh
	mm_sys.build(false)

	# Cámara de captura
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 50.0
	_root.add_child(_cam)

	# Vista 1: Galería completa de las 20 alfombras
	_cam.position = Vector3(0.0, 7.5, 2.5)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.0, -4.0))

func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# Frame 10: Captura de la galería de 20 alfombras
	if _frames == 10:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/rugs_20_gallery_overview.png")
				print("✓ Captura guardada: rugs_20_gallery_overview.png")

	# Frame 15: Mover cámara a la Recámara
	elif _frames == 15:
		_cam.position = Vector3(-3.0, 2.8, 5.0)
		_cam.look_at_from_position(_cam.position, Vector3(-2.6, 0.4, 2.5))

	# Frame 25: Captura de la Recámara
	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/rugs_bedroom_integration.png")
				print("✓ Captura guardada: rugs_bedroom_integration.png")

	# Frame 30: Mover cámara a la Sala
	elif _frames == 30:
		_cam.position = Vector3(3.0, 2.8, 5.0)
		_cam.look_at_from_position(_cam.position, Vector3(3.0, 0.4, 2.5))

	# Frame 40: Captura de la Sala
	elif _frames == 40:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/rugs_living_room_integration.png")
				print("✓ Captura guardada: rugs_living_room_integration.png")

	elif _frames >= 45:
		print("✓ Todas las capturas renderizadas exitosamente.")
		quit(0)

	return false
