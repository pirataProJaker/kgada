extends SceneTree

const PSXPine = preload("res://world/vegetation/trees/psx_pine.gd")

var _frames: int = 0
var _scene: Node3D
var _cam: Camera3D
var _tree_lod0: MeshInstance3D
var _tree_lod1: MeshInstance3D

func _init() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	
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
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_color = Color(1.0, 0.96, 0.90)
	light.light_energy = 1.3
	light.shadow_enabled = true
	_scene.add_child(light)
	
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(100, 100)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.24, 0.16)
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	_scene.add_child(floor_inst)
	
	# LOD 0 a la izquierda
	_tree_lod0 = MeshInstance3D.new()
	_tree_lod0.mesh = PSXPine.get_lod0_mesh()
	_tree_lod0.position = Vector3(-8.0, 0.0, 0.0)
	_scene.add_child(_tree_lod0)
	
	var l0 = Label3D.new()
	l0.text = "LOD 0 (Normal)\n30 Tris (Cruz 3D)"
	l0.font_size = 32
	l0.outline_size = 8
	l0.position = Vector3(-8.0, 36.0, 0.0)
	l0.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_scene.add_child(l0)
	
	# LOD 1 a la derecha
	_tree_lod1 = MeshInstance3D.new()
	_tree_lod1.mesh = PSXPine.get_lod1_mesh()
	_tree_lod1.position = Vector3(8.0, 0.0, 0.0)
	_scene.add_child(_tree_lod1)
	
	var l1 = Label3D.new()
	l1.text = "LOD 1 (Billboard)\n2 Tris (1 Tronco + 1 Copa)"
	l1.font_size = 32
	l1.outline_size = 8
	l1.position = Vector3(8.0, 36.0, 0.0)
	l1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_scene.add_child(l1)
	
	_cam = Camera3D.new()
	_cam.current = true
	_cam.position = Vector3(0.0, 16.0, 48.0)
	_cam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	_cam.fov = 50.0
	_scene.add_child(_cam)
	print("Turntable test escena lista.")

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	
	# 4 tomas de rotación: 0°, 60°, 120°, 180°
	if _frames == 5:
		_tree_lod0.rotation_degrees = Vector3(0, 0, 0)
	elif _frames == 10:
		if vp:
			var img = vp.get_texture().get_image()
			img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_turntable_0deg.png")
			print("✓ 0 deg guardada")
			
	elif _frames == 15:
		_tree_lod0.rotation_degrees = Vector3(0, 60, 0)
	elif _frames == 20:
		if vp:
			var img = vp.get_texture().get_image()
			img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_turntable_60deg.png")
			print("✓ 60 deg guardada")
			
	elif _frames == 25:
		_tree_lod0.rotation_degrees = Vector3(0, 120, 0)
	elif _frames == 30:
		if vp:
			var img = vp.get_texture().get_image()
			img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_turntable_120deg.png")
			print("✓ 120 deg guardada")
			
	elif _frames == 35:
		_tree_lod0.rotation_degrees = Vector3(0, 180, 0)
	elif _frames == 40:
		if vp:
			var img = vp.get_texture().get_image()
			img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_turntable_180deg.png")
			print("✓ 180 deg guardada")
		quit(0)
		return true
		
	return false
