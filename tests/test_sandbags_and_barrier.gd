extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const SandbagsRecipesScript = preload("res://world/object_engine/recipes/sandbags_recipes.gd")
const BarrierGateRecipeScript = preload("res://world/object_engine/recipes/barrier_gate_recipe.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	print("--- Setting up Sandbags & Barrier Gate Showcase ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World Environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.92)
	env.ambient_light_energy = 0.90
	env_node.environment = env
	root_node.add_child(env_node)

	# Sol principal
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 42.0, 0.0)
	sun.light_energy = 1.50
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Luz de relleno
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -135.0, 0.0)
	fill.light_energy = 0.65
	root_node.add_child(fill)

	# Suelo (asfalto / explanada de control militar)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.24, 0.25, 0.28)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Object Engine (+0 Draw Calls)
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# =========================================================================
	# 1. BARRICADA MILITAR DE COSTALES DE ARENA (Sandbag Barricade)
	# =========================================================================
	# Barricada de trinchera de 4 costales de largo, 3 niveles de alto, doble hilera
	var barricade_t := Transform3D(Basis.IDENTITY, Vector3(-1.4, 0.0, -0.3))
	SandbagsRecipesScript.SandbagBarricadeRecipe.build(builder, barricade_t, {
		"length_bags": 4,
		"height_tiers": 3,
		"double_row": true
	})

	# 3 costales individuales en primer plano para apreciar las texturas recortadas de arpillera:
	# Costal 1: Limpio (variación 0)
	var sack1_t := Transform3D(Basis(Vector3.UP, deg_to_rad(15.0)), Vector3(-1.8, 0.0, 0.9))
	SandbagsRecipesScript.SandbagRecipe.build(builder, sack1_t, { "variation": 0 })

	# Costal 2: Desgastado / rasgado (variación 10)
	var sack2_t := Transform3D(Basis(Vector3.UP, deg_to_rad(-18.0)), Vector3(-1.1, 0.0, 0.95))
	SandbagsRecipesScript.SandbagRecipe.build(builder, sack2_t, { "variation": 10 })

	# Costal 3: Remendado con parche (variación 17)
	var sack3_t := Transform3D(Basis(Vector3.UP, deg_to_rad(10.0)), Vector3(-0.4, 0.0, 0.85))
	SandbagsRecipesScript.SandbagRecipe.build(builder, sack3_t, { "variation": 17 })

	# =========================================================================
	# 2. PLUMA DE ACCESO VEHICULAR CERRADA (Barrier Gate - Closed)
	# =========================================================================
	# Gabinete naranja vial, barra de 3.0m cerrada horizontalmente con franjas rojas/blancas
	var gate_closed_t := Transform3D(Basis.IDENTITY, Vector3(0.5, 0.0, 0.4))
	BarrierGateRecipeScript.build(builder, gate_closed_t, {
		"arm_length": 3.0,
		"is_open": false,
		"color": "orange",
		"stripes": "red_white",
		"catch_post": true
	})

	# =========================================================================
	# 3. PLUMA DE ACCESO VEHICULAR ABIERTA (Barrier Gate - Open)
	# =========================================================================
	# Gabinete blanco, barra levantada a 85°, franjas amarillas/negras hazard
	var gate_open_t := Transform3D(Basis.IDENTITY, Vector3(0.5, 0.0, -1.2))
	BarrierGateRecipeScript.build(builder, gate_open_t, {
		"arm_length": 2.8,
		"is_open": true,
		"open_angle": 85.0,
		"color": "white",
		"stripes": "yellow_black",
		"catch_post": true
	})

	engine.commit()

	print("✓ ObjectEngine commit completado:")
	var inst_map = builder.get_instances_map()
	for k in inst_map:
		print("  - Primitiva '", k, "': ", (inst_map[k] as Array).size(), " instancias (1 Draw Call)")

	# Configurar Cámara
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1280, 720)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 36.0
	_sub_viewport.add_child(_camera)
	_camera.position = Vector3(0.1, 2.0, 4.6)
	_camera.look_at_from_position(_camera.position, Vector3(0.1, 0.8, 0.0), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/sandbags_and_barrier_showcase.png"
			img.save_png(save_path)
			print("✓ Render de sacos y plumas guardado en: ", save_path)
		quit(0)
	return false
