extends SceneTree

var _frames: int = 0
var _scene: Node3D
var _cam: Camera3D

func _init() -> void:
	_scene = Node3D.new()
	_scene.name = "PineComparisonScene"
	root.add_child(_scene)
	
	# Iluminación y entorno
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.42, 0.50)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.75, 0.80)
	env.ambient_light_energy = 1.0
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_scene.add_child(world_env)
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 35, 0)
	light.light_color = Color(1.0, 0.96, 0.90)
	light.light_energy = 1.3
	light.shadow_enabled = true
	_scene.add_child(light)
	
	# Suelo
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(250, 250)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.24, 0.16)
	floor_mat.roughness = 0.95
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	_scene.add_child(floor_inst)
	
	# Extraer mallas
	var fbx_scene: PackedScene = load("res://PSX_Forest_AssetCollection_byStarkCrafts.fbx")
	var fbx = fbx_scene.instantiate()
	var tree4: MeshInstance3D = fbx.get_node("PSX_Tree4") as MeshInstance3D
	var orig_mesh: Mesh = tree4.mesh
	var node_t: Transform3D = tree4.transform
	var center_offset = Vector3(tree4.position.x, 0.0, tree4.position.z)
	var local_t = Transform3D(node_t.basis, node_t.origin - center_offset)
	
	# 1. Malla LOD 0 normalizada
	var lod0_mesh = ArrayMesh.new()
	for s in range(orig_mesh.get_surface_count()):
		var arr = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var new_verts = PackedVector3Array()
		for v in verts:
			new_verts.append(local_t * v)
		arr[Mesh.ARRAY_VERTEX] = new_verts
		lod0_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		lod0_mesh.surface_set_material(s, orig_mesh.surface_get_material(s))
		
	# 2. Materiales para LOD 1 con BILLBOARD_FIXED_Y
	var orig_crown_mat: StandardMaterial3D = orig_mesh.surface_get_material(0)
	var orig_trunk_mat: StandardMaterial3D = orig_mesh.surface_get_material(1)
	
	var lod1_crown_mat = orig_crown_mat.duplicate() as StandardMaterial3D
	lod1_crown_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	lod1_crown_mat.billboard_keep_scale = true
	lod1_crown_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Suave ajuste de albedo para compensar el sombreado intrínseco de los planos cruzados de LOD 0
	lod1_crown_mat.albedo_color = Color(0.82, 0.86, 0.80)
	
	var lod1_trunk_mat = orig_trunk_mat.duplicate() as StandardMaterial3D
	lod1_trunk_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	lod1_trunk_mat.billboard_keep_scale = true
	lod1_trunk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lod1_trunk_mat.albedo_color = Color(0.88, 0.85, 0.85)
	
	# 3. Malla LOD 1 (Exactamente 2 triángulos)
	var lod1_mesh = ArrayMesh.new()
	
	# Superficie 0: Tronco (1 triángulo) - Se dibuja primero o con Z ligeramente atrás
	var trunk_st = SurfaceTool.new()
	trunk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t_w = 1.65 * 0.50
	var t_y_base = -0.26
	var t_y_top = 28.50
	
	trunk_st.set_uv(Vector2(0.0, 4.0)); trunk_st.add_vertex(Vector3(-t_w, t_y_base, -0.05))
	trunk_st.set_uv(Vector2(1.0, 4.0)); trunk_st.add_vertex(Vector3(t_w, t_y_base, -0.05))
	trunk_st.set_uv(Vector2(0.5, 0.0)); trunk_st.add_vertex(Vector3(0.0, t_y_top, -0.05))
	trunk_st.generate_normals()
	lod1_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_st.commit_to_arrays())
	lod1_mesh.surface_set_material(0, lod1_trunk_mat)
	
	# Superficie 1: Copa (1 triángulo) - Z ligeramente al frente para cubrir el tronco
	var crown_st = SurfaceTool.new()
	crown_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c_w = 23.5 * 0.50
	var c_y_base = 12.80
	var c_y_top = 34.20
	
	# Top: (0,0) es la punta del pino en la textura
	# Bottom-Left: (0,1) es el follaje izquierdo
	# Bottom-Right: (1,0) es el follaje derecho
	# El eje central x=0 tiene U=V, alineado exactamente con la rama central
	crown_st.set_uv(Vector2(0.0, 1.0)); crown_st.add_vertex(Vector3(-c_w, c_y_base, 0.05))
	crown_st.set_uv(Vector2(1.0, 0.0)); crown_st.add_vertex(Vector3(c_w, c_y_base, 0.05))
	crown_st.set_uv(Vector2(0.0, 0.0)); crown_st.add_vertex(Vector3(0.0, c_y_top, 0.05))
	crown_st.generate_normals()
	lod1_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown_st.commit_to_arrays())
	lod1_mesh.surface_set_material(1, lod1_crown_mat)
	
	# Instanciar lado a lado:
	# Árbol LOD 0 a la izquierda
	var inst_lod0 = MeshInstance3D.new()
	inst_lod0.name = "Pino_LOD0_30tris"
	inst_lod0.mesh = lod0_mesh
	inst_lod0.position = Vector3(-12.0, 0.0, 0.0)
	_scene.add_child(inst_lod0)
	
	var label0 = Label3D.new()
	label0.text = "LOD 0 (Original 3D)\n30 Triángulos"
	label0.font_size = 40
	label0.outline_size = 10
	label0.position = Vector3(-12.0, 38.0, 0.0)
	label0.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_scene.add_child(label0)
	
	# Árbol LOD 1 a la derecha
	var inst_lod1 = MeshInstance3D.new()
	inst_lod1.name = "Pino_LOD1_2tris"
	inst_lod1.mesh = lod1_mesh
	inst_lod1.position = Vector3(12.0, 0.0, 0.0)
	_scene.add_child(inst_lod1)
	
	var label1 = Label3D.new()
	label1.text = "LOD 1 (Distant Billboard)\n2 Triángulos (1 Copa + 1 Tronco)"
	label1.font_size = 40
	label1.outline_size = 10
	label1.position = Vector3(12.0, 38.0, 0.0)
	label1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_scene.add_child(label1)
	
	# Cámara
	_cam = Camera3D.new()
	_cam.current = true
	_scene.add_child(_cam)
	
	fbx.free()
	print("[PineComparison] Escena de comparación inicializada.")

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	
	# Captura 1: Distancia media (45 metros)
	if _frames == 10:
		_cam.position = Vector3(0.0, 16.0, 45.0)
		_cam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
		_cam.fov = 55.0
	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_lod_comparison_45m.png")
				img.save_png("res://tests/pine_lod_comparison_45m.png")
				print("✓ Captura a 45m guardada.")
				
	# Captura 2: Distancia de transición (100 metros) - Vista con zoom para auditoría visual lado a lado
	elif _frames == 25:
		_cam.position = Vector3(0.0, 18.0, 100.0)
		_cam.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
		_cam.fov = 30.0 # Zoom óptico
	elif _frames == 30:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_lod_comparison_100m.png")
				img.save_png("res://tests/pine_lod_comparison_100m.png")
				print("✓ Captura a 100m guardada.")
				
	# Captura 3: Distancia de transición (100 metros) - Vista real del jugador en el juego (FOV 65)
	elif _frames == 40:
		_cam.position = Vector3(0.0, 16.0, 100.0)
		_cam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
		_cam.fov = 65.0 # FOV normal de juego
	elif _frames == 45:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_lod_comparison_100m_player_view.png")
				img.save_png("res://tests/pine_lod_comparison_100m_player_view.png")
				print("✓ Captura a 100m (Player View FOV 65) guardada.")
		quit(0)
		return true
		
	return false
