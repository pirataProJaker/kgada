extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
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
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.92)
	env.ambient_light_energy = 0.90
	env_node.environment = env
	root_node.add_child(env_node)

	# Key light
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, 36.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -45.0, 0.0)
	fill.light_energy = 0.70
	root_node.add_child(fill)

	# Object Engine
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# Display rack / Estantería de 5 niveles para los 50 cartones (10 por nivel)
	var num_rows := 5
	var num_cols := 10
	var carton_w := 0.053
	var carton_d := 0.038
	var carton_h := 0.120
	var gap_x := 0.016
	var step_x := carton_w + gap_x
	var shelf_step_y := 0.155
	var shelf_step_z := -0.070 # Ligera grada escalonada hacia atrás para visualización óptima

	var start_x := -float(num_cols - 1) * step_x * 0.5
	var total_w := float(num_cols) * step_x + 0.05

	for r in range(num_rows):
		var shelf_y := float(4 - r) * shelf_step_y
		var shelf_z := float(r) * shelf_step_z

		# Repisa metálica gris/blanca bajo cada fila
		var shelf_t := Transform3D(Basis.IDENTITY, Vector3(0.0, shelf_y - 0.005, shelf_z))
		builder.add_box(
			shelf_t,
			Vector3(total_w, 0.008, 0.12),
			"commercial_shelf",
			Rect2(0, 0, 1, 1),
			0.40,
			0.50,
			true
		)

		# Colocar los 10 cartones de esta fila
		for c in range(num_cols):
			var idx := r * 10 + c
			var pos := Vector3(start_x + float(c) * step_x, shelf_y, shelf_z)
			# Ligero ángulo de 3/4 (-14 grados) para lucir tanto el frente como la tabla lateral
			var rot := Basis(Vector3.UP, deg_to_rad(-14.0))
			var t := Transform3D(rot, pos)

			CartonDrinks237mlRecipesScript.CartonDrink237mlRecipe.build(builder, t, {
				"drink": idx,
				"has_straw": true,
				"collision": false
			})

	engine.commit()

	# SubViewport for rendering showcase
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1600, 900)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 55.0
	_sub_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 0.38, 0.92)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.32, -0.12), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/carton_drinks_237ml_showcase.png"
			img.save_png(save_path)
			print("✓ Render showcase de las 50 bebidas 237ml guardado en: ", save_path)
		quit(0)
	return false
