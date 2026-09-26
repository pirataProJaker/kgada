extends SceneTree

var _frames: int = 0
var _scene: Node3D

func _init() -> void:
	_scene = Node3D.new()
	_scene.name = "PinesShowcase"
	root.add_child(_scene)
	
	# Entorno y luz
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.24, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.70, 0.75)
	env.ambient_light_energy = 1.0
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_scene.add_child(world_env)
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_color = Color(1.0, 0.96, 0.88)
	light.light_energy = 1.2
	light.shadow_enabled = true
	_scene.add_child(light)
	
	# Suelo de referencia
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 40)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.22, 0.16)
	floor_mat.roughness = 0.9
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	_scene.add_child(floor_inst)
	
	# Cargar FBX StarkCrafts de la raíz
	var fbx_path := "res://PSX_Forest_AssetCollection_byStarkCrafts.fbx"
	var fbx_scene: PackedScene = load(fbx_path)
	var fbx_inst: Node = fbx_scene.instantiate()
	
	# Extraer árboles y acomodarlos en fila
	var tree_names = ["PSX_Tree1", "PSX_Tree4", "PSX_Tree3", "PSX_Tree2"]
	var x_pos = -15.0
	for t_name in tree_names:
		var node = fbx_inst.get_node_or_null(t_name)
		if node:
			var clone = node.duplicate()
			_scene.add_child(clone)
			clone.position = Vector3(x_pos, 0.0, 0.0)
			clone.rotation_degrees = node.rotation_degrees
			clone.scale = node.scale
			
			var label = Label3D.new()
			label.text = "%s\n(%d tris)" % [t_name, _get_tri_count(clone)]
			label.font_size = 28
			label.outline_size = 8
			label.position = Vector3(x_pos, 16.0, 0.0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_scene.add_child(label)
			
			x_pos += 10.0
			
	# Piña de pino en pedestal
	var cone_node = fbx_inst.get_node_or_null("PSX_PineConre")
	if cone_node:
		var clone_cone = cone_node.duplicate()
		_scene.add_child(clone_cone)
		clone_cone.position = Vector3(25.0, 2.0, 0.0)
		clone_cone.rotation_degrees = cone_node.rotation_degrees
		clone_cone.scale = cone_node.scale * 10.0 # Aumentar escala para verla en detalle
		var label = Label3D.new()
		label.text = "PSX_PineCone (x10)\n(6 tris)"
		label.font_size = 28
		label.outline_size = 8
		label.position = Vector3(25.0, 6.0, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_scene.add_child(label)
			
	fbx_inst.free()
	
	# Cámara más centrada y cercana
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 10.0, 28.0)
	cam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	cam.fov = 55.0
	cam.current = true
	_scene.add_child(cam)
	
	print("[CaptureFBXPines] Escena lista, esperando frames...")

func _get_tri_count(mi: MeshInstance3D) -> int:
	var m = mi.mesh
	if not m: return 0
	var tris = 0
	for s in range(m.get_surface_count()):
		var arr = m.surface_get_arrays(s)
		if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
			tris += arr[Mesh.ARRAY_INDEX].size() / 3
		elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			tris += arr[Mesh.ARRAY_VERTEX].size() / 3
	return tris

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		var vp = root.get_viewport()
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				var path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/fbx_pines_inspection.png"
				img.save_png(path)
				img.save_png("res://tests/fbx_pines_inspection.png")
				print("✓ Captura guardada en: ", path)
		quit(0)
		return true
	return false
