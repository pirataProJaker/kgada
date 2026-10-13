extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const SodaCansRecipesScript = preload("res://world/object_engine/recipes/soda_cans_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	print("--- Setting up 19 Soda Cans Showcase Render ---")
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
	sun.rotation_degrees = Vector3(-34.0, 38.0, 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light (cool soft fill)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -50.0, 0.0)
	fill.light_energy = 0.65
	root_node.add_child(fill)

	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.30, 0.32, 0.35)
	floor_mat.roughness = 0.80
	floor_mesh.material_override = floor_mat
	root_node.add_child(floor_mesh)

	# Object Engine
	var engine = ObjectEngineScript.new()
	root_node.add_child(engine)
	var builder = engine.get_builder()

	# Gradas de exhibición comercial (4 niveles para las 19 latas)
	var can_r := 0.033
	var can_h := 0.122
	var can_spacing := 0.090

	# 4 filas:
	# Fila 3 (Atrás, más alta): 5 latas (Row 0: Kola, Pepzi, Spritz, Fanta, Seven)
	# Fila 2: 5 latas (Row 1: Pepper, Dew, Crushy, Squirt, Mirindaz)
	# Fila 1: 5 latas (Row 2: Jarriton, Manzanita, Freskita, Inka, Canada Dry)
	# Fila 0 (Frente, baja): 4 latas (Row 3: Red Buller, Mounstro, A&W, Muggy)
	var rows := [
		{ "y": 0.33, "z": -0.27, "start_can": 0,  "count": 5, "rot_y": -12.0 },
		{ "y": 0.22, "z": -0.15, "start_can": 5,  "count": 5, "rot_y": -12.0 },
		{ "y": 0.11, "z": -0.03, "start_can": 10, "count": 5, "rot_y": -12.0 },
		{ "y": 0.00, "z":  0.09, "start_can": 15, "count": 4, "rot_y": -12.0 }
	]

	# Estructura de mostrador blanco
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.055, 0.09)), Vector3(0.72, 0.11, 0.12), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.110, -0.03)), Vector3(0.72, 0.22, 0.12), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.165, -0.15)), Vector3(0.72, 0.33, 0.12), "commercial_cooler", "white_enamel")
	builder.add_smart_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.220, -0.27)), Vector3(0.72, 0.44, 0.12), "commercial_cooler", "white_enamel")

	for r_data in rows:
		var base_y: float = r_data["y"]
		var base_z: float = r_data["z"]
		var rot: float = r_data["rot_y"]
		var start_idx: int = r_data["start_can"]
		var count: int = r_data["count"]

		var half_span := float(count - 1) * 0.5 * can_spacing
		for col in range(count):
			var can_idx := start_idx + col
			var px := -half_span + float(col) * can_spacing

			var basis := Basis(Vector3.UP, deg_to_rad(rot))
			var t := Transform3D(basis, Vector3(px, base_y + 0.11, base_z))

			SodaCansRecipesScript.SodaCanRecipe.build(builder, t, {
				"can": can_idx,
				"radius": can_r,
				"height": can_h,
				"has_lid": true,
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
	# Cámara frontal-elevada para ver las 19 latas y sus tapas
	_camera.position = Vector3(0.0, 0.60, 0.72)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.24, -0.08), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/soda_cans_showcase.png"
			img.save_png(save_path)
			print("✓ Render showcase de 19 latas guardado en: ", save_path)
		quit(0)
	return false
