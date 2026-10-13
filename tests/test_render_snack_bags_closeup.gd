extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const SnackBagsRecipesScript = preload("res://world/object_engine/recipes/snack_bags_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	print("--- Setting up Snack Bags Closeup Render ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.82, 0.86)
	env.ambient_light_energy = 0.95
	env_node.environment = env
	root_node.add_child(env_node)

	# Main key light
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, -50.0, 0.0)
	fill.light_energy = 0.65
	root_node.add_child(fill)

	# Countertop / Table
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.30, 0.35)
	floor_mat.roughness = 0.65
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Object Engine
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# 5 Bolsas de botana destacadas en ángulo 3/4 para apreciar Frente y Tira Lateral:
	# 1. Tostik's Original (Rojo)
	# 2. Crujitos Queso (Amarillo)
	# 3. FuegoRix Extra Picante (Negro/Fuego)
	# 4. Papasol Limón y Sal (Verde Lima)
	# 5. Gomitas Frutas (Rosa Mexicano)
	var featured := [
		{ "snack": "tostiks",  "pos": Vector3(-0.30, 0.0, -0.04), "rot_y": -22.0 },
		{ "snack": "crujitos", "pos": Vector3(-0.15, 0.0,  0.01), "rot_y": -16.0 },
		{ "snack": "fuegorix", "pos": Vector3( 0.00, 0.0,  0.04), "rot_y": -12.0 },
		{ "snack": "papasol",  "pos": Vector3( 0.15, 0.0,  0.01), "rot_y": -10.0 },
		{ "snack": "gomitas",  "pos": Vector3( 0.30, 0.0, -0.04), "rot_y": -8.0 }
	]

	for item in featured:
		var basis := Basis(Vector3.UP, deg_to_rad(item["rot_y"]))
		var t := Transform3D(basis, item["pos"])
		SnackBagsRecipesScript.SnackBagRecipe.build(builder, t, {
			"snack": item["snack"],
			"collision": true
		})

	engine.commit()

	print("Total piezas construidas: ", builder.get_total_instances())
	var inst_map = builder.get_instances_map()
	for k in inst_map:
		print(" - Primitiva '", k, "': ", (inst_map[k] as Array).size(), " instancias (1 Draw Call)")

	# SubViewport for rendering closeup
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1280, 720)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_sub_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 0.14, 0.44)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.10, 0.0), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/snack_bags_closeup.png"
			img.save_png(save_path)
			print("✓ Render closeup de bolsas de papitas guardado en: ", save_path)
		quit(0)
	return false
