extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")
const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const ApplianceToasterScript = preload("res://world/furniture/appliance_toaster.gd")
const CoffeeTableScript = preload("res://world/furniture/coffee_table.gd")
const ApplianceWasherScript = preload("res://world/furniture/appliance_washer.gd")
const ApplianceDryerScript = preload("res://world/furniture/appliance_dryer.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D

var _base_cab: Node3D
var _micro: Node3D
var _toaster: Node3D
var _coffee_table: Node3D
var _washer: Node3D
var _dryer: Node3D


func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	# Iluminación
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.65, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.63, 0.68)
	env.ambient_light_energy = 0.45
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill.light_color = Color(0.85, 0.88, 0.95)
	fill.light_energy = 0.30
	_root.add_child(fill)

	# Suelo
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	floor_mesh.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.55, 0.53, 0.50)
	fmat.roughness = 0.85
	floor_mesh.material_override = fmat
	_root.add_child(floor_mesh)

	# Pared trasera
	var wall := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(20.0, 4.0, 0.20)
	wall.mesh = wall_box
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.40, 0.44, 0.48) # Pared gris azulada tipo azulejo / lavandería
	wall.material_override = wmat
	wall.position = Vector3(0.0, 2.0, -1.5)
	_root.add_child(wall)

	_cam = Camera3D.new()
	_cam.current = true
	_root.add_child(_cam)

	# =========================================================================
	# 1. ESTACIÓN COCINA: Gabinete Base con Microondas Compacto y Tostadora
	# =========================================================================
	_base_cab = KitchenCabinetScript.new()
	_base_cab.name = "ShowcaseBaseCabinet"
	_base_cab.position = Vector3(-2.2, 0.0, -1.0)
	_base_cab.rotation.y = 0.0
	_base_cab.left_door_open_ratio = 0.85   # Puerta izquierda abierta
	_base_cab.right_door_open_ratio = 0.85  # Puerta derecha abierta
	_root.add_child(_base_cab)

	# Microondas compacto (ancho 0.42m - mitad del mueble) sobre encimera izquierda
	_micro = ApplianceMicrowaveScript.new()
	_micro.name = "ShowcaseMicrowave"
	_micro.position = Vector3(-2.2 - 0.20, 0.86, -1.0 + 0.04)
	_micro.door_open_ratio = 0.90 # Puerta de microondas abierta
	_root.add_child(_micro)

	# Tostadora de pan sobre encimera derecha
	_toaster = ApplianceToasterScript.new()
	_toaster.name = "ShowcaseToaster"
	_toaster.position = Vector3(-2.2 + 0.24, 0.86, -1.0 + 0.04)
	_toaster.lever_ratio = 0.0 # Pan tostado arriba ("pop-up")
	_root.add_child(_toaster)

	# =========================================================================
	# 2. ESTACIÓN SALA: Coffee Table con Cajón Abierto
	# =========================================================================
	_coffee_table = CoffeeTableScript.new()
	_coffee_table.name = "ShowcaseCoffeeTable"
	_coffee_table.position = Vector3(0.0, 0.0, -0.6)
	_coffee_table.drawer_open_ratio = 0.85 # Cajón deslizado hacia afuera
	_root.add_child(_coffee_table)

	# =========================================================================
	# 3. ESTACIÓN LAVANDERÍA: Lavadora y Secadora Pareja
	# =========================================================================
	_washer = ApplianceWasherScript.new()
	_washer.name = "ShowcaseWasher"
	_washer.position = Vector3(1.8, 0.0, -1.0)
	_washer.door_open_ratio = 0.90 # Puerta superior abierta
	_root.add_child(_washer)

	_dryer = ApplianceDryerScript.new()
	_dryer.name = "ShowcaseDryer"
	_dryer.position = Vector3(1.8 + 0.74, 0.0, -1.0)
	_dryer.door_open_ratio = 0.90 # Puerta inferior abierta
	_root.add_child(_dryer)

	print("✓ Modelos configurados. Iniciando captura de verificación...")


func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Vista General de Todo el Mobiliario Nuevo
	if _frames == 10:
		_cam.position = Vector3(0.0, 1.6, 2.2)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.55, -0.8))

	elif _frames == 14:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_all_new_appliances_overview.png")
				print("✓ 1. verify_all_new_appliances_overview.png guardada.")

	# Frame 20: Primer Plano de Cocina (Gabinete 2 puertas abiertas + Microondas compacto + Tostadora)
	elif _frames == 20:
		_cam.position = Vector3(-2.2, 1.25, 0.40)
		_cam.look_at_from_position(_cam.position, Vector3(-2.2, 0.65, -0.95))

	elif _frames == 24:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_kitchen_microwave_toaster_cabinet.png")
				print("✓ 2. verify_kitchen_microwave_toaster_cabinet.png guardada.")

	# Frame 30: Primer Plano Coffee Table (Madera cálida + Cajón abierto)
	elif _frames == 30:
		_cam.position = Vector3(0.0, 0.95, 0.70)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 0.35, -0.55))

	elif _frames == 34:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_coffee_table_drawer.png")
				print("✓ 3. verify_coffee_table_drawer.png guardada.")

	# Frame 40: Primer Plano Lavandería con Puertas Abiertas
	elif _frames == 40:
		_cam.position = Vector3(2.17, 1.38, 0.60)
		_cam.look_at_from_position(_cam.position, Vector3(2.17, 0.65, -1.0))

	elif _frames == 44:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_laundry_washer_dryer_open.png")
				print("✓ 4. verify_laundry_washer_dryer_open.png guardada.")

	# Frame 46: Acercamiento directo al interior de la Lavadora (Tina redonda, collarín y rodillo/agitador con aspas)
	elif _frames == 46:
		_cam.position = Vector3(1.80, 1.42, -0.45)
		_cam.look_at_from_position(_cam.position, Vector3(1.80, 0.68, -0.96))

	elif _frames == 50:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_laundry_washer_open_agitator.png")
				print("✓ 5. verify_laundry_washer_open_agitator.png guardada.")

	# Frame 52: Cerrar puertas de lavadora y secadora para capturar réplica exacta de la imagen del usuario
	elif _frames == 52:
		_washer.door_open_ratio = 0.0
		_dryer.door_open_ratio = 0.0
		# Ángulo frontal-perspectiva como la imagen del usuario
		_cam.position = Vector3(1.60, 1.28, 0.70)
		_cam.look_at_from_position(_cam.position, Vector3(2.17, 0.72, -1.0))

	elif _frames == 56:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/verify_laundry_washer_dryer_closed.png")
				img.save_png(ARTIFACT_DIR + "/verify_laundry_washer_dryer.png")
				print("✓ 6. verify_laundry_washer_dryer_closed.png guardada.")

	elif _frames == 60:
		# Probar interact() en todos los objetos para asegurar que el método funciona
		_base_cab.interact()
		_micro.interact()
		_toaster.interact()
		_coffee_table.interact()
		_washer.interact()
		_dryer.interact()
		print("✓ interact() ejecutado con éxito en todos los muebles y electrodomésticos.")

	elif _frames == 64:
		quit(0)

	return false
