extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const CerealBoxesRecipesScript = preload("res://world/object_engine/recipes/cereal_boxes_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	print("--- Setting up 20 Cereal Boxes Showcase Render ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.80, 0.84)
	env.ambient_light_energy = 0.95
	env_node.environment = env
	root_node.add_child(env_node)

	# Main light (warm key light)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light (cool soft fill)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, -50.0, 0.0)
	fill.light_energy = 0.65
	root_node.add_child(fill)

	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.30, 0.34)
	floor_mat.roughness = 0.80
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Object Engine
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# Gradas de anaquel de supermercado (4 repisas escalonadas para las 20 cajas)
	var box_w := 0.180
	var box_h := 0.260
	var box_d := 0.060
	var spacing_x := 0.220

	# 4 filas:
	# Fila 3 (Atrás, más alta): 5 cajas (Row 0: Krisp Max, Zucarinix, Corny Bits, Choco Bites, Fruti Loops)
	# Fila 2: 5 cajas (Row 1: Choco Krunch, Miel Dorada, Estrella Flakes, Granola Mix, Avena Crunch)
	# Fila 1: 5 cajas (Row 2: Tornado Flakes, Frosty Crunch, Rayo Cereal, Selva Crunch, Sol Nativo)
	# Fila 0 (Frente, baja): 5 cajas (Row 3: Campo Feliz, Dulce Maiz, Choco Rizos, Nube Crispy, Bosque Crunch)
	var rows := [
		{ "y": 0.81, "z": -0.45, "start_can": 0,  "rot_y": -16.0 },
		{ "y": 0.54, "z": -0.25, "start_can": 5,  "rot_y": -16.0 },
		{ "y": 0.27, "z": -0.05, "start_can": 10, "rot_y": -16.0 },
		{ "y": 0.00, "z":  0.15, "start_can": 15, "rot_y": -16.0 }
	]

	# Estructuras de repisas blancas
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.135, 0.15)), Vector3(1.25, 0.27, 0.18), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.270, -0.05)), Vector3(1.25, 0.54, 0.18), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.405, -0.25)), Vector3(1.25, 0.81, 0.18), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.540, -0.45)), Vector3(1.25, 1.08, 0.18), "commercial_cooler", "white_enamel")

	for r_data in rows:
		var base_y: float = r_data["y"]
		var base_z: float = r_data["z"]
		var rot: float = r_data["rot_y"]
		var start_idx: int = r_data["start_can"]

		var half_span := 4.0 * 0.5 * spacing_x
		for col in range(5):
			var box_idx := start_idx + col
			var px := -half_span + float(col) * spacing_x

			var basis := Basis(Vector3.UP, deg_to_rad(rot))
			var t := Transform3D(basis, Vector3(px, base_y + 0.27, base_z))

			CerealBoxesRecipesScript.CerealBoxRecipe.build(builder, t, {
				"cereal": box_idx,
				"width": box_w,
				"height": box_h,
				"depth": box_d,
				"collision": true
			})

	engine.commit()

	# SubViewport for rendering
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1280, 720)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_sub_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_sub_viewport.add_child(_camera)
	# Cámara para exhibición completa de las 20 cajas
	_camera.position = Vector3(0.0, 1.15, 1.45)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.65, -0.15), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/cereal_boxes_showcase.png"
			img.save_png(save_path)
			print("✓ Render showcase de 20 cajas de cereal guardado en: ", save_path)
		quit(0)
	return false
