extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const ElectricMeterCFERecipeScript = preload("res://world/object_engine/recipes/electric_meter_cfe_recipe.gd")

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

var _frames := 0
var _cam: Camera3D = null


func _init() -> void:
	print("=== INICIANDO CAPTURA DEL MEDIDOR CFE EN EL MOTOR DE OBJETOS (+0 DRAW CALLS) ===")

	var root_node := Node3D.new()
	root_node.name = "TestRoot"
	root.add_child(root_node)

	var engine := ObjectEngineScript.new()
	root_node.add_child(engine)

	var builder := engine.get_builder()

	# 1. Muro de fachada (Caja con textura de pared)
	builder.add_box(
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, -0.05)),
		Vector3(3.0, 2.5, 0.1),
		"roble_claro",
		Rect2(0.0, 0.0, 1.0, 1.0),
		0.80, 0.0, true
	)

	# 2. Medidor CFE #1: Montado con gabinete de switch lateral (Casa estándar)
	ElectricMeterCFERecipeScript.build(
		builder,
		Transform3D(Basis.IDENTITY, Vector3(-0.55, 1.50, 0.0)),
		{"include_enclosure": false, "include_switch_box": true}
	)

	# 3. Medidor CFE #2: Montado en caja gabinete Square D (Pilar / Acometida)
	ElectricMeterCFERecipeScript.build(
		builder,
		Transform3D(Basis.IDENTITY, Vector3(0.55, 1.50, 0.0)),
		{"include_enclosure": true, "include_switch_box": false}
	)

	# Compilar buffers a GPU
	engine.commit()

	var stats := engine.get_stats()
	print("ESTADÍSTICAS DEL MOTOR DE OBJETOS:")
	print("- Total instancias procesadas en GPU: %d" % stats["total_instances"])
	print("- Draw Calls totales consumidos: %d" % stats["draw_calls"])
	print("- Primitivas activas: %s" % str(stats["primitives_active"]))

	# Configurar Cámara
	_cam = Camera3D.new()
	_cam.fov = 40.0
	root_node.add_child(_cam)

	# Iluminación
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, 35.0, 0.0)
	light.light_energy = 1.25
	root_node.add_child(light)

	# Luz ambiental
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.68, 0.72)
	env_node.environment = env
	root_node.add_child(env_node)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# Frame 10: Foto Frontal de ambos medidores CFE
	if _frames == 10:
		_cam.position = Vector3(0.0, 1.50, 1.60)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 1.50, 0.0))

	elif _frames == 14:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cfe_meter_engine_front.png")
				print("✓ Captura Frontal guardada: cfe_meter_engine_front.png")

	# Frame 18: Foto Closeup en Ángulo del Medidor CFE (apreciando profundidad de cilindros y carátula de cristal)
	elif _frames == 18:
		_cam.position = Vector3(0.20, 1.58, 0.70)
		_cam.look_at_from_position(_cam.position, Vector3(0.55, 1.50, 0.0))

	elif _frames == 22:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cfe_meter_engine_closeup.png")
				print("✓ Captura Closeup guardada: cfe_meter_engine_closeup.png")

	elif _frames >= 26:
		print("=== CAPTURAS FINALIZADAS CON ÉXITO ===")
		quit(0)

	return false
