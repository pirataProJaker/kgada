extends SceneTree

const PSXPine = preload("res://world/vegetation/trees/psx_pine.gd")

var _frames: int = 0
var _scene: Node3D
var _cam: Camera3D

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
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	_scene.add_child(floor_inst)
	
	# Muestra de árboles en fila rotados a diferentes ángulos: 0, 45, 90, 135, 180
	var angles = [0.0, 45.0, 90.0, 135.0, 180.0]
	for i in range(angles.size()):
		var ang = angles[i]
		var x = (i - 2) * 16.0
		
		# LOD 0
		var m0 = MeshInstance3D.new()
		m0.mesh = PSXPine.get_lod0_mesh()
		m0.position = Vector3(x, 0.0, -10.0)
		m0.rotation_degrees = Vector3(0.0, ang, 0.0)
		_scene.add_child(m0)
		
		var l0 = Label3D.new()
		l0.text = "LOD 0\nRot: %d°" % int(ang)
		l0.font_size = 32
		l0.outline_size = 8
		l0.position = Vector3(x, 38.0, -10.0)
		l0.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_scene.add_child(l0)
		
		# LOD 1
		var m1 = MeshInstance3D.new()
		m1.mesh = PSXPine.get_lod1_mesh()
		m1.position = Vector3(x, 0.0, 15.0)
		# En LOD 1, el billboard se encarga de rotar
		_scene.add_child(m1)
		
		var l1 = Label3D.new()
		l1.text = "LOD 1 (Billboard)\n(2 Tris)"
		l1.font_size = 32
		l1.outline_size = 8
		l1.position = Vector3(x, 38.0, 15.0)
		l1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_scene.add_child(l1)
		
	_cam = Camera3D.new()
	_cam.current = true
	_cam.position = Vector3(0.0, 22.0, 75.0)
	_cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	_cam.fov = 55.0
	_scene.add_child(_cam)
	print("Escena de ángulos inicializada.")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		var vp = root.get_viewport()
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/pine_angles_test.png")
				img.save_png("res://tests/pine_angles_test.png")
				print("✓ Captura pine_angles_test.png guardada.")
		quit(0)
		return true
	return false
