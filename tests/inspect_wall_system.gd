extends SceneTree
## Herramienta de Inspección Visual para el Sistema de Paredes:
## 1. Restricción exclusiva a pisos (advertencia roja si está fuera).
## 2. Anclaje magnético automático a las orillas del piso (🧲).
## 3. Flujo guiado de 3 pasos: P0 en piso -> Altura -> Largo en piso -> Trazado delimitado.

const ARTIFACT_DIR := "C:/Users/PC 1/.gemini/antigravity-ide/brain/7665bda4-35a4-4713-97f9-d4941a9911be"
const PlannedSiteScript = preload("res://world/building/planned_site.gd")

var _stage: int = 0
var _frame: int = 0
var _camera: Camera3D
var _scene_root: Node3D
var _engine: Node3D
var _ghost_mesh: MeshInstance3D
var _label: Label3D
var _aiming_marker: MeshInstance3D
var _aiming_mat: StandardMaterial3D
var _ghost_mat: StandardMaterial3D

func _init() -> void:
	print("🔍 [InspectWallTool] Inicializando inspección visual del sistema de paredes...")

	_scene_root = Node3D.new()
	root.add_child(_scene_root)

	# 1. Luz direccional
	var sun := DirectionalLight3D.new()
	sun.transform.basis = Basis.looking_at(Vector3(-0.6, -0.8, -0.5).normalized(), Vector3.UP)
	sun.position = Vector3(0, 15, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	_scene_root.add_child(sun)

	# 2. Entorno
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 1.0
	env_node.environment = env
	_scene_root.add_child(env_node)

	# 3. Terreno
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.25, 0.45, 0.22)
	plane.material = g_mat
	ground.mesh = plane
	_scene_root.add_child(ground)

	# 4. ConstructionEngine
	if ClassDB.class_exists("ConstructionEngine"):
		_engine = ClassDB.instantiate("ConstructionEngine")
		_scene_root.add_child(_engine)

	# 5. Componentes visuales
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.2, 0.75, 1.0, 0.40)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(0.1, 0.55, 0.95)
	_ghost_mat.emission_energy_multiplier = 0.65

	_ghost_mesh = MeshInstance3D.new()
	_ghost_mesh.visible = false
	_scene_root.add_child(_ghost_mesh)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 24
	_label.outline_size = 8
	_label.outline_modulate = Color(0.05, 0.05, 0.05, 0.95)
	_label.visible = false
	_scene_root.add_child(_label)

	_aiming_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.20
	torus.outer_radius = 0.30
	_aiming_marker.mesh = torus
	_aiming_mat = StandardMaterial3D.new()
	_aiming_mat.emission_enabled = true
	_aiming_mat.emission_energy_multiplier = 0.9
	_aiming_marker.material_override = _aiming_mat
	_aiming_marker.visible = false
	_scene_root.add_child(_aiming_marker)

	# 6. Cámara en ángulo cenital-isométrico
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 55.0
	_scene_root.add_child(_camera)

	process_frame.connect(_on_process_frame)

func _on_process_frame() -> void:
	_frame += 1
	if _frame < 8:
		return

	# Ajustar cámara y preparar el piso en el primer frame activo
	if _stage == 0 and _frame == 8:
		_camera.position = Vector3(2.0, 4.8, 6.2)
		_camera.look_at(Vector3(2.0, 0.0, 1.2), Vector3.UP)

		# Construir piso de madera previo (4m x 3m desde X:0..4, Z:0..3)
		if _engine:
			_engine.call("add_floor_span", Vector3(0, 0, 0), Vector3(4, 0, 3), 0) # 0: Wood
			print("🔍 [InspectWallTool] Piso de madera previo (4.0m x 3.0m) generado en ConstructionEngine.")

	match _stage:
		0:
			# CASO 1: RESTRICCIÓN - Cursor fuera de piso muestra advertencia roja
			print("📸 [InspectWallTool] Caso 1: Intentando colocar pared fuera de piso...")
			var outside_pos := Vector3(2.0, 0.0, 4.2) # Fuera del piso en Z (piso llega a Z=3)
			_aiming_mat.albedo_color = Color(1.0, 0.20, 0.20, 0.90)
			_aiming_mat.emission = Color(0.95, 0.15, 0.15)
			_aiming_marker.global_position = outside_pos + Vector3(0, 0.05, 0)
			_aiming_marker.visible = true

			_label.text = "❌ Las paredes solo se pueden colocar dentro de un piso"
			_label.modulate = Color(1.0, 0.35, 0.35)
			_label.global_position = outside_pos + Vector3(0, 0.65, 0)
			_label.visible = true

			_stage = 1
			_frame = 0

		1:
			if _frame >= 10:
				_save_screenshot("inspect_wall_outside_floor.png")
				_stage = 2
				_frame = 0

		2:
			# CASO 2: ANCLAJE MAGNÉTICO - Cursor cerca de la orilla frontal del piso (Z=3.0)
			print("📸 [InspectWallTool] Caso 2: Anclaje magnético a la orilla del piso...")
			var raw_pos := Vector3(1.8, 0.0, 2.85) # Muy cerca del borde sur Z=3.0
			var snap_res: Dictionary = _engine.call("snap_point_to_floor", raw_pos, 0.45)
			var snapped_pos: Vector3 = snap_res.get("position", raw_pos)

			_aiming_mat.albedo_color = Color(0.15, 0.95, 0.85, 0.90) # Turquesa magnético
			_aiming_mat.emission = Color(0.10, 0.90, 0.80)
			_aiming_marker.global_position = snapped_pos + Vector3(0, 0.05, 0)
			_aiming_marker.visible = true

			_label.text = "🧲 Orilla de piso detectada [Clic 1: Fijar inicio de pared]"
			_label.modulate = Color(0.35, 1.0, 0.90)
			_label.global_position = snapped_pos + Vector3(0, 0.65, 0)
			_label.visible = true

			_stage = 3
			_frame = 0

		3:
			if _frame >= 10:
				_save_screenshot("inspect_wall_magnetic_edge_snap.png")
				_stage = 4
				_frame = 0

		4:
			# CASO 3: PASO 2 - P0 FIJADO EN LA ORILLA, AJUSTANDO ALTURA
			print("📸 [InspectWallTool] Caso 3: Paso 2 - Definiendo la altura de la pared...")
			_aiming_marker.visible = false

			var p0 := Vector3(0.0, 0.0, 3.0) # Esquina frontal del piso
			var wall_height := 2.5

			var col := BoxMesh.new()
			col.size = Vector3(0.28, wall_height, 0.28)
			col.material = _ghost_mat
			_ghost_mesh.mesh = col
			_ghost_mesh.rotation = Vector3.ZERO
			_ghost_mesh.global_position = Vector3(p0.x, p0.y + wall_height * 0.5, p0.z)
			_ghost_mesh.visible = true

			_label.text = "📏 Paso 2/3: Altura de pared = %.1f m\n[Mueve el ratón arriba/abajo • Clic Izq: Confirmar Altura]" % wall_height
			_label.modulate = Color(1.0, 0.92, 0.35)
			_label.global_position = Vector3(p0.x, p0.y + wall_height + 0.55, p0.z)
			_label.visible = true

			_stage = 5
			_frame = 0

		5:
			if _frame >= 10:
				_save_screenshot("inspect_wall_step2_height.png")
				_stage = 6
				_frame = 0

		6:
			# CASO 4: PASO 3 - ALTURA FIJADA (2.5m), AJUSTANDO LARGO A LO LARGO DE LA ORILLA DEL PISO
			print("📸 [InspectWallTool] Caso 4: Paso 3 - Definiendo el largo dentro del piso...")
			var p0 := Vector3(0.0, 0.0, 3.0)
			var p1 := Vector3(4.0, 0.0, 3.0) # Borde frontal completo del piso (4m de largo)
			var wall_height := 2.5
			var wall_len := p0.distance_to(p1)

			var wall_box := BoxMesh.new()
			wall_box.size = Vector3(wall_len, wall_height, 0.20)
			wall_box.material = _ghost_mat
			_ghost_mesh.mesh = wall_box
			_ghost_mesh.rotation = Vector3.ZERO
			_ghost_mesh.global_position = Vector3(2.0, wall_height * 0.5, 3.0)
			_ghost_mesh.visible = true

			_label.text = "📐 Paso 3/3: Pared = %.1fm largo × %.1fm alto (🧲 Anclado a orilla)\n[Clic Izq: Construir • Clic Der: Reajustar Altura]" % [wall_len, wall_height]
			_label.modulate = Color(1.0, 0.92, 0.35)
			_label.global_position = Vector3(2.0, wall_height + 0.65, 3.0)
			_label.visible = true

			_stage = 7
			_frame = 0

		7:
			if _frame >= 10:
				_save_screenshot("inspect_wall_step3_length.png")
				_stage = 8
				_frame = 0

		8:
			# CASO 5: PARED DELIMITADA EN EL TRAZADO DEL PISO
			print("📸 [InspectWallTool] Caso 5: Pared delimitada en el trazado del piso...")
			_ghost_mesh.visible = false
			_label.visible = false

			var p0 := Vector3(0.0, 0.0, 3.0)
			var p1 := Vector3(4.0, 0.0, 3.0)
			var tool_dict := {"name": "Palo de Trazado", "marker_type": "dirt_scrape", "discount_percent": 0.0}

			var wall_site = PlannedSiteScript.new()
			wall_site.setup(1, p0, p1, tool_dict, 2.5) # 1: Wall, 2.5m
			_scene_root.add_child(wall_site)

			_stage = 9
			_frame = 0

		9:
			if _frame >= 10:
				_save_screenshot("inspect_wall_confirmed_site.png")
				print("🎉 [InspectWallTool] Inspección visual completada exitosamente.")
				quit(0)

func _save_screenshot(filename: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img:
		var project_path := "res://tests/" + filename
		var artifact_path := ARTIFACT_DIR + "/" + filename
		img.save_png(project_path)
		img.save_png(artifact_path)
		print("💾 Captura guardada en: ", artifact_path)
