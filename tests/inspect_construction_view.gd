extends SceneTree
## Herramienta de Inspección Visual Automatizada para el Sistema de Construcción.
## Simula la colocación de pisos y estructuras en un chunk real,
## renderiza desde múltiples ángulos de cámara (perspectiva y cenital)
## y guarda las capturas directamente en la carpeta de artefactos para análisis visual.

const ARTIFACT_DIR := "C:/Users/PC 1/.gemini/antigravity-ide/brain/7665bda4-35a4-4713-97f9-d4941a9911be"
const ConstructionVisualMarkerScript = preload("res://world/building/construction_visual_marker.gd")

var _stage: int = 0
var _frame: int = 0
var _viewport: Viewport
var _camera: Camera3D
var _scene_root: Node3D
var _engine: Node3D
var _marker: Node3D

func _init() -> void:
	print("🔍 [InspectTool] Inicializando herramienta de inspección visual de construcción...")

	# Crear escena raíz
	_scene_root = Node3D.new()
	root.add_child(_scene_root)

	# 1. Luz direccional con sombras
	var sun := DirectionalLight3D.new()
	sun.transform.basis = Basis.looking_at(Vector3(-0.6, -0.8, -0.5).normalized(), Vector3.UP)
	sun.position = Vector3(0, 15, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	_scene_root.add_child(sun)

	# 2. Entorno con cielo
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 1.0
	env_node.environment = env
	_scene_root.add_child(env_node)

	# 3. Terreno de 1 chunk (40x40m) con cuadrícula visible para medir precisión de snap
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	plane.subdivide_width = 40 # 1 división por metro
	plane.subdivide_depth = 40
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.45, 0.22)
	ground_mat.roughness = 0.9
	plane.material = ground_mat
	ground.mesh = plane
	_scene_root.add_child(ground)

	# Colisión estática de suelo
	var static_body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(40, 2, 40)
	col_shape.shape = box_col
	col_shape.position = Vector3(0, -1, 0)
	static_body.add_child(col_shape)
	_scene_root.add_child(static_body)

	# 4. ConstructionEngine (Rust)
	if ClassDB.class_exists("ConstructionEngine"):
		_engine = ClassDB.instantiate("ConstructionEngine")
		_scene_root.add_child(_engine)
		print("🔍 [InspectTool] ConstructionEngine (Rust) instanciado.")

	# 5. Marcador visual de trazado
	_marker = ConstructionVisualMarkerScript.new()
	_scene_root.add_child(_marker)

	# 6. Cámara de inspección
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 65.0
	_scene_root.add_child(_camera)

	process_frame.connect(_on_process_frame)

func _on_process_frame() -> void:
	_frame += 1
	if _frame < 8:
		return

	match _stage:
		0:
			# CASO 1: PERÍMETRO COMPLETO DE TIERRA RASCADA Y FANTASMA HOLOGRÁFICO
			print("📸 [InspectTool] Caso 1: Mostrando Toda la Orilla Rascada con Palo y Fantasma...")
			var p0 := Vector3(0, 0, 0)
			var p1 := Vector3(3.4, 0, 2.6)
			var w := absf(p1.x - p0.x)
			var d := absf(p1.z - p0.z)

			# Holograma
			var ghost := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(w, 0.20, d)
			var g_mat := StandardMaterial3D.new()
			g_mat.albedo_color = Color(0.2, 0.75, 1.0, 0.35)
			g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			g_mat.emission_enabled = true
			g_mat.emission = Color(0.1, 0.6, 0.95)
			g_mat.emission_energy_multiplier = 0.8
			box.material = g_mat
			ghost.mesh = box
			ghost.position = Vector3(w * 0.5, 0.10, d * 0.5)
			ghost.name = "GhostPreviewMesh"
			_scene_root.add_child(ghost)

			# Etiqueta 3D
			var lbl := Label3D.new()
			lbl.name = "GhostDimensionLabel"
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.font_size = 28
			lbl.outline_size = 8
			lbl.outline_modulate = Color(0.05, 0.05, 0.05, 0.95)
			lbl.modulate = Color(1.0, 0.92, 0.35)
			lbl.text = "📐 %.1fm × %.1fm  (%.1f m²)" % [w, d, w * d]
			lbl.position = Vector3(w * 0.5, 0.85, d * 0.5)
			_scene_root.add_child(lbl)

			# Marcador de toda la orilla con tierra rascada (4 lados + 4 esquinas con montículos)
			var c0 := Vector3(0, 0, 0)
			var c1 := Vector3(w, 0, 0)
			var c2 := Vector3(w, 0, d)
			var c3 := Vector3(0, 0, d)
			var pts_scrape: Array[Vector3] = [c0, c1, c2, c3, c0]
			_marker.setup("dirt_scrape", pts_scrape)

			# Cámara isométrica
			_camera.position = Vector3(5, 4.5, 5.5)
			_camera.look_at(Vector3(w * 0.5, 0.1, d * 0.5), Vector3.UP)

			_stage = 1
			_frame = 0

		1:
			if _frame >= 10:
				_save_screenshot("inspect_ghost_preview.png")
				var old_ghost = _scene_root.get_node_or_null("GhostPreviewMesh")
				if old_ghost: old_ghost.queue_free()
				var old_lbl = _scene_root.get_node_or_null("GhostDimensionLabel")
				if old_lbl: old_lbl.queue_free()
				_stage = 2
				_frame = 0

		2:
			# CASO 2: TRAZADO CON PALO CONFIRMADO (SIN PISO SÓLIDO, SOLO LA ORILLA RASCADA EN LA TIERRA)
			print("📸 [InspectTool] Caso 2: Trazado confirmado (PlannedSite). Toda la orilla rascada sin piso...")
			var planned_script = preload("res://world/building/planned_site.gd")
			var site = planned_script.new()
			site.name = "TestPlannedSite"
			var tool_dict := {"name": "Palo de Trazado", "marker_type": "dirt_scrape", "discount_percent": 0.0}
			site.setup(0, Vector3(0.5, 0.0, 0.5), Vector3(4.5, 0.0, 3.5), tool_dict)
			_scene_root.add_child(site)

			_marker.clear()
			_camera.position = Vector3(2.5, 5.5, 6.0)
			_camera.look_at(Vector3(2.5, 0.0, 2.0), Vector3.UP)
			_stage = 3
			_frame = 0

		3:
			if _frame >= 10:
				_save_screenshot("inspect_scraped_earth_perimeter.png")
				# Mover cámara a primer plano del surco 3D y el montículo de la esquina
				print("📸 [InspectTool] Caso 2B: Primer plano (Close-up) del relieve 3D rascado y textura...")
				_camera.position = Vector3(1.2, 0.65, 1.2)
				_camera.look_at(Vector3(0.5, 0.03, 0.5), Vector3.UP)
				_stage = 4
				_frame = 0

		4:
			if _frame >= 10:
				_save_screenshot("inspect_scraped_3d_closeup.png")
				# Regresar cámara para ver la construcción
				_camera.position = Vector3(2.5, 5.5, 6.0)
				_camera.look_at(Vector3(2.5, 0.0, 2.0), Vector3.UP)
				_stage = 5
				_frame = 0

		5:
			# CASO 3: EL JUGADOR APLICA MADERA AL TRAZADO -> SE CONSTRUYE EL PISO
			print("📸 [InspectTool] Caso 3: Edificación del trazado con Madera...")
			var site = _scene_root.get_node_or_null("TestPlannedSite")
			if site and _engine:
				site.call("build_with_material", 0, null, _engine) # 0: Wood
				print("   -> ¡Piso de madera construido y trazado de tierra completado!")

			_stage = 6
			_frame = 0

		6:
			if _frame >= 10:
				_save_screenshot("inspect_built_from_scraped_site.png")
				print("🎉 [InspectTool] Inspección visual completada exitosamente.")
				quit(0)

func _save_screenshot(filename: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img:
		var project_path := "res://tests/" + filename
		var artifact_path := ARTIFACT_DIR + "/" + filename
		img.save_png(project_path)
		img.save_png(artifact_path)
		print("💾 Captura guardada en: ", artifact_path)
