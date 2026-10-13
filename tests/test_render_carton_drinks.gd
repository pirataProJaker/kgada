extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const CartonDrinksRecipesScript = preload("res://world/object_engine/recipes/carton_drinks_recipes.gd")
const CommercialRecipesScript = preload("res://world/object_engine/recipes/commercial_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	print("--- Setting up 1L Beverage Cartons Showcase Render ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.76, 0.80)
	env.ambient_light_energy = 0.95
	env_node.environment = env
	root_node.add_child(env_node)

	# Main light (warm key light)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, 36.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light (cool soft fill)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -50.0, 0.0)
	fill.light_energy = 0.60
	root_node.add_child(fill)

	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.32, 0.34, 0.37)
	floor_mat.roughness = 0.80
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Object Engine
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# Mostrador / Gradas de exhibición de 3 niveles para apreciar los 18 cartones en 3/4
	var step_w := 0.72
	var step_d := 0.12
	var carton_w := 0.090
	var carton_d := 0.058
	var carton_h := 0.185
	var carton_spacing := 0.108

	# Distribuir las 18 bebidas en 3 filas escalonadas de 6 cartones cada una:
	# Fila 0 (Atrás, más alta): Lácteos y Jugos (0..5)
	# Fila 1 (Centro, media): Néctares y Tés (6..11)
	# Fila 2 (Frente, baja): Refrescos y Energizantes (12..17)
	var rows := [
		{ "level": 2, "y": 0.28, "z": -0.22, "start_drink": 0, "rot_y": -12.0 },
		{ "level": 1, "y": 0.14, "z": -0.06, "start_drink": 6, "rot_y": -12.0 },
		{ "level": 0, "y": 0.00, "z":  0.10, "start_drink": 12, "rot_y": -12.0 }
	]

	# Estructura escalonada de exhibición blanca estilo tienda
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.07, 0.10)), Vector3(0.75, 0.14, 0.12), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.14, -0.06)), Vector3(0.75, 0.28, 0.12), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.21, -0.22)), Vector3(0.75, 0.42, 0.12), "commercial_cooler", "white_enamel")

	for r_data in rows:
		var base_y: float = r_data["y"]
		var base_z: float = r_data["z"]
		var rot: float = r_data["rot_y"]
		var start_idx: int = r_data["start_drink"]

		for col in range(6):
			var drink_idx := start_idx + col
			var px := -2.5 * carton_spacing + float(col) * carton_spacing

			var basis := Basis(Vector3.UP, deg_to_rad(rot))
			var t := Transform3D(basis, Vector3(px, base_y + 0.14, base_z))

			CartonDrinksRecipesScript.CartonDrinkRecipe.build(builder, t, {
				"drink": drink_idx,
				"width": carton_w,
				"depth": carton_d,
				"height": carton_h,
				"has_cap": true,
				"collision": true
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
	_camera.position = Vector3(0.12, 0.58, 0.88)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.30, -0.05), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/carton_drinks_showcase.png"
			img.save_png(save_path)
			print("✓ Render de bebidas en cartón guardado en: ", save_path)
		quit(0)
	return false
