extends Node3D
## Escena de Inspección y Generación de Tiendas de Conveniencia Procedurales (Play Sector X).
## Especializado en la cadena OTXO (CommercialConvenience - zone_type = 3).
##
## Al presionar la tecla [R], destruye la tienda actual y genera una nueva tienda procedural
## con semilla aleatoria, variando dimensiones y distribución (esquina con estacionamiento en L, frontal, etc.).
##
## Controles:
## [R] Generar nueva tienda procedural aleatoria
## [O] Rotar orientación urbana del predio (Norte, Este, Sur, Oeste)
## [T] Alternar visibilidad de techo (inspección interior / azotea)
## [L] Cambiar preset de dimensiones del lote (16x16, 18x16, 16x18, 14x16, 18x18)
## [1] o [F] Enfocar Fachada principal y acceso
## [2] o [P] Enfocar Tótem publicitario gigante OTXO
## [3] o [I] Enfocar Interior de la tienda (piso de venta)
## [4] o [C] Enfocar Costado / Vitrales laterales
## [0] o [Espacio] Vista aérea general
## [WASD + Click Derecho] Vuelo libre de cámara

const CityTextureManager = preload("res://world/city/city_texture_manager.gd")
const CommercialPropsBuilder = preload("res://world/building/commercial_props_builder.gd")
const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")

## Presets de dimensiones basados en estándares reales de franquicias de conveniencia OTXO (300 a 450 m²)
const LOT_DIMENSION_PRESETS: Array[Vector2i] = [
	Vector2i(15, 25), # 375 m² — Lote típico profundo OTXO (15m frente x 25m fondo, 5 autos en batería)
	Vector2i(15, 20), # 300 m² — Lote estándar OTXO (15m frente x 20m fondo, 4-5 autos en batería)
	Vector2i(16, 24), # 384 m² — Esquina OTXO estándar (16m frente x 24m fondo, doble estacionamiento en "L")
	Vector2i(18, 22), # 396 m² — Esquina amplia OTXO (18m frente x 22m fondo, alta afluencia vehicular)
	Vector2i(15, 30), # 450 m² — Lote profundo máximo OTXO (15m frente x 30m fondo, entre medianeras)
	Vector2i(18, 25), # 450 m² — Esquina máxima OTXO (18m frente x 25m fondo, bulevar y avenida)
]

var _engine = null
var _store_root: Node3D = null
var _ground_root: Node3D = null
var _camera: Camera3D = null

# Estado de generación
var _current_seed: int = 1009
var _preset_idx: int = 0
var _lot_width: int = 15
var _lot_depth: int = 25
var _show_roofs: bool = true
var _lot_orientation_deg: int = 0

# Datos de la tienda actual
var _last_gen_result: Dictionary = {}
var _last_comm_data: Dictionary = {}

# Variables de cámara
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.30
const CAM_MOVE_SPEED := 20.0
var _mouse_captured: bool = false

# UI Elements
var _hud_layer: CanvasLayer = null
var _stats_label: Label = null
var _banner_label: Label = null
var _banner_timer: float = 0.0

# Materiales reutilizables
var _mat_solid: StandardMaterial3D = null
var _mat_glass: StandardMaterial3D = null
var _mat_asphalt_lot: StandardMaterial3D = null
var _mat_asphalt_street: StandardMaterial3D = null


func _ready() -> void:
	if ClassDB.class_exists("ProceduralHouseEngine"):
		_engine = ClassDB.instantiate("ProceduralHouseEngine")
		print("[ProceduralStoreShowcase] ✓ ProceduralHouseEngine cargado con éxito.")
	else:
		printerr("[ProceduralStoreShowcase] ERROR: ProceduralHouseEngine no encontrado en ClassDB.")

	CityTextureManager.ensure_initialized()
	_init_shared_materials()
	_setup_environment()
	_setup_camera()
	_setup_ground()
	_setup_ui()

	# Generar primera tienda procedural
	_lot_width = LOT_DIMENSION_PRESETS[_preset_idx].x
	_lot_depth = LOT_DIMENSION_PRESETS[_preset_idx].y
	generate_store(_current_seed)
	_focus_facade()

	if DisplayServer.get_name() == "headless":
		_run_headless_verification()


func _init_shared_materials() -> void:
	# Material PBR sólido para estructura interna y muros
	_mat_solid = StandardMaterial3D.new()
	_mat_solid.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat_solid.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_mat_solid.vertex_color_use_as_albedo = true
	_mat_solid.roughness = 0.88
	_mat_solid.metallic = 0.05
	_mat_solid.cull_mode = BaseMaterial3D.CULL_BACK

	# Material PBR vidrio translúcido templado
	_mat_glass = StandardMaterial3D.new()
	_mat_glass.vertex_color_use_as_albedo = true
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glass.albedo_color = Color(0.25, 0.45, 0.65, 0.65)
	_mat_glass.roughness = 0.10
	_mat_glass.metallic = 0.30
	_mat_glass.cull_mode = BaseMaterial3D.CULL_BACK

	# Asfalto de estacionamiento (lote)
	_mat_asphalt_lot = StandardMaterial3D.new()
	_mat_asphalt_lot.albedo_color = Color(0.22, 0.23, 0.25)
	_mat_asphalt_lot.roughness = 0.92

	# Asfalto de calle periférica
	_mat_asphalt_street = StandardMaterial3D.new()
	_mat_asphalt_street.albedo_color = Color(0.16, 0.16, 0.17)
	_mat_asphalt_street.roughness = 0.95


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.48, 0.78)
	sky_mat.sky_horizon_color = Color(0.70, 0.82, 0.92)
	sky_mat.ground_bottom_color = Color(0.18, 0.20, 0.18)
	sky_mat.sun_angle_max = 30.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.64, 0.70)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Sol Direccional con sombras de alta definición
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.current = true
	_camera.fov = 68.0
	_camera.near = 0.15
	_camera.far = 250.0
	add_child(_camera)


func _setup_ground() -> void:
	if _ground_root == null:
		_ground_root = Node3D.new()
		_ground_root.name = "GroundRoot"
		add_child(_ground_root)

	_update_ground_geometry()


func _update_ground_geometry() -> void:
	for child in _ground_root.get_children():
		child.queue_free()

	# 1. Base de calle y contexto urbano general (85m x 85m)
	var street_mesh := PlaneMesh.new()
	street_mesh.size = Vector2(85.0, 85.0)
	var street_inst := MeshInstance3D.new()
	street_inst.name = "StreetBase"
	street_inst.mesh = street_mesh
	street_inst.position = Vector3(0.0, -0.02, 0.0)
	street_inst.material_override = _mat_asphalt_street
	_ground_root.add_child(street_inst)

	# 2. Placa de asfalto del predio comercial OTXO (exactamente W x D metros)
	var lot_mesh := BoxMesh.new()
	lot_mesh.size = Vector3(float(_lot_width), 0.04, float(_lot_depth))
	var lot_inst := MeshInstance3D.new()
	lot_inst.name = "LotAsphalt"
	lot_inst.mesh = lot_mesh
	lot_inst.position = Vector3(0.0, 0.0, 0.0)
	lot_inst.material_override = _mat_asphalt_lot
	_ground_root.add_child(lot_inst)

	# 3. Banqueta perimetral exterior al lote (guarnición de concreto delimitadora en la vía pública)
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.75, 0.75, 0.74)
	curb_mat.roughness = 0.90

	var curb_mesh := BoxMesh.new()
	var half_w := float(_lot_width) * 0.5
	var half_d := float(_lot_depth) * 0.5

	# Guarnición frontal exterior (Z = -half_d - 0.15)
	var curb_front := MeshInstance3D.new()
	var cm_f := BoxMesh.new()
	cm_f.size = Vector3(float(_lot_width) + 2.0, 0.16, 0.25)
	curb_front.mesh = cm_f
	curb_front.position = Vector3(0.0, 0.06, -half_d - 0.125)
	curb_front.material_override = curb_mat
	_ground_root.add_child(curb_front)

	# Guarnición lateral Oeste exterior (X = -half_w - 0.15)
	var curb_side := MeshInstance3D.new()
	var cm_s := BoxMesh.new()
	cm_s.size = Vector3(0.25, 0.16, float(_lot_depth) + 2.0)
	curb_side.mesh = cm_s
	curb_side.position = Vector3(-half_w - 0.125, 0.06, 0.0)
	curb_side.material_override = curb_mat
	_ground_root.add_child(curb_side)


## Genera una nueva tienda procedural destruyendo la existente
func generate_store(seed_val: int = -1, randomize_lot_size: bool = false) -> void:
	if seed_val == -1:
		_current_seed = int(randi() & 0x7FFFFFFF)
	else:
		_current_seed = seed_val

	if randomize_lot_size:
		_preset_idx = int(randi() % LOT_DIMENSION_PRESETS.size())
		_lot_width = LOT_DIMENSION_PRESETS[_preset_idx].x
		_lot_depth = LOT_DIMENSION_PRESETS[_preset_idx].y

	if _store_root == null:
		_store_root = Node3D.new()
		_store_root.name = "StoreRoot"
		add_child(_store_root)

	for child in _store_root.get_children():
		child.queue_free()

	if _engine == null:
		printerr("[ProceduralStoreShowcase] ERROR: _engine no está inicializado.")
		return

	_update_ground_geometry()

	# Generación procedural Rust de tienda de conveniencia OTXO (zone_type = 3)
	var res: Dictionary = _engine.generate_house(_lot_width, _lot_depth, 3, _current_seed, _show_roofs)
	if res.is_empty() or not res.has("solid_multimesh"):
		printerr("[ProceduralStoreShowcase] ERROR: generate_house retornó diccionario vacío.")
		return

	_last_gen_result = res
	var comm_data: Dictionary = res.get("commercial", {})
	_last_comm_data = comm_data
	var rooms_data: Array = res.get("rooms", [])

	var store_node := Node3D.new()
	store_node.name = "OTXO_Store_%d" % _current_seed
	store_node.position = Vector3(0.0, 0.16, 0.0)

	# 1. MultiMeshInstance3D de Fachada Exterior Amarilla OTXO con Texture2DArray compartido
	var ext_walls_mm: MultiMesh = res.get("ext_walls_multimesh", null)
	if ext_walls_mm:
		var ext_inst := MultiMeshInstance3D.new()
		ext_inst.name = "ExtWallsMultiMesh"
		ext_inst.multimesh = ext_walls_mm
		ext_inst.material_override = CityTextureManager.get_walls_shared_material()
		ext_inst.set_instance_shader_parameter("wall_layer", CityTextureManager.get_wall_layer("amarilla"))
		store_node.add_child(ext_inst)

	# 2. MultiMeshInstance3D de Columnas Arquitectónicas 3D y Basamentos en Gris Carbón
	var columns_mm: MultiMesh = res.get("columns_multimesh", null)
	if columns_mm:
		var col_inst := MultiMeshInstance3D.new()
		col_inst.name = "ColumnsMultiMesh"
		col_inst.multimesh = columns_mm
		col_inst.material_override = CityTextureManager.get_walls_shared_material()
		col_inst.set_instance_shader_parameter("wall_layer", CityTextureManager.get_wall_layer("gris"))
		store_node.add_child(col_inst)

	# 3. MultiMeshInstance3D Sólido (Interiores, marquesina superior roja, loseta de piso, pretiles)
	var solid_mm: MultiMesh = res.get("solid_multimesh", null)
	if solid_mm:
		var solid_inst := MultiMeshInstance3D.new()
		solid_inst.name = "SolidMultiMesh"
		solid_inst.multimesh = solid_mm
		solid_inst.material_override = _mat_solid
		store_node.add_child(solid_inst)

	# 4. MultiMeshInstance3D de Ventanales de Cristal Templado Translúcido
	var glass_mm: MultiMesh = res.get("glass_multimesh", null)
	if glass_mm:
		var glass_inst := MultiMeshInstance3D.new()
		glass_inst.name = "GlassMultiMesh"
		glass_inst.multimesh = glass_mm
		glass_inst.material_override = _mat_glass
		store_node.add_child(glass_inst)

	# 5. Cajas de Colisión Físicas (StaticBody3D)
	var col_boxes: Array = res.get("collision_boxes", [])
	if not col_boxes.is_empty():
		var col_body := StaticBody3D.new()
		col_body.name = "StoreCollision"
		for b_dict in col_boxes:
			var c_shape := CollisionShape3D.new()
			var b_shape := BoxShape3D.new()
			b_shape.size = b_dict.get("size", Vector3.ONE)
			c_shape.shape = b_shape
			c_shape.position = b_dict.get("position", Vector3.ZERO)
			col_body.add_child(c_shape)
		store_node.add_child(col_body)

	# 6. Props e Infraestructura Comercial (Tótem gigante, letrero marquesina, estacionamiento, bolardos, etc.)
	if not comm_data.is_empty():
		CommercialPropsBuilder.build_all_commercial_elements(
			store_node,
			comm_data,
			rooms_data,
			float(_lot_width),
			float(_lot_depth)
		)

	# 7. Árbol ornamental en esquina de banqueta pública (Regla estricta: Únicamente ProceduralTree)
	var sidewalk_tree := ProceduralTree.new()
	sidewalk_tree.name = "SidewalkTree"
	sidewalk_tree.profile_id = "classic_oak"
	sidewalk_tree.tree_seed = _current_seed + 777
	sidewalk_tree.cast_shadows = true
	sidewalk_tree.position = Vector3(float(_lot_width) * 0.5 + 2.5, 0.0, -float(_lot_depth) * 0.5 - 2.5)
	sidewalk_tree.scale = Vector3(0.75, 0.75, 0.75)
	store_node.add_child(sidewalk_tree)

	_store_root.add_child(store_node)
	_apply_lot_orientation()

	_update_stats_ui()
	_show_banner_message("¡Nueva Tienda OTXO Generada! (Semilla: %d | %dx%dm)" % [_current_seed, _lot_width, _lot_depth])


## Interacción y teclas
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseMotion and _mouse_captured:
		_cam_yaw -= event.relative.x * 0.003
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -1.45, 1.45)
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

	elif event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_R:
				# [R] REGLA PRINCIPAL: Crear / Regenerar nueva tienda procedural con semilla y tamaño aleatorio
				generate_store(-1, true)
			KEY_O:
				# [O] Ciclar orientación urbana del predio (0°, 90°, 180°, 270°)
				cycle_orientation(90)
			KEY_T:
				# [T] Alternar visibilidad de techo
				_show_roofs = not _show_roofs
				generate_store(_current_seed, false)
			KEY_L:
				# [L] Ciclar dimensiones de lote
				_preset_idx = (_preset_idx + 1) % LOT_DIMENSION_PRESETS.size()
				_lot_width = LOT_DIMENSION_PRESETS[_preset_idx].x
				_lot_depth = LOT_DIMENSION_PRESETS[_preset_idx].y
				generate_store(_current_seed, false)
			KEY_F, KEY_1:
				_focus_facade()
			KEY_P, KEY_2:
				_focus_totem()
			KEY_I, KEY_3:
				_focus_interior()
			KEY_C, KEY_4:
				_focus_lateral()
			KEY_0, KEY_SPACE:
				_focus_aerial()


func cycle_orientation(step: int = 90) -> void:
	_lot_orientation_deg = (_lot_orientation_deg + step) % 360
	_apply_lot_orientation()
	_update_stats_ui()
	_show_banner_message("Orientación del Predio: %d° (%s)" % [_lot_orientation_deg, _get_orientation_name(_lot_orientation_deg)])


func _apply_lot_orientation() -> void:
	var rot_rad := deg_to_rad(float(_lot_orientation_deg))
	if _store_root:
		_store_root.rotation.y = rot_rad
	if _ground_root:
		_ground_root.rotation.y = rot_rad


func _get_orientation_name(deg: int) -> String:
	match deg:
		0: return "Fachada Norte (0°)"
		90: return "Fachada Este (90°)"
		180: return "Fachada Sur (180°)"
		270: return "Fachada Oeste (270°)"
		_: return "%d°" % deg


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner_label != null:
			_banner_label.visible = false

	if not _mouse_captured:
		return

	var move_vec := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_vec -= _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_vec += _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_vec -= _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_vec += _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		move_vec += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		move_vec += Vector3.DOWN

	var speed := CAM_MOVE_SPEED * (2.2 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	_camera.position += move_vec.normalized() * speed * delta


# Presets de cámara para inspección
func _focus_facade() -> void:
	var half_d := float(_lot_depth) * 0.5
	_camera.position = Vector3(0.0, 2.5, -half_d - 6.5)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 1.8, -half_d + 4.5))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_totem() -> void:
	var totem_dict: Dictionary = _last_comm_data.get("totem_sign", {})
	var tpos: Vector3 = totem_dict.get("position", Vector3(-float(_lot_width) * 0.5 + 1.8, 0.0, -float(_lot_depth) * 0.5 + 1.8))
	var pole_h: float = clampf(float(totem_dict.get("height", 9.0)), 8.0, 10.0)
	# Colocar la cámara en la calle frente al tótem (Z negativo) con retroceso y elevación para encuadrar los 8-10m
	_camera.position = Vector3(tpos.x, 3.2, tpos.z - 7.5)
	_camera.look_at_from_position(_camera.position, Vector3(tpos.x, pole_h + 0.8, tpos.z))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_interior() -> void:
	# Dentro del piso de venta de la tienda
	_camera.position = Vector3(0.0, 1.6, 0.0)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 1.5, -float(_lot_depth) * 0.5 + 4.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_lateral() -> void:
	# Enfocar la fachada lateral (vitrina o muro de estacionamiento lateral)
	var lat_side: int = _last_comm_data.get("lateral_parking_side", 1)
	var half_w := float(_lot_width) * 0.5
	if lat_side == 2:
		# Lado Este
		_camera.position = Vector3(half_w + 7.5, 2.4, 0.0)
		_camera.look_at_from_position(_camera.position, Vector3(0.0, 1.8, 0.0))
	else:
		# Lado Oeste (por defecto en esquina)
		_camera.position = Vector3(-half_w - 7.5, 2.4, 0.0)
		_camera.look_at_from_position(_camera.position, Vector3(0.0, 1.8, 0.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_aerial() -> void:
	var half_w := float(_lot_width) * 0.5
	var half_d := float(_lot_depth) * 0.5
	_camera.position = Vector3(half_w + 16.0, 26.0, -half_d - 16.0)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 1.5, 2.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y


# Sistema de Interfaz Gráfica (HUD)
func _setup_ui() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUD"
	add_child(_hud_layer)

	# Panel Superior Derecho con Título y Estadísticas (Evita tapar el monitor FPS superior izquierdo)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -450.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = 230.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.90)
	style.set_corner_radius_all(10)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.08, 0.08, 0.90) # Borde Rojo OTXO
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_hud_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "🏪 PLAY SECTOR X — TIENDA PROCEDURAL OTXO"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.10))
	vbox.add_child(title)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.94))
	vbox.add_child(_stats_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var hints := Label.new()
	hints.text = "⌨️ [R] Nueva Tienda | [O] Orientación | [T] Techo | [L] Tamaño\n🎥 [F] Fachada | [P] Tótem | [I] Interior | [C] Costado | [0] Aérea\n🖱️ [WASD + Click Derecho] Vuelo Libre"
	hints.add_theme_font_size_override("font_size", 11)
	hints.add_theme_color_override("font_color", Color(0.72, 0.75, 0.80))
	vbox.add_child(hints)

	# Barra Inferior con Botones Interactivos
	var bottom_bar := HBoxContainer.new()
	bottom_bar.offset_left = 16.0
	bottom_bar.offset_top = -60.0
	bottom_bar.offset_right = 880.0
	bottom_bar.offset_bottom = -16.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.add_theme_constant_override("separation", 10)
	_hud_layer.add_child(bottom_bar)

	var btn_r := Button.new()
	btn_r.text = "🎲 Generar Tienda [R]"
	btn_r.pressed.connect(func(): generate_store(-1, true))
	bottom_bar.add_child(btn_r)

	var btn_o := Button.new()
	btn_o.text = "🔄 Orientación [O]"
	btn_o.pressed.connect(func(): cycle_orientation(90))
	bottom_bar.add_child(btn_o)

	var btn_t := Button.new()
	btn_t.text = "🏠 Techo [T]"
	btn_t.pressed.connect(func():
		_show_roofs = not _show_roofs
		generate_store(_current_seed)
	)
	bottom_bar.add_child(btn_t)

	var btn_l := Button.new()
	btn_l.text = "📐 Tamaño [L]"
	btn_l.pressed.connect(func():
		_preset_idx = (_preset_idx + 1) % LOT_DIMENSION_PRESETS.size()
		_lot_width = LOT_DIMENSION_PRESETS[_preset_idx].x
		_lot_depth = LOT_DIMENSION_PRESETS[_preset_idx].y
		generate_store(_current_seed)
	)
	bottom_bar.add_child(btn_l)

	var btn_f := Button.new()
	btn_f.text = "🏢 Fachada [F]"
	btn_f.pressed.connect(func(): _focus_facade())
	bottom_bar.add_child(btn_f)

	var btn_c := Button.new()
	btn_c.text = "🪟 Costado [C]"
	btn_c.pressed.connect(func(): _focus_lateral())
	bottom_bar.add_child(btn_c)

	var btn_totem := Button.new()
	btn_totem.text = "🚩 Tótem [P]"
	btn_totem.pressed.connect(func(): _focus_totem())
	bottom_bar.add_child(btn_totem)

	var btn_int := Button.new()
	btn_int.text = "🛒 Interior [I]"
	btn_int.pressed.connect(func(): _focus_interior())
	bottom_bar.add_child(btn_int)

	var btn_aer := Button.new()
	btn_aer.text = "✈️ Aérea [0]"
	btn_aer.pressed.connect(func(): _focus_aerial())
	bottom_bar.add_child(btn_aer)

	# Banner emergente de notificación
	_banner_label = Label.new()
	_banner_label.anchor_left = 0.5
	_banner_label.anchor_right = 0.5
	_banner_label.offset_left = -250.0
	_banner_label.offset_right = 250.0
	_banner_label.offset_top = 24.0
	_banner_label.offset_bottom = 60.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	bstyle.border_color = Color(0.98, 0.82, 0.10)
	bstyle.border_width_left = 2
	bstyle.border_width_right = 2
	bstyle.border_width_top = 2
	bstyle.border_width_bottom = 2
	bstyle.set_corner_radius_all(8)
	_banner_label.add_theme_stylebox_override("panel", bstyle)
	_banner_label.add_theme_font_size_override("font_size", 13)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_banner_label.visible = false
	_hud_layer.add_child(_banner_label)


func _update_stats_ui() -> void:
	if _stats_label == null:
		return

	var entrance_type: int = _last_comm_data.get("entrance_type", 0)
	var entrance_desc: String = "Centro de Fachada"
	match entrance_type:
		1: entrance_desc = "Esquina Comercial (junto a tótem/parking)"
		2: entrance_desc = "Desplazado Lateral"
		_: entrance_desc = "Centro de Fachada"

	var lat_side: int = _last_comm_data.get("lateral_parking_side", 0)
	var lat_corner_desc: String = "Lote Frontal Simple"
	if lat_side == 1:
		lat_corner_desc = "Esquina L (Calle Oeste + Frente)"
	elif lat_side == 2:
		lat_corner_desc = "Esquina L (Calle Este + Frente)"

	var has_showcase: bool = _last_comm_data.get("has_lateral_showcase", false)
	var showcase_desc: String = "Muro Ciego Comercial (Sin vitrina)"
	if has_showcase:
		showcase_desc = "Vitrales Panorámicos con Columnas 3D"

	var area_m2 := _lot_width * _lot_depth
	var num_bays: int = _last_comm_data.get("parking_bays", []).size()

	var text := "Semilla: %d | Orientación: %s\n" % [_current_seed, _get_orientation_name(_lot_orientation_deg)]
	text += "Predio OTXO: %dm frente x %dm fondo (%d m² | Estándar: 300-450 m²)\n" % [_lot_width, _lot_depth, area_m2]
	text += "Estacionamiento: %d cajones en batería (%s)\n" % [num_bays, lat_corner_desc]
	text += "Acceso: %s\n" % entrance_desc
	text += "Fachada Lateral: %s\n" % showcase_desc
	text += "Techos: %s\n" % ("Visibles (Azotea con Pretil)" if _show_roofs else "Ocultos (Ver Interior)")

	var total_instances := 0
	var col_shapes := 0

	var store_node = _store_root.get_node_or_null("OTXO_Store_%d" % _current_seed)
	if store_node:
		var ext_inst: MultiMeshInstance3D = store_node.get_node_or_null("ExtWallsMultiMesh")
		if ext_inst and ext_inst.multimesh:
			total_instances += ext_inst.multimesh.instance_count
		var col_inst: MultiMeshInstance3D = store_node.get_node_or_null("ColumnsMultiMesh")
		if col_inst and col_inst.multimesh:
			total_instances += col_inst.multimesh.instance_count
		var solid_inst: MultiMeshInstance3D = store_node.get_node_or_null("SolidMultiMesh")
		if solid_inst and solid_inst.multimesh:
			total_instances += solid_inst.multimesh.instance_count
		var glass_inst: MultiMeshInstance3D = store_node.get_node_or_null("GlassMultiMesh")
		if glass_inst and glass_inst.multimesh:
			total_instances += glass_inst.multimesh.instance_count

		var col_body: StaticBody3D = store_node.get_node_or_null("StoreCollision")
		if col_body:
			col_shapes = col_body.get_child_count()

	text += "Instancias GPU: %d cubos/cilindros | Colisiones: %d" % [total_instances, col_shapes]
	_stats_label.text = text


func _show_banner_message(msg: String) -> void:
	if _banner_label == null:
		return
	_banner_label.text = msg
	_banner_label.visible = true
	_banner_timer = 2.8


func _run_headless_verification() -> void:
	print("--- VERIFICACIÓN HEADLESS SHOWCASE TIENDA PROCEDURAL ---")
	print("Semilla inicial: ", _current_seed)
	assert(_store_root != null, "_store_root es nulo")
	assert(_store_root.get_child_count() > 0, "No se generó la tienda procedural")
	print("✓ Tienda inicial generada exitosamente con ", _store_root.get_child_count(), " nodo(s).")

	# Simular pulsación de la tecla 'R' (Regeneración de tienda con nueva semilla)
	print("Simulando tecla [R] para generar nueva tienda procedural...")
	var old_seed := _current_seed
	generate_store(-1, true)
	assert(_current_seed != old_seed, "La semilla no cambió al regenerar")
	assert(_store_root.get_child_count() > 0, "No se generó la nueva tienda procedural tras regeneración")
	print("✓ Nueva tienda procedural generada con éxito (Nueva Semilla: %d)." % _current_seed)
	print("✓ VERIFICACIÓN HEADLESS COMPLETADA CON ÉXITO.")
