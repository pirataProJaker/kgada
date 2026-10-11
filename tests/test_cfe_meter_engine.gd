@tool
extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const ElectricMeterCFERecipeScript = preload("res://world/object_engine/recipes/electric_meter_cfe_recipe.gd")


func _init() -> void:
	print("=== PROBANDO MIGRACIÓN DEL MEDIDOR CFE AL MOTOR DE OBJETOS (+0 DRAW CALLS) ===")

	var root := Node3D.new()
	var engine := ObjectEngineScript.new()
	root.add_child(engine)

	# Crear un muro de fondo para dar contexto visual de fachada/banqueta
	var builder := engine.get_builder()

	# Muro de concreto/ladrillo (Caja)
	builder.add_box(
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, -0.05)),
		Vector3(3.0, 3.0, 0.1),
		"commercial_cooler",
		Rect2(0.5, 0.5, 0.5, 0.5), # Gris claro pared
		0.85, 0.0, true
	)

	# 1. Medidor CFE #1: Incrustado en muro (colonia estándar)
	ElectricMeterCFERecipeScript.build(
		builder,
		Transform3D(Basis.IDENTITY, Vector3(-0.70, 1.60, 0.0)),
		{"include_enclosure": false, "include_switch_box": true}
	)

	# 2. Medidor CFE #2: Montado sobre gabinete metálico con switch
	ElectricMeterCFERecipeScript.build(
		builder,
		Transform3D(Basis.IDENTITY, Vector3(0.70, 1.60, 0.0)),
		{"include_enclosure": true, "include_switch_box": false}
	)

	# Enviar geometría a la GPU
	engine.commit()

	var stats := engine.get_stats()
	print("--- ESTADÍSTICAS DE RENDERIZADO DEL MOTOR DE OBJETOS ---")
	print("Instancias totales procesadas: %d" % stats["total_instances"])
	print("Draw Calls consumidos: %d" % stats["draw_calls"])
	print("Primitivas activas: %s" % str(stats["primitives_active"]))
	print("Colisiones físicas consolidadas: %d" % stats["collision_shapes"])

	# Solo debe haber 2 draw calls (Cilindros de 12 lados y Cubos)
	assert(stats["draw_calls"] == 2, "ERROR: Los draw calls deben ser exactamente 2.")
	print("✓ Verificación matemática superada: Exactamente 2 Draw Calls para toda la escena.")

	# Configurar cámara y luz para captura fotográfica de validación
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.60, 1.10)
	cam.look_at(Vector3(0.0, 1.60, 0.0))
	cam.fov = 45.0
	root.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	light.light_energy = 1.3
	root.add_child(light)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.65)
	env_node.environment = env
	root.add_child(env_node)

	# Renderizar y guardar captura
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 600)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(root)

	var main_window := get_root()
	main_window.add_child(vp)

	# Esperar varios cuadros para asegurar compilación de shaders y renderizado
	for i in range(10):
		await process_frame

	var img := vp.get_texture().get_image()
	var save_path := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181/cfe_meter_engine_verification.png"
	var err := img.save_png(save_path)
	if err == OK:
		print("✓ Captura guardada con éxito en: ", save_path)
	else:
		printerr("Error guardando captura: ", err)

	main_window.remove_child(vp)
	vp.free()
	quit(0)
