extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D
var _fms: FurnitureMultiMeshSystem

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	FurnitureTextureManagerScript.ensure_initialized()

	# Iluminación de estudio profesional
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.88, 0.90, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 1.15
	env_node.environment = env
	_root.add_child(env_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	key_light.light_color = Color(1.0, 0.99, 0.95)
	key_light.light_energy = 1.3
	key_light.shadow_enabled = true
	_root.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-25.0, -145.0, 0.0)
	fill_light.light_color = Color(0.75, 0.82, 0.92)
	fill_light.light_energy = 0.55
	_root.add_child(fill_light)

	# Suelo de estudio
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(50.0, 0.1, 50.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.92, 0.92, 0.90)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(floor_mesh)

	# Sistema MultiMesh único para TODO el mobiliario
	_fms = FurnitureMultiMeshSystemScript.new()
	_fms.name = "AllFurnitureMultiMesh"
	_root.add_child(_fms)

	# 1. Comedor (Mesa + Sillas)
	var dining_t := Transform3D(Basis.IDENTITY, Vector3(-5.5, 0.0, 0.0))
	_fms.add_dining_set(dining_t, 0, 4)

	# 2. Refrigerador
	_fms.add_refrigerator(Transform3D(Basis.IDENTITY, Vector3(-3.4, 0.0, 0.0)))

	# 3. Estufa
	_fms.add_stove(Transform3D(Basis.IDENTITY, Vector3(-2.2, 0.0, 0.0)))

	# 4. Gabinete bajo mesada + Tostadora encima
	_fms.add_cabinet_base(Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 0.0)))
	_fms.add_toaster(Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.90, 0.0)))

	# 5. Gabinete aéreo + Microondas debajo/en frente
	_fms.add_cabinet_wall(Transform3D(Basis.IDENTITY, Vector3(0.1, 1.35, 0.0)))
	_fms.add_microwave(Transform3D(Basis.IDENTITY, Vector3(0.1, 0.0, 0.0)))

	# 6. Mesa de Centro (Coffee table)
	_fms.add_coffee_table(Transform3D(Basis.IDENTITY, Vector3(1.4, 0.0, 0.0)))

	# 7. Sillón Orejero de Cuero (Armchair)
	_fms.add_armchair(Transform3D(Basis(Vector3.UP, deg_to_rad(-25.0)), Vector3(2.6, 0.0, 0.0)))

	# 8. Lavadora
	_fms.add_washer(Transform3D(Basis.IDENTITY, Vector3(3.8, 0.0, 0.0)))

	# 9. Secadora
	_fms.add_dryer(Transform3D(Basis.IDENTITY, Vector3(4.8, 0.0, 0.0)))

	# 10. Mueble personalizado compuesto 100% de Primitivas (Cubo + Cilindros + Cuña)
	# Banco / otomana con asiento acolchado y patas cilíndricas de madera
	var stool_center := Vector3(6.0, 0.0, 0.0)
	# 4 patas cilíndricas
	var leg_r := 0.04
	var leg_h := 0.28
	var leg_offsets := [
		Vector3(-0.25, leg_h * 0.5, -0.20),
		Vector3( 0.25, leg_h * 0.5, -0.20),
		Vector3(-0.25, leg_h * 0.5,  0.20),
		Vector3( 0.25, leg_h * 0.5,  0.20)
	]
	for lo in leg_offsets:
		var leg_basis := Basis().scaled(Vector3(leg_r * 2.0, leg_h, leg_r * 2.0))
		_fms.add_primitive_cylinder(Transform3D(leg_basis, stool_center + lo), "pino_natural", 0.40, 0.02)

	# Asiento cúbico tapizado en cuero
	var seat_sz := Vector3(0.65, 0.16, 0.55)
	var seat_basis := Basis().scaled(seat_sz)
	_fms.add_primitive_cube(Transform3D(seat_basis, stool_center + Vector3(0.0, leg_h + seat_sz.y * 0.5, 0.0)), "sofa_leather", 0.65, 0.05)

	# Respaldo en cuña/prisma
	var wedge_sz := Vector3(0.65, 0.22, 0.18)
	var wedge_basis := Basis().scaled(wedge_sz)
	_fms.add_primitive_prism(Transform3D(wedge_basis, stool_center + Vector3(0.0, leg_h + seat_sz.y + wedge_sz.y * 0.5, -0.18)), "sofa_leather", 0.65, 0.05)

	# Compilar el sistema
	_fms.build(true)
	print("✓ Sistema compilado: %d muebles registrados, %d draw calls de MultiMesh activas." % [
		_fms.get_total_furniture_count(),
		_fms.get_active_multimesh_count()
	])

	# Cámara de captura
	_cam = Camera3D.new()
	_cam.current = true
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Vista general amplia de todo el mobiliario
	if _frames == 10:
		_cam.position = Vector3(0.5, 2.5, 6.8)
		_cam.look_at_from_position(_cam.position, Vector3(0.5, 0.7, 0.0))

	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/all_furniture_gpu_lineup.png")
				print("✓ Captura guardada: all_furniture_gpu_lineup.png")

	# Frame 20: Primer plano Cocina (Refrigerador, Estufa, Gabinetes, Tostadora, Microondas)
	elif _frames == 20:
		_cam.position = Vector3(-1.8, 1.5, 3.2)
		_cam.look_at_from_position(_cam.position, Vector3(-1.8, 0.85, 0.0))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/appliances_kitchen_gpu_closeup.png")
				print("✓ Captura guardada: appliances_kitchen_gpu_closeup.png")

	# Frame 30: Primer plano Sala y Lavandería (Sillón, Mesa Centro, Lavadora, Secadora, Banco Primitivo)
	elif _frames == 30:
		_cam.position = Vector3(3.6, 1.4, 3.4)
		_cam.look_at_from_position(_cam.position, Vector3(3.6, 0.65, 0.0))

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/living_laundry_gpu_closeup.png")
				print("✓ Captura guardada: living_laundry_gpu_closeup.png")

	elif _frames >= 40:
		print("✓ Todas las capturas completadas.")
		quit(0)

	return false
