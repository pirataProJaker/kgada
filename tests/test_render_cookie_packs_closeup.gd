extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const CookiePacksRecipesScript = preload("res://world/object_engine/recipes/cookie_packs_recipes.gd")

var _frame := 0
var _sub_viewport: SubViewport
var _camera: Camera3D

func _init() -> void:
	print("--- Setting up Cookie Packs Closeup Render ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	# World environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
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

	# 5 Paquetes de galletas destacados para apreciar Frente, Lateral y Dorso:
	# 1. Clásicas (Azul): Ángulo 3/4 mostrando Frente y Tira Lateral
	# 2. Fresa (Rojo): Frente con fresas y logotipo Rizko
	# 3. Crema (Negro): De espaldas mostrando tabla nutrimental, código de barras e ingredientes
	# 4. Chispas (Cian): Ángulo 3/4
	# 5. Festival (Negro/Confeti): Ángulo mostrando lateral y frente
	var featured := [
		{ "cookie": "clasicas", "pos": Vector3(-0.16, 0.0, -0.02), "rot_y": -24.0 },
		{ "cookie": "fresa",    "pos": Vector3(-0.08, 0.0,  0.01), "rot_y": -12.0 },
		{ "cookie": "crema",    "pos": Vector3( 0.00, 0.0,  0.03), "rot_y": 165.0 }, # Vista dorsal con código de barras
		{ "cookie": "chispas",  "pos": Vector3( 0.08, 0.0,  0.01), "rot_y": -18.0 },
		{ "cookie": "festival", "pos": Vector3( 0.16, 0.0, -0.02), "rot_y": -14.0 }
	]

	for item in featured:
		var basis := Basis(Vector3.UP, deg_to_rad(item["rot_y"]))
		var t := Transform3D(basis, item["pos"])
		CookiePacksRecipesScript.CookiePackRecipe.build(builder, t, {
			"cookie": item["cookie"],
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
	_camera.position = Vector3(0.0, 0.14, 0.36)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.09, 0.0), Vector3.UP)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		var img := _sub_viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/cookie_packs_closeup.png"
			img.save_png(save_path)
			print("✓ Render closeup de galletas Rizko guardado en: ", save_path)
		quit(0)
	return false
