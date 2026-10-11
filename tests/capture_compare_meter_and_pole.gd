extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const ElectricMeterCFERecipeScript = preload("res://world/object_engine/recipes/electric_meter_cfe_recipe.gd")
const StreetlightPoleRecipeScript = preload("res://world/object_engine/recipes/streetlight_pole_recipe.gd")

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

var _frames := 0
var _cam: Camera3D = null


func _init() -> void:
	print("=================================================================")
	print("=== COMPARACIÓN EN VIVO: MEDIDOR CFE + POSTE DE LUZ (PSX) ===")
	print("=================================================================")

	var root_node := Node3D.new()
	root_node.name = "CompareRoot"
	root.add_child(root_node)

	var engine := ObjectEngineScript.new()
	root_node.add_child(engine)

	var builder := engine.get_builder()

	# 1. Banqueta y Muro de Calle (Contexto Urbano)
	# Banqueta de concreto (Cubo)
	builder.add_box(
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0)),
		Vector3(8.0, 0.20, 3.0),
		"roble_claro",
		Rect2(0.0, 0.0, 1.0, 1.0),
		0.90, 0.0, true
	)
	# Muro de fachada de casa / pilar (Cubo)
	builder.add_box(
		Transform3D(Basis.IDENTITY, Vector3(-1.20, 1.50, -0.90)),
		Vector3(2.4, 2.80, 0.25),
		"commercial_cooler",
		Rect2(0.5, 0.5, 0.5, 0.5), # Concreto claro
		0.80, 0.0, true
	)

	# 2. OBJETO A: Medidor CFE montado en la fachada/pilar (altura estándar 1.65m)
	ElectricMeterCFERecipeScript.build(
		builder,
		Transform3D(Basis.IDENTITY, Vector3(-1.20, 1.65, -0.77)),
		{"include_enclosure": true, "include_switch_box": true}
	)

	# 3. OBJETO B: Poste de Alumbrado Público colocado en la banqueta junto a la calle
	StreetlightPoleRecipeScript.build(
		builder,
		Transform3D(Basis.IDENTITY, Vector3(1.20, 0.20, 0.20)),
		{"height": 6.8, "double_arm": false, "arm_reach": 1.5}
	)

	# Ejecutar el empaquetado del Motor de Objetos
	engine.commit()

	var stats := engine.get_stats()
	print("--- TELEMETRÍA DE DRAW CALLS Y HARDWARE INSTANCING ---")
	print("Total de piezas geométricas combinadas en pantalla: %d" % stats["total_instances"])
	print("DRAW CALLS TOTALES PARA AMBOS OBJETOS + ENTORNO: %d" % stats["draw_calls"])
	print("Primitivas activas en el motor: %s" % str(stats["primitives_active"]))
	print("Colisiones físicas consolidadas en StaticBody3D: %d" % stats["collision_shapes"])
	print("-----------------------------------------------------------------")

	# Configurar Cámara
	_cam = Camera3D.new()
	_cam.fov = 48.0
	root_node.add_child(_cam)

	# Iluminación
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	light.light_energy = 1.3
	root_node.add_child(light)

	# Entorno
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.21, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.68, 0.72)
	env_node.environment = env
	root_node.add_child(env_node)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# Frame 10: Vista Panorámica Urbana (Poste de luz completo de 7m + Medidor CFE en fachada)
	if _frames == 10:
		_cam.position = Vector3(0.20, 3.80, 8.80)
		_cam.look_at_from_position(_cam.position, Vector3(0.0, 3.60, 0.0))

	elif _frames == 14:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/compare_pole_and_meter_overview.png")
				print("✓ Foto 1 guardada: compare_pole_and_meter_overview.png")

	# Frame 18: Vista en Ángulo Medio (El medidor CFE en fachada con el poste de luz en primer plano)
	elif _frames == 18:
		_cam.position = Vector3(0.60, 2.20, 3.00)
		_cam.look_at_from_position(_cam.position, Vector3(-0.60, 1.70, -0.60))

	elif _frames == 22:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/compare_pole_and_meter_closeup.png")
				print("✓ Foto 2 guardada: compare_pole_and_meter_closeup.png")

	elif _frames >= 26:
		print("=== PRUEBA DE COMPARACIÓN FINALIZADA CON ÉXITO ===")
		quit(0)

	return false
