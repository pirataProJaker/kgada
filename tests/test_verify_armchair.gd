extends SceneTree

const ArmchairLeatherScript = preload("res://world/furniture/armchair_leather.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D
var _armchair: Node3D

func _init() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.49, 0.52) # Same studio grey as Image 2
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.70)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	root_node.add_child(env_node)

	# Directional light matching Image 2 (from top-left front)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light (soft from right)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -60.0, 0.0)
	fill.light_energy = 0.5
	root_node.add_child(fill)

	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.40, 0.44, 0.47)
	floor_mat.roughness = 0.8
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Armchair instance
	_armchair = ArmchairLeatherScript.new()
	_armchair.position = Vector3(0.0, 0.0, 0.0)
	# Turn slightly so we see front 3/4 view just like Image 2
	_armchair.rotation_degrees = Vector3(0.0, -22.0, 0.0)
	root_node.add_child(_armchair)

	# SubViewport for rendering
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(768, 768)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_sub_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 0.58, 1.45)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.52, 0.0), Vector3.UP)

	print("✓ Configuración de verificación de sillón lista. Renderizando...")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 6:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/verify_armchair_render.png"
			img.save_png(save_path)
			print("✓ Render capturado guardado en: ", save_path)
		else:
			print("ERROR: Texture image is null or empty.")
		quit(0)
	return false
