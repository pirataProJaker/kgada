class_name OfficePackShowcase
extends Node3D

## Escaparate Oficial del Conjunto de Mobiliario de Oficina (Office Pack)
## Reproduce fielmente los modelos en Hardware Instancing a +0 Draw Calls en ObjectEngine.
## Soporte interactivo: Gavetas y archiveros abribles/cerrables (Presiona ESPACIO para alternar).

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const OfficeRecipesScript = preload("res://world/object_engine/recipes/office_recipes.gd")

const MOVE_SPEED := 7.0
const SPRINT_SPEED := 18.0
const MOUSE_SENSITIVITY := 0.0025

var _engine: ObjectEngine = null
var _camera: Camera3D = null
var _mouse_captured: bool = false
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.35
var _all_drawers_open: bool = false


func _ready() -> void:
	print("=======================================================================")
	print("=== ESCAPARATE DE MOBILIARIO DE OFICINA PLAY SECTOR X (OFFICE PACK) ===")
	print("=======================================================================")

	_setup_lighting_and_environment()
	_rebuild_office_pack(false)


func _setup_lighting_and_environment() -> void:
	# Fondo oscuro idéntico a la imagen de referencia (#0d0e14)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.70, 0.78)
	env.ambient_light_energy = 0.90
	env_node.environment = env
	add_child(env_node)

	# Luz solar direccional de estudio equilibrada
	var sun := DirectionalLight3D.new()
	sun.name = "StudioSun"
	sun.rotation_degrees = Vector3(-42.0, 32.0, 0.0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.shadow_enabled = true
	add_child(sun)

	# Luz de relleno suave
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(20.0, -145.0, 0.0)
	fill.light_energy = 0.50
	fill.light_color = Color(0.70, 0.82, 0.95)
	add_child(fill)

	# Cámara de visualización ortogonal estilo renders isométricos
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 5.7
	_camera.position = Vector3(0.0, 4.4, 7.5)
	_camera.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
	add_child(_camera)
	_camera.make_current()


func _rebuild_office_pack(all_open: bool = false) -> void:
	if _engine != null:
		remove_child(_engine)
		_engine.queue_free()
		_engine = null

	_engine = ObjectEngineScript.new()
	_engine.name = "ShowcaseObjectEngine"
	add_child(_engine)

	var builder = _engine.get_builder()

	# Coordenadas de la cuadrícula 4x3 calibrada
	# Columnas X: -3.3, -1.1, 1.1, 3.3
	# Filas Z con espaciado amplio:
	#   Fila 1 (Z = -3.8): 4 Escritorios
	#   Fila 2 (Z =  0.0): 2 Sillas y Archivero (Cerrado y Abierto Vacío)
	#   Fila 3 (Z =  3.8): 2 Armarios y 2 Libreros
	var col_x := [-3.3, -1.1, 1.1, 3.3]
	var rot_isometric := Basis(Vector3.UP, deg_to_rad(24.0))

	# =========================================================================
	# FILA 1: ESCRITORIOS
	# =========================================================================
	var r1_z := -3.8
	var desk_params := {"is_open": true} if all_open else {}

	# 1. Escritorio Ejecutivo Doble Pedestal de Madera
	OfficeRecipesScript.OfficeDeskDoublePedestalRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[0], 0.0, r1_z)), desk_params)

	# 2. Escritorio Metálico Tanker
	OfficeRecipesScript.OfficeDeskMetalTankerRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[1], 0.0, r1_z)), desk_params)

	# 3. Escritorio Modular en L con Patas Azules
	OfficeRecipesScript.OfficeDeskLShapedRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[2], 0.0, r1_z)), desk_params)

	# 4. Escritorio Sencillo Patas Abiertas
	OfficeRecipesScript.OfficeDeskSinglePedestalRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[3], 0.0, r1_z)), desk_params)

	# =========================================================================
	# FILA 2: SILLAS Y ARCHIVEROS (MODELO ÚNICO UNIFICADO)
	# =========================================================================
	var r2_z := 0.0
	var rot_chair := Basis(Vector3.UP, deg_to_rad(-24.0))

	# 5. Silla Ergonómica Verde
	OfficeRecipesScript.OfficeChairGreenRecipe.build(builder, Transform3D(rot_chair, Vector3(col_x[0], 0.0, r2_z)))

	# 6. Silla Giratoria Roja Vintage
	OfficeRecipesScript.OfficeChairRedRecipe.build(builder, Transform3D(rot_chair, Vector3(col_x[1], 0.0, r2_z)))

	# 7. Archivero Vertical Metálico - Estado Cerrado
	var fc1_params := {"is_open": true} if all_open else {"is_open": false}
	OfficeRecipesScript.OfficeFileCabinetRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[2], 0.0, r2_z)), fc1_params)

	# 8. Archivero Vertical Metálico - Demostración Estado Abierto (100% Vacío, sin carpetas)
	OfficeRecipesScript.OfficeFileCabinetRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[3], 0.0, r2_z)), {"is_open": true})

	# =========================================================================
	# FILA 3: ARMARIOS Y LIBREROS
	# =========================================================================
	var r3_z := 3.8
	var cab_params := {"is_open": true} if all_open else {}

	# 9. Armario Alto de Madera 2 Puertas
	OfficeRecipesScript.OfficeCabinetTallRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[0], 0.0, r3_z)), cab_params)

	# 10. Mueble Bajo / Aparador de Madera 2 Puertas
	OfficeRecipesScript.OfficeCabinetLowRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[1], 0.0, r3_z)), cab_params)

	# 11. Librero Alto Abierto 5 Niveles
	OfficeRecipesScript.OfficeBookcaseTallRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[2], 0.0, r3_z)))

	# 12. Librero Bajo Abierto 2 Niveles
	OfficeRecipesScript.OfficeBookcaseLowRecipe.build(builder, Transform3D(rot_isometric, Vector3(col_x[3], 0.0, r3_z)))

	# Enviar toda la geometría al GPU en Hardware Instancing (+0 Draw Calls)
	_engine.commit()

	var stats := _engine.get_stats()
	print("✓ TELEMETRÍA CONFIRMADA DE OFFICE PACK:")
	print("- Total Piezas Geométricas: %d" % stats["total_instances"])
	print("- DRAW CALLS TOTALES PARA LA COLECCIÓN COMPLETA: %d" % stats["draw_calls"])
	print("- Primitivas en Hardware Instancing: %s" % str(stats["primitives_active"]))
	print("- Formas de Colisión Físicas: %d" % stats["collision_shapes"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_all_drawers_open = not _all_drawers_open
			print("Alternando estado interactivo de gavetas: Abierto=%s" % str(_all_drawers_open))
			_rebuild_office_pack(_all_drawers_open)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_mouse_captured = not _mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	if _mouse_captured and event is InputEventMouseMotion:
		_cam_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.4, 1.4)
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _process(delta: float) -> void:
	if not _mouse_captured or _camera == null:
		return

	var input_vec := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_vec.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_vec.z += 1.0
	if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
	if Input.is_key_pressed(KEY_E): input_vec.y += 1.0
	if Input.is_key_pressed(KEY_Q): input_vec.y -= 1.0

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else MOVE_SPEED
	var cam_basis := _camera.global_transform.basis
	var move_dir := (cam_basis * input_vec).normalized()
	_camera.global_position += move_dir * speed * delta
