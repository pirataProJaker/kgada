extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const CartonDrinksRecipesScript = preload("res://world/object_engine/recipes/carton_drinks_recipes.gd")
const CartonDrinks237mlRecipesScript = preload("res://world/object_engine/recipes/carton_drinks_237ml_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.88)
	env.ambient_light_energy = 0.95
	env_node.environment = env
	root_node.add_child(env_node)

	# Main light (warm key light)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28.0, 42.0, 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light (cool soft fill)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12.0, -48.0, 0.0)
	fill.light_energy = 0.65
	root_node.add_child(fill)

	# Floor / Countertop
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.38, 0.42)
	floor_mat.roughness = 0.70
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Object Engine
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# Comparativa y Showcase Hero:
	# 1. [1L] Leche Entera 1L para escala comparativa directa (a la izquierda)
	# 2. [237ml] Frutalia Jugo Manzana 237ml
	# 3. [237ml] Voltik Bebida Energética 237ml
	# 4. [237ml] Yogui Yogurt Fresa 237ml
	# 5. [237ml] Biolact Vainilla 237ml
	# 6. [237ml] Vista de reverso con popote de LimónFit 237ml
	var basis_1l := Basis(Vector3.UP, deg_to_rad(-18.0))
	var t_1l := Transform3D(basis_1l, Vector3(-0.25, 0.0, -0.06))
	CartonDrinksRecipesScript.CartonDrinkRecipe.build(builder, t_1l, {
		"drink": "leche_entera",
		"has_cap": true,
		"collision": true
	})

	var showcase_items := [
		{ "drink": "frutalia_manzana", "pos": Vector3(-0.13, 0.0, -0.01), "rot_y": -22.0, "straw": true },
		{ "drink": "solviva_naranja",  "pos": Vector3(-0.05, 0.0, 0.02),  "rot_y": -16.0, "straw": true },
		{ "drink": "voltik_energetica","pos": Vector3(0.03, 0.0, 0.03),   "rot_y": -12.0, "straw": true },
		{ "drink": "yogui_fresa",      "pos": Vector3(0.11, 0.0, 0.01),   "rot_y": -8.0,  "straw": true },
		{ "drink": "biolact_vainilla", "pos": Vector3(0.19, 0.0, -0.02),  "rot_y": 14.0,  "straw": true },
		# Vista de reverso mostrando el popote adherido:
		{ "drink": "limonfit_limon",   "pos": Vector3(0.27, 0.0, -0.05),  "rot_y": 165.0, "straw": true }
	]

	for item in showcase_items:
		var basis := Basis(Vector3.UP, deg_to_rad(item["rot_y"]))
		var t := Transform3D(basis, item["pos"])
		CartonDrinks237mlRecipesScript.CartonDrink237mlRecipe.build(builder, t, {
			"drink": item["drink"],
			"has_straw": item["straw"],
			"collision": true
		})

	engine.commit()

	# SubViewport for rendering closeup
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1280, 720)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_sub_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 0.17, 0.40)
	_camera.look_at_from_position(_camera.position, Vector3(0.01, 0.07, 0.0), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/carton_drinks_237ml_closeup.png"
			img.save_png(save_path)
			print("✓ Render closeup de bebidas 237ml guardado en: ", save_path)
		quit(0)
	return false
