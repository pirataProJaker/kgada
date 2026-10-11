@tool
extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const AppliancesRecipesScript = preload("res://world/object_engine/recipes/appliances_recipes.gd")

var _frames := 0
var _engine: Node3D = null

func _init() -> void:
	print("=== INICIANDO CAPTURA DE LAVADORA Y SECADORA (MOTOR DE OBJETOS +0 DRAW CALLS) ===")
	
	var world := Node3D.new()
	root.add_child(world)
	
	# Entorno e iluminación neutra como en el render de referencia
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.24, 0.25, 0.28) # Gris azulado oscuro neutro
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.75, 0.76, 0.80)
	env_res.ambient_light_energy = 1.0
	env.environment = env_res
	world.add_child(env)
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	light.light_energy = 0.95
	world.add_child(light)
	
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-15.0, -45.0, 0.0)
	fill_light.light_energy = 0.45
	world.add_child(fill_light)
	
	# Cámara (Ángulo idéntico al render de referencia del usuario: ligeramente ladeado y cenital 17°)
	var camera := Camera3D.new()
	camera.name = "TestCamera"
	camera.position = Vector3(0.18, 1.30, 1.82)
	camera.rotation_degrees = Vector3(-17.0, 7.5, 0.0)
	world.add_child(camera)
	
	# Motor de Objetos (+0 Draw Calls)
	_engine = ObjectEngineScript.new()
	world.add_child(_engine)
	
	var builder = _engine.get_builder()
	
	# Fila 1: Comparativa exacta con la referencia del usuario (Cerradas)
	# Lavadora Cerrada (X = -0.42) y Secadora Cerrada (X = 0.42)
	AppliancesRecipesScript.WasherRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-0.42, 0.0, 0.0)), {"is_open": false})
	AppliancesRecipesScript.DryerRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(0.42, 0.0, 0.0)), {"is_open": false})
	
	_engine.commit()
	print("✓ ObjectEngine commit ejecutado. Stats: ", _engine.get_stats())

func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()
	
	# Frame 8: Captura de referencia idéntica a la imagen del usuario (Washer y Dryer cerradas)
	if _frames == 8:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/washer_dryer_closed_parity.png")
				print("✓ Captura guardada: washer_dryer_closed_parity.png")
	
	# Frame 12: Cambiamos a mostrar las 4 variantes (Cerradas y Abiertas)
	elif _frames == 12:
		_engine.clear()
		var builder = _engine.get_builder()
		# 1. Lavadora Cerrada
		AppliancesRecipesScript.WasherRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-1.26, 0.0, 0.0)), {"is_open": false})
		# 2. Lavadora Abierta
		AppliancesRecipesScript.WasherRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-0.42, 0.0, 0.0)), {"is_open": true})
		# 3. Secadora Cerrada
		AppliancesRecipesScript.DryerRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(0.42, 0.0, 0.0)), {"is_open": false})
		# 4. Secadora Abierta
		AppliancesRecipesScript.DryerRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(1.26, 0.0, 0.0)), {"is_open": true})
		_engine.commit()
		
		# Ajustar cámara para ver las 4
		var cam: Camera3D = root.find_child("TestCamera", true, false)
		if cam:
			cam.position = Vector3(0.0, 1.65, 3.1)
			cam.rotation_degrees = Vector3(-24.0, 0.0, 0.0)
	
	# Frame 18: Guardar captura panorámica de todas las variantes
	elif _frames == 18:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/washer_dryer_all_states.png")
				print("✓ Captura guardada: washer_dryer_all_states.png")
	
	# Frame 22: Primer plano cercano mirando hacia la tina y rodillo de la lavadora abierta
	elif _frames == 22:
		var cam: Camera3D = root.find_child("TestCamera", true, false)
		if cam:
			cam.position = Vector3(-0.42, 1.40, 0.85)
			cam.rotation_degrees = Vector3(-42.0, 0.0, 0.0)
	
	# Frame 26: Guardar primer plano de la lavadora abierta (tina + agitador)
	elif _frames == 26:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/washer_open_drum_closeup.png")
				print("✓ Captura guardada: washer_open_drum_closeup.png")
	
	# Frame 30: Primer plano cercano de la secadora abierta (puerta abatida + tambor)
	elif _frames == 30:
		var cam: Camera3D = root.find_child("TestCamera", true, false)
		if cam:
			cam.position = Vector3(1.26, 1.15, 1.05)
			cam.rotation_degrees = Vector3(-18.0, 15.0, 0.0)
	
	# Frame 34: Guardar primer plano de la secadora abierta
	elif _frames == 34:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/dryer_open_drum_closeup.png")
				print("✓ Captura guardada: dryer_open_drum_closeup.png")
	
	elif _frames >= 38:
		print("=== CAPTURAS DE LAVADORAS Y SECADORAS COMPLETADAS ===")
		quit(0)
	
	return false
