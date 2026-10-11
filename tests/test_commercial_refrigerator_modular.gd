extends SceneTree

const CommercialRefrigeratorModularScript = preload("res://world/furniture/commercial_refrigerator_modular.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

var _frames := 0
var _cam: Camera3D = null
var _root_node: Node3D = null
var _cooler_1door: Node3D = null
var _cooler_2door: Node3D = null

func _init() -> void:
	print("[TestCommercialCooler] === INICIANDO VALIDACIÓN DE REFRIGERADORES COMERCIALES ===")
	CommercialRefrigeratorModularScript.clear_cache()

	# 1. Validar inicialización del Atlas Inteligente
	FurnitureTextureManagerScript.ensure_initialized()
	var layer := FurnitureTextureManagerScript.get_texture_layer("commercial_cooler")
	print("[TestCommercialCooler] ✓ Capa commercial_cooler en Texture2DArray: %d" % layer)

	# 2. Validar mallas compartidas para 1 puerta y 2 puertas
	var mesh_single := CommercialRefrigeratorModularScript.get_shared_body_mesh(
		CommercialRefrigeratorModularScript.RefrigeratorType.SINGLE_DOOR,
		CommercialRefrigeratorModularScript.FinishColor.BLACK_MODERN,
		1.00, 0.88, 2.05, 5
	)
	assert(mesh_single != null, "La malla de 1 puerta no debe ser nula")
	print("[TestCommercialCooler] ✓ Malla compartida 1 puerta generada con éxito (%d superficies)." % mesh_single.get_surface_count())

	var mesh_double := CommercialRefrigeratorModularScript.get_shared_body_mesh(
		CommercialRefrigeratorModularScript.RefrigeratorType.DOUBLE_DOOR,
		CommercialRefrigeratorModularScript.FinishColor.WHITE_HOSPITALITY,
		1.80, 0.88, 2.05, 5
	)
	assert(mesh_double != null, "La malla de 2 puertas no debe ser nula")
	print("[TestCommercialCooler] ✓ Malla compartida 2 puertas generada con éxito (%d superficies)." % mesh_double.get_surface_count())

	# 3. Validar integración con FurnitureMultiMeshSystem (GPU Instancing)
	var fms := FurnitureMultiMeshSystemScript.new()
	root.add_child(fms)
	fms.add_commercial_refrigerator(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0, 1) # Single black
	fms.add_commercial_refrigerator(Transform3D(Basis.IDENTITY, Vector3(3, 0, 0)), 1, 0) # Double white
	fms.build(true)
	print("[TestCommercialCooler] ✓ FurnitureMultiMeshSystem compiló correctamente las vitrinas en GPU.")
	fms.queue_free()

	# 4. Crear escena de visualización para captura
	_root_node = Node3D.new()
	root.add_child(_root_node)

	# Piso gris neutro de exhibición
	var floor_body := StaticBody3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(20.0, 0.2, 20.0)
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	var mat_fl := StandardMaterial3D.new()
	mat_fl.albedo_color = Color(0.82, 0.82, 0.84)
	floor_inst.material_override = mat_fl
	floor_inst.position.y = -0.1
	floor_body.add_child(floor_inst)
	_root_node.add_child(floor_body)

	# Luz ambiental y direccional brillante
	var light := DirectionalLight3D.new()
	light.position = Vector3(4.0, 6.0, 5.0)
	light.look_at_from_position(light.position, Vector3(0, 1, 0))
	light.light_energy = 1.3
	_root_node.add_child(light)

	# Vitrina 1: Doble Puerta Blanco Hostelero (como la de la izquierda de la imagen) en X = -1.2
	_cooler_2door = CommercialRefrigeratorModularScript.new()
	_cooler_2door.name = "CoolerDoubleDoor_White"
	_cooler_2door.refrigerator_type = CommercialRefrigeratorModularScript.RefrigeratorType.DOUBLE_DOOR
	_cooler_2door.finish_color = CommercialRefrigeratorModularScript.FinishColor.WHITE_HOSPITALITY
	_cooler_2door.width = 1.80
	_cooler_2door.depth = 0.90
	_cooler_2door.height = 2.05
	_cooler_2door.auto_stock = true
	_cooler_2door.position = Vector3(-1.20, 0.0, 0.0)
	_root_node.add_child(_cooler_2door)

	# Vitrina 2: Una Puerta Negro Vitrina (como la de la derecha de la imagen) en X = +1.10
	_cooler_1door = CommercialRefrigeratorModularScript.new()
	_cooler_1door.name = "CoolerSingleDoor_Black"
	_cooler_1door.refrigerator_type = CommercialRefrigeratorModularScript.RefrigeratorType.SINGLE_DOOR
	_cooler_1door.finish_color = CommercialRefrigeratorModularScript.FinishColor.BLACK_MODERN
	_cooler_1door.width = 1.00
	_cooler_1door.depth = 0.90
	_cooler_1door.height = 2.05
	_cooler_1door.auto_stock = true
	_cooler_1door.position = Vector3(1.10, 0.0, 0.0)
	_root_node.add_child(_cooler_1door)

	# Cámara 3D
	_cam = Camera3D.new()
	_cam.current = true
	_cam.position = Vector3(0.0, 1.35, 3.4)
	_cam.look_at_from_position(_cam.position, Vector3(0.0, 1.05, 0.0))
	_root_node.add_child(_cam)

	print("[TestCommercialCooler] ✓ Escena de showcase configurada con ambos modelos.")


func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 15: Captura con puertas cerradas (Frontal completa de ambos modelos)
	if _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/commercial_coolers_showcase_closed.png")
				print("✓ Captura 1 guardada: commercial_coolers_showcase_closed.png")

	# Frame 20: Abrir las puertas para apreciar la mercancía interna y estantes
	elif _frames == 20:
		if _cooler_2door:
			_cooler_2door.left_door_open_ratio = 0.75
			_cooler_2door.right_door_open_ratio = 0.75
		if _cooler_1door:
			_cooler_1door.right_door_open_ratio = 0.80

	# Frame 25: Captura con puertas abiertas
	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/commercial_coolers_showcase_open.png")
				print("✓ Captura 2 guardada: commercial_coolers_showcase_open.png")

	# Frame 30: Detalle cercano a la vitrina de 2 puertas
	elif _frames == 30:
		if _cam:
			_cam.position = Vector3(-1.10, 1.25, 2.1)
			_cam.look_at_from_position(_cam.position, Vector3(-1.10, 1.10, 0.0))

	# Frame 35: Captura detalle de 2 puertas
	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/commercial_cooler_double_closeup.png")
				print("✓ Captura 3 guardada: commercial_cooler_double_closeup.png")
				quit(0)

	return false
