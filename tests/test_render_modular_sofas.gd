extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const Furniture2SeatingRecipesScript = preload("res://world/object_engine/recipes/furniture2_seating_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	print("--- Setting up Modular Sofas Showcase Render ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.22, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.72, 0.75)
	env.ambient_light_energy = 0.9
	env_node.environment = env
	root_node.add_child(env_node)

	# Main light (warm key light)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light (cool soft fill)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, -50.0, 0.0)
	fill.light_energy = 0.5
	root_node.add_child(fill)

	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.38, 0.40)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Object Engine
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# 1. Sofá Grande (2.0 m) - 3 Plazas - Tela Vintage Jacquard Oro y Café (Fila 0, Col 0)
	var t1 := Transform3D(Basis(Vector3.UP, deg_to_rad(14.0)), Vector3(-2.1, 0.0, 0.1))
	Furniture2SeatingRecipesScript.ModularSofaRecipe.build(builder, t1, {
		"width": 2.0,
		"fabric": "vintage_01_jacquard_gold",
		"wood_finish": "nogal_oscuro"
	})

	# 2. Sofá Mediano (1.5 m) - 2 Plazas - Tela Vintage Pana Naranja Óxido (Fila 0, Col 2)
	var t2 := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.2))
	Furniture2SeatingRecipesScript.ModularSofaRecipe.build(builder, t2, {
		"width": 1.5,
		"fabric": "vintage_03_corduroy_orange",
		"wood_finish": "nogal_oscuro"
	})

	# 3. Sillón Individual (1.0 m) - 1 Plaza - Tela Moderna Bouclé Avena (Fila 2, Col 1)
	var t3 := Transform3D(Basis(Vector3.UP, deg_to_rad(-18.0)), Vector3(1.85, 0.0, 0.1))
	Furniture2SeatingRecipesScript.ModularSofaRecipe.build(builder, t3, {
		"width": 1.0,
		"fabric": "modern_02_boucle_oat",
		"wood_finish": "nogal_oscuro"
	})

	# Comprometer al ObjectEngine
	engine.commit()

	print("Total piezas construidas: ", builder.get_total_instances())
	var inst_map = builder.get_instances_map()
	for k in inst_map:
		print(" - Primitiva '", k, "': ", (inst_map[k] as Array).size(), " instancias (1 Draw Call)")

	# SubViewport for rendering
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1280, 720)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_sub_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 1.45, 3.8)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.45, 0.0), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/modular_sofas_showcase.png"
			img.save_png(save_path)
			print("✓ Render guardado exitosamente en: ", save_path)
		else:
			print("ERROR: Texture image is null or empty.")
		quit(0)
	return false
