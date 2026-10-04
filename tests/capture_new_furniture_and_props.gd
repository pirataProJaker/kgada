extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const BookcaseTallScript = preload("res://world/furniture/bookcase_tall.gd")
const NightstandOakScript = preload("res://world/furniture/nightstand_oak.gd")
const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")
const WardrobeOakScript = preload("res://world/furniture/wardrobe_oak.gd")
const SinkUnitWhiteScript = preload("res://world/furniture/sink_unit_white.gd")
const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureStorageContainerScript = preload("res://world/furniture/furniture_storage_container.gd")

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
	env.ambient_light_color = Color(0.70, 0.72, 0.76)
	env.ambient_light_energy = 1.2
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill.light_color = Color(0.70, 0.78, 0.90)
	fill.light_energy = 0.55
	_root.add_child(fill)

	# Suelo de habitación
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(20.0, 0.1, 20.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.90, 0.90, 0.88)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(floor_mesh)

	# Pared posterior decorativa
	var wall_mesh := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(16.0, 3.2, 0.1)
	wall_mesh.mesh = wall_box
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.82, 0.84, 0.86)
	wall_mat.roughness = 0.9
	wall_mesh.material_override = wall_mat
	wall_mesh.position = Vector3(0.0, 1.6, -1.8)
	_root.add_child(wall_mesh)

	# 1. Tapete trenzado circular en el piso
	var mat_props := FurniturePropsBuilderScript.get_props_material(0.65, 0.02)

	var rug := MeshInstance3D.new()
	rug.mesh = FurniturePropsBuilderScript.get_rug_braided_mesh()
	rug.material_override = mat_props
	rug.position = Vector3(0.0, 0.002, 0.6)
	_root.add_child(rug)

	# 2. Cuadro de paisaje en la pared
	var pic := MeshInstance3D.new()
	pic.mesh = FurniturePropsBuilderScript.get_picture_landscape_mesh()
	pic.material_override = mat_props
	pic.position = Vector3(0.0, 1.85, -1.74)
	_root.add_child(pic)

	# 3. Cama individual de roble con edredón y almohada blanca
	var bed: BedSingleOakScript = BedSingleOakScript.new()
	bed.position = Vector3(0.0, 0.0, -0.3)
	_root.add_child(bed)

	# Periódico sobre la cama
	var news_bed := MeshInstance3D.new()
	news_bed.mesh = FurniturePropsBuilderScript.get_newspaper_mesh()
	news_bed.material_override = mat_props
	news_bed.position = Vector3(0.15, 0.45, 0.3)
	news_bed.rotation_degrees.y = 15.0
	_root.add_child(news_bed)

	# 4. Mesa de noche de roble con cajón semiabierto y consumibles encima
	var nightstand: NightstandOakScript = NightstandOakScript.new()
	nightstand.position = Vector3(-1.20, 0.0, -0.9)
	nightstand.drawer_open_ratio = 0.50
	nightstand.storage.add_item(FurnitureStorageContainerScript.create_milk(0.85, 1.0))
	nightstand.storage.add_item(FurnitureStorageContainerScript.create_cereal(0.90, 1.0))
	_root.add_child(nightstand)

	# Taza y pila de libros sobre la mesita
	var mug_ns := MeshInstance3D.new()
	mug_ns.mesh = FurniturePropsBuilderScript.get_mug_mesh()
	mug_ns.material_override = mat_props
	mug_ns.position = Vector3(-1.10, 0.71, -0.85)
	_root.add_child(mug_ns)

	var books_ns := MeshInstance3D.new()
	books_ns.mesh = FurniturePropsBuilderScript.get_book_stack_mesh()
	books_ns.material_override = mat_props
	books_ns.position = Vector3(-1.25, 0.71, -0.95)
	_root.add_child(books_ns)

	# 5. Librero alto (inicia vacío, con 4 libros modulares insertados)
	var bookcase: BookcaseTallScript = BookcaseTallScript.new()
	bookcase.position = Vector3(-2.25, 0.0, -1.2)
	bookcase.insert_book(0, "bible")
	bookcase.insert_book(1, "atlas")
	bookcase.insert_book(4, "recipes")
	bookcase.insert_book(8, "novel")
	_root.add_child(bookcase)

	# 6. Ropero alto de roble (puertas persianas entreabiertas)
	var wardrobe: WardrobeOakScript = WardrobeOakScript.new()
	wardrobe.position = Vector3(1.50, 0.0, -1.0)
	wardrobe.doors_open_ratio = 0.40 # Entreabiertas para lucir las persianas y el interior
	wardrobe.storage.add_item(FurnitureStorageContainerScript.create_book("novel", "Diario Personal"))
	wardrobe.storage.add_item(FurnitureStorageContainerScript.create_newspaper("Edición Especial"))
	_root.add_child(wardrobe)

	# 7. Mueble fregadero blanco con grifería
	var sink: SinkUnitWhiteScript = SinkUnitWhiteScript.new()
	sink.position = Vector3(2.95, 0.0, -0.7)
	sink.rotation_degrees.y = -18.0
	sink.doors_open_ratio = 0.35 # Entreabiertas
	sink.storage.add_item(FurnitureStorageContainerScript.create_soup(1.0, 1.0))
	_root.add_child(sink)

	# Consumibles sobre el lateral del mesón del fregadero
	var soup_sink := MeshInstance3D.new()
	soup_sink.mesh = FurniturePropsBuilderScript.get_soup_can_mesh()
	soup_sink.material_override = mat_props
	soup_sink.position = Vector3(2.65, 0.88, -0.60)
	_root.add_child(soup_sink)

	var beer_sink := MeshInstance3D.new()
	beer_sink.mesh = FurniturePropsBuilderScript.get_beer_can_mesh()
	beer_sink.material_override = mat_props
	beer_sink.position = Vector3(2.72, 0.88, -0.48)
	_root.add_child(beer_sink)

	var plate_sink := MeshInstance3D.new()
	plate_sink.mesh = FurniturePropsBuilderScript.get_plate_mesh()
	plate_sink.material_override = mat_props
	plate_sink.position = Vector3(3.25, 0.88, -0.80)
	_root.add_child(plate_sink)

	# Cámara
	_cam = Camera3D.new()
	_cam.current = true
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Vista general del dormitorio y cocina
	if _frames == 10:
		_cam.position = Vector3(0.6, 2.2, 3.8)
		_cam.look_at_from_position(_cam.position, Vector3(0.2, 0.85, -0.5))

	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/new_furniture_room_lineup.png")
				print("✓ Captura guardada: new_furniture_room_lineup.png")

	# Frame 20: Primer plano directo del librero y sus libros modulares
	elif _frames == 20:
		_cam.position = Vector3(-2.25, 1.1, 0.3)
		_cam.look_at_from_position(_cam.position, Vector3(-2.25, 0.85, -1.2))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/new_furniture_bookcase_closeup.png")
				print("✓ Captura guardada: new_furniture_bookcase_closeup.png")

	# Frame 30: Primer plano de la taza, pila de libros y mesita de noche
	elif _frames == 30:
		_cam.position = Vector3(-1.15, 1.0, -0.3)
		_cam.look_at_from_position(_cam.position, Vector3(-1.15, 0.70, -0.9))

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/new_furniture_nightstand_closeup.png")
				print("✓ Captura guardada: new_furniture_nightstand_closeup.png")

	# Frame 40: Primer plano del fregadero (verificando exactamente 2 puertas y sin duplicados)
	elif _frames == 40:
		_cam.position = Vector3(2.8, 1.4, 0.4)
		_cam.look_at_from_position(_cam.position, Vector3(2.95, 0.65, -0.7))

	elif _frames == 45:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/new_furniture_sink_props_closeup.png")
				print("✓ Captura guardada: new_furniture_sink_props_closeup.png")

	elif _frames >= 50:
		print("✓ Todas las capturas renderizadas exitosamente.")
		quit(0)

	return false
