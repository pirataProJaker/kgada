extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const Furniture2SeatingRecipesScript = preload("res://world/object_engine/recipes/furniture2_seating_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.24, 0.26, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 0.95
	env_node.environment = env
	root_node.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 42.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	root_node.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -55.0, 0.0)
	fill.light_energy = 0.55
	root_node.add_child(fill)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.38, 0.40, 0.43)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# Sillón Individual 1.0m - Moderno Verde Olivo (Row 2, Col 3)
	var t1 := Transform3D(Basis(Vector3.UP, deg_to_rad(-22.0)), Vector3(-0.7, 0.0, 0.0))
	Furniture2SeatingRecipesScript.ModularSofaRecipe.build(builder, t1, {
		"width": 1.0,
		"fabric": "modern_04_olive",
		"wood_finish": "roble_claro"
	})

	# Loveseat 1.5m - Vintage Pana Naranja Óxido (Row 0, Col 2)
	var t2 := Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), Vector3(0.9, 0.0, 0.0))
	Furniture2SeatingRecipesScript.ModularSofaRecipe.build(builder, t2, {
		"width": 1.5,
		"fabric": "vintage_03_corduroy_orange",
		"wood_finish": "nogal_oscuro"
	})

	engine.commit()

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1024, 640)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_sub_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 1.10, 2.5)
	_camera.look_at_from_position(_camera.position, Vector3(0.1, 0.46, 0.0), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/modular_duo_closeup.png"
			img.save_png(save_path)
			print("✓ Render duo guardado en: ", save_path)
		quit(0)
	return false
