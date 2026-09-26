extends SceneTree

var _frame: int = 0
var _cam_ref: Camera3D

func _init() -> void:
	var root_node := Node3D.new()
	root_node.name = "RoadShowcaseRoot"
	root.add_child(root_node)

	# 1. Iluminación y Cielo
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.48, 0.65, 0.85)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.65, 0.70, 0.78)
	env_res.ambient_light_energy = 0.85
	env.environment = env_res
	root_node.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 50, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	root_node.add_child(sun)

	# 2. Terreno base de césped
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(250, 250)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.42, 0.22)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = floor_mat
	root_node.add_child(floor_mi)

	# 3. Instanciar Motor de Carreteras (Rust GDExtension)
	var engine = ClassDB.instantiate("RoadEngine")
	root_node.add_child(engine)

	# Nodos de la red
	var n_center: int = engine.add_node(Vector3(0, 0, 0))
	var n_north: int = engine.add_node(Vector3(0, 0, -70))
	var n_south: int = engine.add_node(Vector3(0, 0, 70))
	var n_west: int = engine.add_node(Vector3(-60, 0, 0))
	var n_east: int = engine.add_node(Vector3(60, 0, 0))

	# Bulevar dividido con camellón central arbolado Norte-Sur
	var blvd_params = {
		"lanes": 2,
		"lane_width": 3.75,
		"median_width": 6.0,
		"median_style": "trees",
		"tree_spacing": 14.0,
		"sidewalk_width": 2.5
	}
	engine.add_road(n_north, n_center, "divided_boulevard", blvd_params)
	engine.add_road(n_center, n_south, "divided_boulevard", blvd_params)

	# Calle residencial cruzando Este-Oeste
	var res_params = {
		"lane_width": 3.25,
		"sidewalk_width": 2.0
	}
	engine.add_road(n_west, n_center, "residential_2lane", res_params)
	engine.add_road(n_center, n_east, "residential_2lane", res_params)

	# Resolver red en Rust
	engine.solve()

	# 4. Materiales con textura de ruido de píxel (asfalto, banqueta, bordillo, marcas)
	ProceduralRoadMaterials.clear_cache()
	var mat_asphalt: Material = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_ASPHALT)
	var mat_junction: Material = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_ASPHALT) # Mismo asfalto continuo
	var mat_sidewalk: Material = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_SIDEWALK)
	var mat_curb: Material = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_CURB)
	var mat_median: Material = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_MEDIAN)
	var mat_paint: Material = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_WHITE_LINE)

	# 5. Configurar los MultiMeshInstance3D con hardware GPU instancing
	var mm_asphalt: MultiMesh = engine.get_asphalt_multimesh()
	if mm_asphalt and mm_asphalt.instance_count > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm_asphalt
		mmi.material_override = mat_asphalt
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root_node.add_child(mmi)

	var mm_junction: MultiMesh = engine.get_junction_multimesh()
	if mm_junction and mm_junction.instance_count > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm_junction
		mmi.material_override = mat_junction
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root_node.add_child(mmi)

	var mm_sidewalk: MultiMesh = engine.get_sidewalk_multimesh()
	if mm_sidewalk and mm_sidewalk.instance_count > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm_sidewalk
		mmi.material_override = mat_sidewalk
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root_node.add_child(mmi)

	var mm_curb: MultiMesh = engine.get_curb_multimesh()
	if mm_curb and mm_curb.instance_count > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm_curb
		mmi.material_override = mat_curb
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root_node.add_child(mmi)

	var mm_median: MultiMesh = engine.get_median_multimesh()
	if mm_median and mm_median.instance_count > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm_median
		mmi.material_override = mat_median
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root_node.add_child(mmi)

	var mm_paint: MultiMesh = engine.get_paint_multimesh()
	if mm_paint and mm_paint.instance_count > 0:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm_paint
		mmi.material_override = mat_paint
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root_node.add_child(mmi)

	# 6. Sockets de árboles en camellones: instanciar ProceduralTree
	var tree_sockets: Array = engine.get_tree_socket_transforms()
	print("[RoadEngine Showcase] Instanciando %d arboles en los sockets del camellon..." % tree_sockets.size())
	for i in range(tree_sockets.size()):
		var t_trans: Transform3D = tree_sockets[i]
		var tree := ProceduralTree.new()
		tree.profile_id = "classic_oak" if (i % 2 == 0) else "alnus_acuminata"
		tree.tree_seed = 1000 + i * 777
		tree.cast_shadows = true
		root_node.add_child(tree)
		tree.global_transform = t_trans

	# 7. Cámara aérea elevada mostrando la intersección completa
	var cam := Camera3D.new()
	root_node.add_child(cam)
	var cam_pos := Vector3(32, 28, 36)
	var cam_target := Vector3(0, 0.25, 0)
	cam.look_at_from_position(cam_pos, cam_target, Vector3.UP)
	cam.fov = 42.0

	process_frame.connect(_on_frame)
	_cam_ref = cam

func _on_frame() -> void:
	_frame += 1
	if _frame == 20:
		var img := root.get_viewport().get_texture().get_image()
		if img != null:
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/road_engine_preview.png"
			img.save_png(save_path)
			print("[SUCCESS] Captura aérea guardada en: " + save_path)
		
		# Perspectiva peatonal situada directamente sobre la banqueta amplia y el asfalto negro
		_cam_ref.look_at_from_position(Vector3(18.0, 2.2, 7.5), Vector3(14.0, 0.33, 4.45), Vector3.UP)
		_cam_ref.fov = 55.0

	elif _frame == 35:
		var img := root.get_viewport().get_texture().get_image()
		if img != null:
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/road_engine_closeup.png"
			img.save_png(save_path)
			print("[SUCCESS] Captura de banqueta y calle guardada en: " + save_path)

		# Cambiar cámara a ras de banqueta / asfalto (primer plano de detalle de texturas)
		_cam_ref.look_at_from_position(Vector3(6.5, 1.4, 6.5), Vector3(2.0, 0.20, 3.5), Vector3.UP)
		_cam_ref.fov = 44.0

	elif _frame == 48:
		var img := root.get_viewport().get_texture().get_image()
		if img != null:
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/road_engine_ground.png"
			img.save_png(save_path)
			print("[SUCCESS] Captura rasante guardada en: " + save_path)
		quit(0)


