extends Node3D
## Escena de prueba e inspección de Casas Procedurales en Intersección en Cruz (Play Sector X).
## Muestra una calle en cruz con esquinas habitadas por casas procedurales:
## - NW: Colonia Vieja (Barrio tradicional, pared con pared)
## - NE: Colonia Nueva (Fraccionamiento / Infonavit, pasillo de servicio)
## - SW: Colonia Vieja / Mixto
## - SE: Zona X (Residencia de lujo contemporánea con jardín perimetral)
##
## Controles:
## [R] Generar nuevas semillas aleatorias para todas las casas
## [T] Alternar visibilidad de techos (inspección de arquitectura interior)
## [Z] Ciclar modo de zona (Mixto, Pura Colonia Vieja, Pura Colonia Nueva, Pura Zona X)
## [1, 2, 3, 4] Enfocar esquinas NW, NE, SW, SE
## [0 o Espacio] Vista aérea general
## [WASD + Click Derecho] Vuelo libre de cámara

const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")
const ElectricMeterScript = preload("res://world/electricity/electric_meter.gd")
const ElectricServicePillarScript = preload("res://world/electricity/electric_service_pillar.gd")
const WallDecalSystem = preload("res://world/city/wall_decal_system.gd")
const CityTextureManager = preload("res://world/city/city_texture_manager.gd")
const WindowGrilleSystem = preload("res://world/building/window_grille_system.gd")
const DiningSetScript = preload("res://world/furniture/dining_set.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const ApplianceRefrigeratorScript = preload("res://world/furniture/appliance_refrigerator.gd")
const ApplianceStoveScript = preload("res://world/furniture/appliance_stove.gd")
const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")
const HouseFurniturePlannerScript = preload("res://world/furniture/house_furniture_planner.gd")
const StairModuleScript = preload("res://world/building/stair_module.gd")
const CommercialPropsBuilder = preload("res://world/building/commercial_props_builder.gd")

## Texturas exteriores de fachada para paredes de afuera (archivos *_ext.png)
const EXT_WALL_TEXTURE_PATHS: Array[String] = [
	"res://assets/textures/house/pared_amarilla_ext_seamless.png",
	"res://assets/textures/house/pared_azul_ext_seamless.png",
	"res://assets/textures/house/pared_blanca_ext_seamless.png",
	"res://assets/textures/house/pared_cremita_ext_seamless.png",
	"res://assets/textures/house/pared_gris_ext_seamless.png"
]

var _ext_materials: Array[Material] = []

## Grafitis urbanos (grandes y pequeños)
const LARGE_GRAFFITI_PATHS: Array[String] = [
	"res://assets/textures/house/grafiti.png",
	"res://assets/textures/house/grafiti2.png",
	"res://assets/textures/house/grafiti3.png",
	"res://assets/textures/house/grafiti4.png",
	"res://assets/textures/house/grafiti5.png"
]

const SMALL_GRAFFITI_PATHS: Array[String] = [
	"res://assets/textures/house/grafiti_peque.png",
	"res://assets/textures/house/grafiti_peque2.png",
	"res://assets/textures/house/grafiti_peque3.png"
]

## Desgaste y desprendimiento de pintura (pared desgastada / pintura desprendida)
const WORN_WALL_PATHS: Array[String] = [
	"res://assets/textures/house/pared_desgastada2.png",
	"res://assets/textures/house/pared_desgastada3.png",
	"res://assets/textures/house/pared_desgastada4.png",
	"res://assets/textures/house/pared_desgastada5.png",
	"res://assets/textures/house/pared_desgastada6.png",
	"res://assets/textures/house/pared_desgastada7.png",
	"res://assets/textures/house/pintura_desgastada.png"
]

var _large_graffiti_materials: Array[StandardMaterial3D] = []
var _small_graffiti_materials: Array[StandardMaterial3D] = []
var _worn_wall_materials: Array[StandardMaterial3D] = []

enum ZoneMode {
	MIXED = 0,
	ALL_COLONIA_VIEJA = 1,
	ALL_COLONIA_NUEVA = 2,
	ALL_ZONA_X = 3,
	ALL_COMMERCIAL = 4
}

var _engine = null
var _houses_root: Node3D
var _street_root: Node3D
var _electrical_root: Node3D
var _camera: Camera3D
var _info_label: Label
var _stats_label: Label
var ui_canvas: CanvasLayer = null
var _nw_house_data: Dictionary = {}

var _show_roofs: bool = true
var _zone_mode: ZoneMode = ZoneMode.MIXED
var _global_seed: int = 1009
var _corner_seeds: Array[int] = [
	1009, 2018, 3027, 4036,
	5045, 6054, 7063, 8072, 9081,
	1111, 2222, 3333, 4444, 5555, 6666
]

# Variables de cámara
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.45
const CAM_MOVE_SPEED := 24.0
var _mouse_captured: bool = false
var is_capture_mode: bool = false

# Definición de parcelas en cuadrícula entera (1m x 1m) en las 4 esquinas de la intersección
# Incluye manzanas con vecinos traseros (lotes adosados espalda con espalda)
var _parcels_config: Array[Dictionary] = []


func _ready() -> void:
	if ClassDB.class_exists("ProceduralHouseEngine"):
		_engine = ClassDB.instantiate("ProceduralHouseEngine")
		print("[CrossStreetShowcase] ✓ ProceduralHouseEngine cargado con éxito.")
	else:
		printerr("[CrossStreetShowcase] ERROR: ProceduralHouseEngine no encontrado en ClassDB.")

	_init_parcel_definitions()
	_setup_environment()
	_setup_camera()
	_setup_street_geometry()
	_setup_houses()
	_setup_ui()

	if DisplayServer.get_name() == "headless" and not is_capture_mode:
		_run_headless_verification()


func _init_parcel_definitions() -> void:
	# Sistema Métrico Discreto Entero (1m x 1m):
	# - Arroyo vehicular: 8m de ancho (X/Z entre -4.0 y +4.0)
	# - Banqueta de concreto: 3m de ancho (entre |X|=4 y |X|=7, |Z|=4 y |Z|=7)
	# - Lotes urbanos: Comienzan exactamente en |X| >= 7 y |Z| >= 7
	# - Manzanas con profundidad para casas espalda con espalda ("Vecinos Traseros")
	_parcels_config = [
		# =====================================================================
		# --- ESQUINA 1: NOROESTE (NW) - COLONIA VIEJA (Barrio Tradicional) ---
		# =====================================================================
		# Frente a la calle principal (Sur, frente_side = 2)
		{
			"corner_name": "NW - Lote Esquina Frente",
			"rect": Rect2(-17.0, -23.0, 10.0, 16.0),
			"front_side": 2, # Frente a calle en Z = -7
			"default_zone": 0, # ColoniaVieja
			"lot_color": Color(0.38, 0.35, 0.30)
		},
		{
			"corner_name": "NW - Lote Adosado Frente",
			"rect": Rect2(-26.0, -23.0, 9.0, 16.0), # Pared con pared al oeste
			"front_side": 2,
			"default_zone": 0,
			"lot_color": Color(0.35, 0.32, 0.28)
		},
		# Vecinos traseros (Espalda con espalda, comparten linde posterior en Z = -23.0)
		{
			"corner_name": "NW - Vecino Trasero Esquina",
			"rect": Rect2(-17.0, -39.0, 10.0, 16.0),
			"front_side": 0, # Frente a calle trasera en Z = -39
			"default_zone": 0,
			"lot_color": Color(0.36, 0.33, 0.29)
		},
		{
			"corner_name": "NW - Vecino Trasero Adosado",
			"rect": Rect2(-26.0, -39.0, 9.0, 16.0),
			"front_side": 0,
			"default_zone": 0,
			"lot_color": Color(0.34, 0.31, 0.27)
		},

		# =====================================================================
		# --- ESQUINA 2: NORESTE (NE) - COLONIA NUEVA (Infonavit Serializado) -
		# =====================================================================
		# Manzana de casas serializadas de 7m x 15m con pasillo lateral
		{
			"corner_name": "NE - Infonavit Esquina",
			"rect": Rect2(7.0, -22.0, 7.0, 15.0),
			"front_side": 2, # Frente a calle en Z = -7
			"default_zone": 1, # ColoniaNueva
			"lot_color": Color(0.32, 0.36, 0.40)
		},
		{
			"corner_name": "NE - Infonavit Lote 2",
			"rect": Rect2(14.0, -22.0, 7.0, 15.0),
			"front_side": 2,
			"default_zone": 1,
			"lot_color": Color(0.30, 0.34, 0.38)
		},
		{
			"corner_name": "NE - Infonavit Lote 3",
			"rect": Rect2(21.0, -22.0, 7.0, 15.0),
			"front_side": 2,
			"default_zone": 1,
			"lot_color": Color(0.28, 0.32, 0.36)
		},
		{
			"corner_name": "NE - Infonavit Lote 4",
			"rect": Rect2(28.0, -22.0, 7.0, 15.0),
			"front_side": 2,
			"default_zone": 1,
			"lot_color": Color(0.31, 0.35, 0.39)
		},
		# Vecinos traseros Infonavit (Comparten barda de patio trasero en Z = -22.0)
		{
			"corner_name": "NE - Infonavit Trasero 1",
			"rect": Rect2(7.0, -37.0, 7.0, 15.0),
			"front_side": 0,
			"default_zone": 1,
			"lot_color": Color(0.31, 0.35, 0.39)
		},
		{
			"corner_name": "NE - Infonavit Trasero 2",
			"rect": Rect2(14.0, -37.0, 7.0, 15.0),
			"front_side": 0,
			"default_zone": 1,
			"lot_color": Color(0.29, 0.33, 0.37)
		},
		{
			"corner_name": "NE - Infonavit Trasero 3",
			"rect": Rect2(21.0, -37.0, 7.0, 15.0),
			"front_side": 0,
			"default_zone": 1,
			"lot_color": Color(0.28, 0.32, 0.36)
		},
		{
			"corner_name": "NE - Infonavit Trasero 4",
			"rect": Rect2(28.0, -37.0, 7.0, 15.0),
			"front_side": 0,
			"default_zone": 1,
			"lot_color": Color(0.30, 0.34, 0.38)
		},

		# =====================================================================
		# --- ESQUINA 3: SUROESTE (SW) - TIENDA COMERCIAL OTXO / MIXTO --------
		# =====================================================================
		{
			"corner_name": "SW - Tienda OTXO",
			"rect": Rect2(-23.0, 7.0, 16.0, 16.0),
			"front_side": 0, # Frente a calle en Z = +7
			"default_zone": 3, # CommercialConvenience (OTXO)
			"lot_color": Color(0.24, 0.24, 0.26) # Asfalto oscuro de estacionamiento
		},
		{
			"corner_name": "SW - Adosado Sur",
			"rect": Rect2(-26.0, 7.0, 3.0, 16.0),
			"front_side": 0,
			"default_zone": 0,
			"lot_color": Color(0.34, 0.32, 0.28)
		},
		# Vecinos traseros al sur (Comparten linde en Z = +23.0)
		{
			"corner_name": "SW - Vecino Trasero Sur 1",
			"rect": Rect2(-17.0, 23.0, 10.0, 16.0),
			"front_side": 2, # Frente a calle sur en Z = +39
			"default_zone": 0,
			"lot_color": Color(0.35, 0.33, 0.29)
		},
		{
			"corner_name": "SW - Vecino Trasero Sur 2",
			"rect": Rect2(-26.0, 23.0, 9.0, 16.0),
			"front_side": 2,
			"default_zone": 0,
			"lot_color": Color(0.33, 0.31, 0.27)
		},

		# =====================================================================
		# --- ESQUINA 4: SURESTE (SE) - ZONA X (Residencias de Lujo) ----------
		# =====================================================================
		{
			"corner_name": "SE - Mansión Zona X",
			"rect": Rect2(7.0, 7.0, 18.0, 20.0),
			"front_side": 0, # Frente a calle en Z = +7
			"default_zone": 2, # ZonaX
			"lot_color": Color(0.26, 0.30, 0.34)
		},
		{
			"corner_name": "SE - Residencia Contemporánea",
			"rect": Rect2(25.0, 7.0, 14.0, 20.0),
			"front_side": 0,
			"default_zone": 2, # ZonaX
			"lot_color": Color(0.28, 0.32, 0.36)
		}
	]


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.46, 0.72)
	sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.84, 0.82, 0.80)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Sol con sombras nítidas
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 42.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.90)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 58.0
	_camera.near = 0.2
	_camera.far = 500.0
	_focus_overview()
	add_child(_camera)


func _setup_street_geometry() -> void:
	_street_root = Node3D.new()
	_street_root.name = "StreetIntersection"
	add_child(_street_root)

	# 1. Terreno base circundante
	var ground := MeshInstance3D.new()
	var ground_plane := PlaneMesh.new()
	ground_plane.size = Vector2(200.0, 200.0)
	ground.mesh = ground_plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.26, 0.30, 0.20)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	_street_root.add_child(ground)

	# 2. Arroyo vehicular de Asfalto (Cruz de 8m de ancho: de -4.0 a +4.0)
	var asphalt_mat := StandardMaterial3D.new()
	asphalt_mat.albedo_color = Color(0.18, 0.19, 0.20)
	asphalt_mat.roughness = 0.88

	# Tramo transversal Este-Oeste (Eje X)
	var road_x := MeshInstance3D.new()
	var road_x_mesh := BoxMesh.new()
	road_x_mesh.size = Vector3(100.0, 0.04, 8.0)
	road_x.mesh = road_x_mesh
	road_x.material_override = asphalt_mat
	road_x.position = Vector3(0.0, 0.02, 0.0)
	_street_root.add_child(road_x)

	# Tramo longitudinal Norte-Sur (Eje Z)
	var road_z := MeshInstance3D.new()
	var road_z_mesh := BoxMesh.new()
	road_z_mesh.size = Vector3(8.0, 0.04, 100.0)
	road_z.mesh = road_z_mesh
	road_z.material_override = asphalt_mat
	road_z.position = Vector3(0.0, 0.02, 0.0)
	_street_root.add_child(road_z)

	# 3. Señalización vial
	var yellow_mat := StandardMaterial3D.new()
	yellow_mat.albedo_color = Color(0.92, 0.76, 0.14)
	yellow_mat.roughness = 0.70

	var line_arms := [
		Vector3(0.0, 0.05, -28.0),
		Vector3(0.0, 0.05, 28.0),
		Vector3(-28.0, 0.05, 0.0),
		Vector3(28.0, 0.05, 0.0)
	]
	var line_sizes := [
		Vector3(0.16, 0.01, 38.0),
		Vector3(0.16, 0.01, 38.0),
		Vector3(38.0, 0.01, 0.16),
		Vector3(38.0, 0.01, 0.16)
	]
	for idx in range(4):
		var y_line := MeshInstance3D.new()
		var y_box := BoxMesh.new()
		y_box.size = line_sizes[idx]
		y_line.mesh = y_box
		y_line.material_override = yellow_mat
		y_line.position = line_arms[idx]
		_street_root.add_child(y_line)

	# 4. Pasos Peatonales (Cebras blancas)
	var white_mat := StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.90, 0.90, 0.90)
	white_mat.roughness = 0.65

	for z_pos in [-5.5, 5.5]:
		for stripe in range(6):
			var stripe_x := -3.0 + float(stripe) * 1.2
			var cebra := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(0.55, 0.01, 1.8)
			cebra.mesh = c_box
			cebra.material_override = white_mat
			cebra.position = Vector3(stripe_x, 0.05, z_pos)
			_street_root.add_child(cebra)

	for x_pos in [-5.5, 5.5]:
		for stripe in range(6):
			var stripe_z := -3.0 + float(stripe) * 1.2
			var cebra := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(1.8, 0.01, 0.55)
			cebra.mesh = c_box
			cebra.material_override = white_mat
			cebra.position = Vector3(x_pos, 0.05, stripe_z)
			_street_root.add_child(cebra)

	# 5. Banquetas de concreto de 3m de ancho (de |X,Z|=4 a |X,Z|=7 y borde exterior)
	var sidewalk_mat := StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.68, 0.66, 0.62)
	sidewalk_mat.roughness = 0.90

	var corners := [
		Vector3(-25.5, 0.08, -25.5), # NW
		Vector3(25.5, 0.08, -25.5),  # NE
		Vector3(-25.5, 0.08, 25.5),  # SW
		Vector3(25.5, 0.08, 25.5)   # SE
	]
	for c_pos in corners:
		var sw := MeshInstance3D.new()
		var sw_box := BoxMesh.new()
		sw_box.size = Vector3(43.0, 0.16, 43.0)
		sw.mesh = sw_box
		sw.material_override = sidewalk_mat
		sw.position = c_pos
		_street_root.add_child(sw)


func _init_ext_materials() -> void:
	if not _ext_materials.is_empty():
		return
	var shader := load("res://assets/building/wall_exterior_triplanar.gdshader") as Shader
	for path in EXT_WALL_TEXTURE_PATHS:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var tex: Texture2D
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path):
			tex = load(path)
		mat.set_shader_parameter("wall_texture", tex)
		mat.set_shader_parameter("uv_scale", 0.32)
		mat.set_shader_parameter("sharpness", 3.0)
		mat.set_shader_parameter("roughness", 0.90)
		_ext_materials.append(mat)


func _init_graffiti_materials() -> void:
	if not _large_graffiti_materials.is_empty() and not _small_graffiti_materials.is_empty():
		return
	_large_graffiti_materials.clear()
	for path in LARGE_GRAFFITI_PATHS:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.92
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			mat.albedo_texture = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path):
			mat.albedo_texture = load(path)
		_large_graffiti_materials.append(mat)

	_small_graffiti_materials.clear()
	for path in SMALL_GRAFFITI_PATHS:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.92
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			mat.albedo_texture = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path):
			mat.albedo_texture = load(path)
		_small_graffiti_materials.append(mat)


func _init_worn_wall_materials() -> void:
	if not _worn_wall_materials.is_empty():
		return
	_worn_wall_materials.clear()
	for path in WORN_WALL_PATHS:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.95
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			mat.albedo_texture = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(path):
			mat.albedo_texture = load(path)
		_worn_wall_materials.append(mat)


func _setup_houses() -> void:
	if _houses_root == null:
		_houses_root = Node3D.new()
		_houses_root.name = "CornerHouses"
		add_child(_houses_root)

	regenerate_houses()


## Regenera todas las casas de las esquinas usando ProceduralHouseEngine
func regenerate_houses() -> void:
	_nw_house_data.clear()
	for child in _houses_root.get_children():
		child.queue_free()

	if _engine == null:
		printerr("[CrossStreetShowcase] ERROR: ProceduralHouseEngine es nulo.")
		return

	CityTextureManager.ensure_initialized()
	FurnitureTextureManagerScript.ensure_initialized()

	var neighborhood_furniture := FurnitureMultiMeshSystemScript.new()
	neighborhood_furniture.name = "NeighborhoodFurniture"
	_houses_root.add_child(neighborhood_furniture)

	# Materiales compartidos para MultiMeshInstance3D (GPU Instancing)
	var mat_solid := StandardMaterial3D.new()
	mat_solid.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_solid.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_solid.vertex_color_use_as_albedo = true
	mat_solid.roughness = 0.88
	mat_solid.metallic = 0.05
	mat_solid.cull_mode = BaseMaterial3D.CULL_BACK # Cubos 100% sólidos cerrados con normales hacia afuera

	var mat_glass := StandardMaterial3D.new()
	mat_glass.vertex_color_use_as_albedo = true
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.albedo_color = Color(0.25, 0.45, 0.65, 0.65)
	mat_glass.roughness = 0.10
	mat_glass.metallic = 0.30
	mat_glass.cull_mode = BaseMaterial3D.CULL_BACK

	for i in range(_parcels_config.size()):
		var p_cfg: Dictionary = _parcels_config[i]
		var rect: Rect2 = p_cfg["rect"]
		var front_side: int = p_cfg["front_side"]
		var house_seed: int = _corner_seeds[i % _corner_seeds.size()]

		var zone_type: int
		match _zone_mode:
			ZoneMode.ALL_COLONIA_VIEJA:
				zone_type = 0
			ZoneMode.ALL_COLONIA_NUEVA:
				zone_type = 1
			ZoneMode.ALL_ZONA_X:
				zone_type = 2
			ZoneMode.ALL_COMMERCIAL:
				zone_type = 3
			_:
				zone_type = p_cfg["default_zone"]

		# 1. Marcador visual del lote
		_add_lot_ground_marker(rect, p_cfg["lot_color"])

		# 2. Determinar dimensiones y orientación según front_side
		var w: int = int(rect.size.x)
		var d: int = int(rect.size.y)
		var rot_y: float = 0.0

		match front_side:
			0: # Frente hacia -Z (Norte)
				rot_y = 0.0
			1: # Frente hacia +X (Este)
				rot_y = -PI * 0.5
				w = int(rect.size.y)
				d = int(rect.size.x)
			2: # Frente hacia +Z (Sur)
				rot_y = PI
			3: # Frente hacia -X (Oeste)
				rot_y = PI * 0.5
				w = int(rect.size.y)
				d = int(rect.size.x)

		# 3. Generar casa con el motor procedural Rust (1m x 1m grid, GPU Instancing)
		var res: Dictionary = _engine.generate_house(w, d, zone_type, house_seed, _show_roofs)
		if res.is_empty() or not res.has("solid_multimesh"):
			continue

		var house_node := Node3D.new()
		house_node.name = "House_%d_%s" % [i, p_cfg["corner_name"].replace(" ", "_")]
		house_node.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.16, rect.position.y + rect.size.y * 0.5)
		house_node.rotation.y = rot_y

		if i == 0:
			_nw_house_data = {
				"res": res,
				"transform": house_node.transform,
				"w": float(w),
				"d": float(d),
			}

		# 4a. MultiMeshInstance3D de Paredes Exteriores con Texture2DArray compartido (CityTextureManager)
		var ext_walls_mm: MultiMesh = res.get("ext_walls_multimesh", null)
		if ext_walls_mm:
			var ext_inst := MultiMeshInstance3D.new()
			ext_inst.name = "ExtWallsMultiMesh"
			ext_inst.multimesh = ext_walls_mm
			var layer_idx: int
			if zone_type == 3:
				layer_idx = CityTextureManager.get_wall_layer("amarilla")
			else:
				var wall_keys := CityTextureManager.get_all_wall_keys()
				var wall_key: String = wall_keys[int((house_seed ^ (house_seed >> 5)) & 0x7FFFFFFF) % wall_keys.size()]
				layer_idx = CityTextureManager.get_wall_layer(wall_key)
			ext_inst.material_override = CityTextureManager.get_walls_shared_material()
			ext_inst.set_instance_shader_parameter("wall_layer", layer_idx)
			house_node.add_child(ext_inst)

		# 4b. MultiMeshInstance3D Sólido (Estructura interna: muros interiores, pisos, techos, marcos)
		var solid_mm: MultiMesh = res.get("solid_multimesh", null)
		if solid_mm:
			var solid_inst := MultiMeshInstance3D.new()
			solid_inst.name = "SolidMultiMesh"
			solid_inst.multimesh = solid_mm
			solid_inst.material_override = mat_solid
			house_node.add_child(solid_inst)

		# MultiMeshInstance3D de Cristales (1 Draw Call GPU para ventanas translúcidas)
		var glass_mm: MultiMesh = res.get("glass_multimesh", null)
		if glass_mm:
			var glass_inst := MultiMeshInstance3D.new()
			glass_inst.name = "GlassMultiMesh"
			glass_inst.multimesh = glass_mm
			glass_inst.material_override = mat_glass
			house_node.add_child(glass_inst)

		# MultiMeshInstance3D de Columnas Estructurales y Basamentos (1 Draw Call GPU con textura gris concreto)
		var columns_mm: MultiMesh = res.get("columns_multimesh", null)
		if columns_mm:
			var col_inst := MultiMeshInstance3D.new()
			col_inst.name = "ColumnsMultiMesh"
			col_inst.multimesh = columns_mm
			col_inst.material_override = CityTextureManager.get_walls_shared_material()
			col_inst.set_instance_shader_parameter("wall_layer", CityTextureManager.get_wall_layer("gris"))
			house_node.add_child(col_inst)

		# 5. Cajas de colisión físicas (StaticBody3D)
		var col_boxes: Array = res.get("collision_boxes", [])
		if not col_boxes.is_empty():
			var col_body := StaticBody3D.new()
			col_body.name = "HouseCollision"
			for b_dict in col_boxes:
				var c_shape := CollisionShape3D.new()
				var b_shape := BoxShape3D.new()
				b_shape.size = b_dict.get("size", Vector3.ONE)
				c_shape.shape = b_shape
				c_shape.position = b_dict.get("position", Vector3.ZERO)
				col_body.add_child(c_shape)
			house_node.add_child(col_body)

		# 5b. Puerta frontal texturizada con WoodenDoor (solamente casas residenciales, no comercios)
		var door_data: Array = res.get("doors", [])
		var main_door_dict: Dictionary = {}
		for door_entry in door_data:
			if door_entry.get("is_main", false):
				main_door_dict = door_entry
				break
		if main_door_dict.is_empty() and not door_data.is_empty():
			main_door_dict = door_data[0]

		if not main_door_dict.is_empty() and zone_type != 3:
			var door_pos: Vector3 = main_door_dict.get("position", Vector3.ZERO)
			var door_size: Vector3 = main_door_dict.get("size", Vector3(0.85, 2.10, 0.06))
			var door_rot_y: float = main_door_dict.get("rotation_y", 0.0)

			var door_node := WoodenDoor.new()
			door_node.name = "FrontDoor"
			door_node.door_width = door_size.x
			door_node.door_height = door_size.y
			door_node.door_thickness = door_size.z
			door_node.door_style = 0 # Primera textura de puerta ("wood_door.png" / door_0.png)
			door_node.position = door_pos
			door_node.rotation.y = door_rot_y
			house_node.add_child(door_node)

		# 5c. Sistema Centralizado de Detalles de Pared con GPU Instancing (CityTextureManager)
		var wall_details: Array = res.get("wall_details", [])
		if not wall_details.is_empty():
			var decals_inst := CityTextureManager.create_house_decals_multimesh(wall_details)
			if decals_inst:
				house_node.add_child(decals_inst)

		# 5d. Protecciones de Herrería para Ventanas (WindowGrilleSystem, omitir en comercios)
		var windows_data: Array = res.get("windows", [])
		if not windows_data.is_empty() and zone_type != 3:
			var grilles := WindowGrilleSystem.build_house_grilles(windows_data, house_seed, zone_type)
			if grilles:
				house_node.add_child(grilles)

		# 5e. Módulo de Escalera Normalizada (para casas de 2 pisos con núcleo procedural)
		if res.has("stair"):
			var s_data: Dictionary = res["stair"]
			var stair_node := StairModuleScript.new()
			stair_node.name = "HouseStair"
			var s_type: int = s_data.get("type", 0)
			var s_ori: int = s_data.get("orientation", 0)
			var s_x: float = float(s_data.get("x", 0.0))
			var s_z: float = float(s_data.get("z", 0.0))
			var s_w: float = float(s_data.get("width", 1.0))
			var s_l: float = float(s_data.get("length", 3.0))

			stair_node.stair_type = s_type
			stair_node.orientation = s_ori
			stair_node.stair_width = 0.88 if zone_type != 2 else 0.95
			stair_node.straight_length = s_l
			stair_node.target_height = 3.40 if zone_type == 2 else 2.80
			stair_node.material_style = StairModuleScript.MaterialStyle.DARK_OAK if zone_type == 2 else StairModuleScript.MaterialStyle.WOOD
			stair_node.railing_left = true
			stair_node.railing_right = true
			stair_node.add_upper_guardrails = true

			# Detección de muros exteriores colindantes para aplicar retranqueo (inset) anti-z-fighting:
			# Los muros exteriores miden 0.20m de grosor. El inset de 0.12m separa la escalera para que
			# jamás atraviese la fachada exterior de la vivienda.
			var b_f1: PackedByteArray = res.get("room_map_floor1", PackedByteArray())
			var grid_w: int = int(w)
			var grid_d: int = int(d)
			var ix: int = int(s_x)
			var iz: int = int(s_z)

			var ext_west: bool = (ix == 0) or (not b_f1.is_empty() and ix > 0 and b_f1[iz * grid_w + (ix - 1)] == 0)
			var ext_east: bool = (ix + int(s_w) >= grid_w) or (not b_f1.is_empty() and ix + int(s_w) < grid_w and b_f1[iz * grid_w + (ix + int(s_w))] == 0)
			var ext_north: bool = (iz == 0) or (not b_f1.is_empty() and iz > 0 and b_f1[(iz - 1) * grid_w + ix] == 0)
			var ext_south: bool = (iz + int(s_l) >= grid_d) or (not b_f1.is_empty() and iz + int(s_l) < grid_d and b_f1[(iz + int(s_l)) * grid_w + ix] == 0)

			var inset_offset: float = 0.12
			var inset_x: float = (inset_offset if ext_west else (-inset_offset if ext_east else 0.0))
			var inset_z: float = (inset_offset if ext_north else (-inset_offset if ext_south else 0.0))

			var sx: float = 0.0
			var sz: float = 0.0
			if s_type == StairModuleScript.StairType.L_SHAPE:
				# La huella en L de 2x2m está centrada en (0, 0)
				sx = s_x + 1.0 - float(w) * 0.5 + inset_x
				sz = s_z + 1.0 - float(d) * 0.5 + inset_z
			else:
				sx = s_x + s_w * 0.5 - float(w) * 0.5 + inset_x
				sz = s_z - float(d) * 0.5 + (inset_z if ext_north else 0.0)

			stair_node.position = Vector3(sx, 0.0, sz)
			house_node.add_child(stair_node)

		# 6. Árbol en patio trasero o jardín frontal vía ProceduralTree (Regla estricta: NO FBX)
		if zone_type == 0:
			# Colonia Vieja: Limonero / árbol de sombra en patio trasero
			var tree := ProceduralTree.new()
			tree.profile_id = "classic_oak"
			tree.tree_seed = house_seed + 101
			tree.cast_shadows = true
			tree.position = Vector3(0.0, 0.0, float(d) * 0.35)
			tree.scale = Vector3(0.7, 0.7, 0.7)
			house_node.add_child(tree)
		elif zone_type == 2:
			# Zona X: Árbol ornamental en jardín
			var tree := ProceduralTree.new()
			tree.profile_id = "autumn_birch"
			tree.tree_seed = house_seed + 202
			tree.cast_shadows = true
			tree.position = Vector3(float(w) * 0.35, 0.0, -float(d) * 0.35)
			tree.scale = Vector3(0.85, 0.85, 0.85)
			house_node.add_child(tree)

		# 7. Mobiliario Interior Procedural: Habitaciones amuebladas según su función arquitectónica
		var rooms_data: Array = res.get("rooms", [])
		var house_basis := Basis(Vector3.UP, rot_y)
		var floor_h: float = 3.40 if zone_type == 2 else 2.80

		for r_dict in rooms_data:
			var r_name: String = r_dict.get("name", "")
			var r_floor: int = int(r_dict.get("floor", 1))
			var floor_y_offset: float = 0.0 if r_floor == 1 else floor_h

			if r_name == "Comedor" and r_floor == 1:
				var dining_plan: Dictionary = HouseFurniturePlannerScript.plan_dining_set(res, r_dict, float(w), float(d))
				var local_pos: Vector3 = dining_plan["position"]
				local_pos.y += floor_y_offset
				var dining_global_pos := house_node.position + house_basis * local_pos
				var dining_rot_basis := house_basis * Basis(Vector3.UP, float(dining_plan["rotation_y"]))
				var dining_t := Transform3D(dining_rot_basis, dining_global_pos)
				var finish_choice: int = int((house_seed ^ (house_seed >> 3)) & 0x7FFFFFFF) % 4
				neighborhood_furniture.add_dining_set(dining_t, finish_choice, 4)

			elif r_name == "Cocina" and r_floor == 1:
				var kitchen_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_kitchen_furniture(res, r_dict, float(w), float(d))
				for item in kitchen_items:
					var scr = item["script"]
					var lpos: Vector3 = item["position"]
					lpos.y += floor_y_offset
					var item_global_pos := house_node.position + house_basis * lpos
					var item_rot_basis := house_basis * Basis(Vector3.UP, float(item["rotation_y"]))
					var item_t := Transform3D(item_rot_basis, item_global_pos)
					neighborhood_furniture.add_furniture_by_script(scr, item_t, item)

			elif r_name == "Sala":
				var living_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_living_room_furniture(res, r_dict, float(w), float(d), house_seed)
				for item in living_items:
					var scr = item["script"]
					var lpos: Vector3 = item["position"]
					lpos.y += floor_y_offset
					var item_global_pos := house_node.position + house_basis * lpos
					var item_rot_basis := house_basis * Basis(Vector3.UP, float(item["rotation_y"]))
					var item_t := Transform3D(item_rot_basis, item_global_pos)
					neighborhood_furniture.add_furniture_by_script(scr, item_t, item)

			elif r_name == "Lavandería":
				var laundry_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_laundry_furniture(res, r_dict, float(w), float(d))
				for item in laundry_items:
					var scr = item["script"]
					var lpos: Vector3 = item["position"]
					lpos.y += floor_y_offset
					var item_global_pos := house_node.position + house_basis * lpos
					var item_rot_basis := house_basis * Basis(Vector3.UP, float(item["rotation_y"]))
					var item_t := Transform3D(item_rot_basis, item_global_pos)
					neighborhood_furniture.add_furniture_by_script(scr, item_t, item)

			elif r_name == "Baño":
				var bathroom_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_bathroom_furniture(res, r_dict, float(w), float(d), house_seed)
				for item in bathroom_items:
					var scr = item["script"]
					var lpos: Vector3 = item["position"]
					lpos.y += floor_y_offset
					var item_global_pos := house_node.position + house_basis * lpos
					var item_rot_basis := house_basis * Basis(Vector3.UP, float(item["rotation_y"]))
					var item_t := Transform3D(item_rot_basis, item_global_pos)
					neighborhood_furniture.add_furniture_by_script(scr, item_t, item)

			elif r_name == "Recámara":
				var bedroom_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_bedroom_furniture(res, r_dict, float(w), float(d), house_seed)
				for item in bedroom_items:
					var scr = item["script"]
					var lpos: Vector3 = item["position"]
					lpos.y += floor_y_offset
					var item_global_pos := house_node.position + house_basis * lpos
					var item_rot_basis := house_basis * Basis(Vector3.UP, float(item["rotation_y"]))
					var item_t := Transform3D(item_rot_basis, item_global_pos)
					neighborhood_furniture.add_furniture_by_script(scr, item_t, item)

			elif r_name == "Estudio/Biblioteca":
				var studio_items: Array[Dictionary] = HouseFurniturePlannerScript.plan_studio_furniture(res, r_dict, float(w), float(d), house_seed)
				for item in studio_items:
					var scr = item["script"]
					var lpos: Vector3 = item["position"]
					lpos.y += floor_y_offset
					var item_global_pos := house_node.position + house_basis * lpos
					var item_rot_basis := house_basis * Basis(Vector3.UP, float(item["rotation_y"]))
					var item_t := Transform3D(item_rot_basis, item_global_pos)
					neighborhood_furniture.add_furniture_by_script(scr, item_t, item)

		# 8. Infraestructura Comercial OTXO (Tótem, Letrero de Fachada, Estacionamiento, Bolardos, etc.)
		var comm_data: Dictionary = res.get("commercial", {})
		if not comm_data.is_empty():
			CommercialPropsBuilder.build_all_commercial_elements(house_node, comm_data, rooms_data, float(w), float(d))

		_houses_root.add_child(house_node)

	neighborhood_furniture.build(true)
	_setup_electrical_infrastructure()
	_update_stats_ui()


## Configura la infraestructura de acometida eléctrica (Medidores CFE, Mufas y Pilares con Switches)
func _setup_electrical_infrastructure() -> void:
	if _electrical_root != null:
		_electrical_root.queue_free()

	_electrical_root = Node3D.new()
	_electrical_root.name = "ElectricalInfrastructure"
	add_child(_electrical_root)

	# =========================================================================
	# REGLA 1 & 2 DEL USUARIO (INFONAVIT NE):
	# 1) Las mufas NO deben salir a la banqueta. Están a la orilla del lote,
	#    pero completamente dentro del terreno (Z <= -7.0), sin invadir la banqueta.
	#    Con Z = -7.24, el medidor queda en Z = -7.002 (justo al ras del predio).
	# 2) Las mufas compartidas atienden a pares de casas contiguas (Casa 1-2, Casa 3-4).
	#    - Casa 1 y Casa 2 comparten la Mufa 1 en su lindero común (X = 14.0).
	#    - Casa 2 NO comparte con Casa 3 (ya tiene su medidor en el Pilar 1).
	#    - En X = 21.0 (entre Casa 2 y Casa 3) NO HAY MUFA.
	#    - Casa 3 y Casa 4 comparten la Mufa 2 en su lindero común (X = 28.0).
	# =========================================================================
	# Pilar 1: Entre Infonavit Lote 1 y Lote 2 en X = 14.0, Z = -7.24 (a la orilla del lote)
	var pillar_ne_1 := ElectricServicePillarScript.new()
	pillar_ne_1.name = "Pillar_NE_Shared_1_2"
	pillar_ne_1.pillar_mode = ElectricServicePillarScript.PillarMode.SHARED_DUAL
	pillar_ne_1.house_id_top = "NE_Infonavit_Lote1"
	pillar_ne_1.house_id_bottom = "NE_Infonavit_Lote2"
	pillar_ne_1.position = Vector3(14.0, 0.16, -7.24)
	pillar_ne_1.rotation.y = 0.0 # Carátulas hacia el sur (+Z, viendo hacia la calle)
	_electrical_root.add_child(pillar_ne_1)

	# [Lindero X = 21.0 entre Lote 2 y Lote 3: SIN MUFA]
	# Casa 2 ya tiene su medidor asignado en el Pilar 1.

	# Pilar 2: Entre Infonavit Lote 3 y Lote 4 en X = 28.0, Z = -7.24 (a la orilla del lote)
	var pillar_ne_2 := ElectricServicePillarScript.new()
	pillar_ne_2.name = "Pillar_NE_Shared_3_4"
	pillar_ne_2.pillar_mode = ElectricServicePillarScript.PillarMode.SHARED_DUAL
	pillar_ne_2.house_id_top = "NE_Infonavit_Lote3"
	pillar_ne_2.house_id_bottom = "NE_Infonavit_Lote4"
	pillar_ne_2.position = Vector3(28.0, 0.16, -7.24)
	pillar_ne_2.rotation.y = 0.0 # Carátulas hacia el sur (+Z, viendo hacia la calle)
	_electrical_root.add_child(pillar_ne_2)

	# =========================================================================
	# REGLA: Casa Vieja pegada a la banqueta (Colonia Vieja NW)
	# Medidor incrustado dinámicamente en tramo sólido de fachada (NUNCA en ventanas ni puertas)
	# =========================================================================
	var meter_pos := Vector3(-13.8, 1.55, -7.06)
	var switch_pos := Vector3(-13.35, 1.55, -7.06)
	var meter_rot := 0.0

	if not _nw_house_data.is_empty():
		var meter_plan: Dictionary = HouseFurniturePlannerScript.find_safe_facade_meter_position(
			_nw_house_data["res"],
			_nw_house_data["transform"],
			_nw_house_data["w"],
			_nw_house_data["d"]
		)
		meter_pos = meter_plan["meter_world_pos"]
		switch_pos = meter_plan["switch_world_pos"]
		meter_rot = meter_plan["rotation_y"]

	var embedded_meter := ElectricMeterScript.new()
	embedded_meter.name = "Meter_NW_WallEmbedded"
	embedded_meter.meter_id = "CFE-EMBED-NW01"
	embedded_meter.assigned_house_id = "NW_ColoniaVieja_Lote1"
	embedded_meter.installation_type = ElectricMeterScript.InstallationType.WALL_EMBEDDED
	embedded_meter.position = meter_pos
	embedded_meter.rotation.y = meter_rot
	_electrical_root.add_child(embedded_meter)

	# Switch de seguridad montado en fachada junto al medidor incrustado (garantizado en pared sólida)
	embedded_meter.build_switch_box(_electrical_root, switch_pos, meter_rot)

	# =========================================================================
	# REGLA: Casa de ricos / aislada (Mansión Contemporánea Zona X SE)
	# Mufa y pilar individual exclusivo para esa sola casa, en la orilla del lote.
	# Banqueta en Z <= 7.0, lote en Z >= 7.0.
	# Con Z = 7.24 (rotado 180°), el medidor queda en Z = 7.002 (sin invadir la banqueta).
	# =========================================================================
	var pillar_se := ElectricServicePillarScript.new()
	pillar_se.name = "Pillar_SE_ZonaX_Mono"
	pillar_se.pillar_mode = ElectricServicePillarScript.PillarMode.SINGLE_MONO
	pillar_se.house_id_top = "SE_ZonaX_Mansion"
	pillar_se.position = Vector3(7.5, 0.16, 7.24)
	pillar_se.rotation.y = PI # Carátula hacia el norte (-Z, hacia la banqueta y calle)
	_electrical_root.add_child(pillar_se)


func _add_lot_ground_marker(rect: Rect2, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	marker.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	marker.material_override = mat
	marker.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.17, rect.position.y + rect.size.y * 0.5)
	_houses_root.add_child(marker)


## Presionar [R] para asignar semillas aleatorias a todas las casas
func randomize_all_seeds() -> void:
	_global_seed = randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = _global_seed
	for i in range(_corner_seeds.size()):
		_corner_seeds[i] = rng.randi()
	regenerate_houses()


func _setup_ui() -> void:
	ui_canvas = CanvasLayer.new()
	add_child(ui_canvas)
	if is_capture_mode:
		ui_canvas.visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 620.0
	panel.offset_bottom = 240.0
	ui_canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_info_label = Label.new()
	_info_label.text = "PSX - NUEVO MOTOR PROCEDURAL DE CASAS (CUADRÍCULA 1M)\n[R] Semillas Aleatorias | [T] Alternar Techos | [Z] Cambiar Zona\n[1] Esquina NW | [2] Esquina NE | [3] Esquina SW | [4] Esquina SE | [0] Vista Aérea\n[WASD + Click Derecho] Volar libremente"
	_info_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_info_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	vbox.add_child(_stats_label)

	# Fila de botones interactivos
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var btn_rand := Button.new()
	btn_rand.text = "🎲 Randomizar [R]"
	btn_rand.pressed.connect(func(): randomize_all_seeds())
	hbox.add_child(btn_rand)

	var btn_roof := Button.new()
	btn_roof.text = "🏠 Techos [T]"
	btn_roof.pressed.connect(func():
		_show_roofs = not _show_roofs
		regenerate_houses()
	)
	hbox.add_child(btn_roof)

	var btn_zone := Button.new()
	btn_zone.text = "🏙️ Zona [Z]"
	btn_zone.pressed.connect(func():
		_zone_mode = ((_zone_mode + 1) % 5) as ZoneMode
		regenerate_houses()
	)
	hbox.add_child(btn_zone)

	var btn_cam0 := Button.new()
	btn_cam0.text = "✈️ Aérea [0]"
	btn_cam0.pressed.connect(func(): _focus_overview())
	hbox.add_child(btn_cam0)

	_update_stats_ui()


func _update_stats_ui() -> void:
	if _stats_label == null:
		return

	var zone_str := "Mixto Urbano"
	match _zone_mode:
		ZoneMode.ALL_COLONIA_VIEJA: zone_str = "Pura Colonia Vieja (Pared con pared)"
		ZoneMode.ALL_COLONIA_NUEVA: zone_str = "Pura Colonia Nueva (Infonavit)"
		ZoneMode.ALL_ZONA_X: zone_str = "Pura Zona X (Mansiones de Lujo)"
		ZoneMode.ALL_COMMERCIAL: zone_str = "Puro OTXO (Tienda de Conveniencia)"

	var text := "Semilla: %d | Modo Zona: %s\n" % [_global_seed, zone_str]
	text += "Techos: %s | Lotes y Vecinos Traseros: %d\n" % [
		"VISIBLES (Azoteas con Pretil y Tinaco)" if _show_roofs else "OCULTOS (Inspección Interior)",
		_parcels_config.size()
	]

	var houses := _houses_root.get_children().filter(func(c): return c.name.begins_with("House_"))
	var total_instances := 0
	var total_decal_instances := 0
	var total_collision_shapes := 0
	for h in houses:
		var ext_inst: MultiMeshInstance3D = h.get_node_or_null("ExtWallsMultiMesh")
		if ext_inst != null and ext_inst.multimesh != null:
			total_instances += ext_inst.multimesh.instance_count
		var solid_inst: MultiMeshInstance3D = h.get_node_or_null("SolidMultiMesh")
		if solid_inst != null and solid_inst.multimesh != null:
			total_instances += solid_inst.multimesh.instance_count
		var glass_inst: MultiMeshInstance3D = h.get_node_or_null("GlassMultiMesh")
		if glass_inst != null and glass_inst.multimesh != null:
			total_instances += glass_inst.multimesh.instance_count
		var decal_inst: MultiMeshInstance3D = h.get_node_or_null("WallDecalsMultiMesh")
		if decal_inst != null and decal_inst.multimesh != null:
			total_decal_instances += decal_inst.multimesh.instance_count
		var col_body: StaticBody3D = h.get_node_or_null("HouseCollision")
		if col_body != null:
			total_collision_shapes += col_body.get_child_count()

	var furniture_sys = _houses_root.get_node_or_null("NeighborhoodFurniture")
	var total_furn_count: int = furniture_sys.get_total_furniture_count() if furniture_sys != null and furniture_sys.has_method("get_total_furniture_count") else 0
	var furn_dc: int = furniture_sys.get_active_multimesh_count() if furniture_sys != null and furniture_sys.has_method("get_active_multimesh_count") else 0
	if furniture_sys != null:
		var furn_col = furniture_sys.get_node_or_null("FurnitureCollision")
		if furn_col is StaticBody3D:
			total_collision_shapes += furn_col.get_child_count()

	text += "Motor: Rust MultiMesh GPU | Cubos 3D: %d | Calcas: %d | Muebles GPU: %d en %d Draw Calls | Colisiones: %d" % [
		total_instances, total_decal_instances, total_furn_count, furn_dc, total_collision_shapes
	]
	_stats_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseMotion and _mouse_captured:
		_cam_yaw -= event.relative.x * 0.003
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.003, -1.45, 1.45)
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				randomize_all_seeds()
			KEY_T:
				_show_roofs = not _show_roofs
				regenerate_houses()
			KEY_Z:
				_zone_mode = ((_zone_mode + 1) % 4) as ZoneMode
				regenerate_houses()
			KEY_1:
				_focus_nw()
			KEY_2:
				_focus_ne()
			KEY_3:
				_focus_sw()
			KEY_4:
				_focus_se()
			KEY_0, KEY_SPACE:
				_focus_overview()


func _process(delta: float) -> void:
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


# Preset de cámaras
func _focus_overview() -> void:
	_camera.position = Vector3(32.0, 32.0, 42.0)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 2.0, 0.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_nw() -> void:
	_camera.position = Vector3(-16.0, 7.5, 4.0)
	_camera.look_at_from_position(_camera.position, Vector3(-17.0, 3.0, -18.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_ne() -> void:
	_camera.position = Vector3(14.0, 7.0, 4.0)
	_camera.look_at_from_position(_camera.position, Vector3(15.0, 3.0, -18.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_sw() -> void:
	_camera.position = Vector3(-16.0, 7.5, -4.0)
	_camera.look_at_from_position(_camera.position, Vector3(-17.0, 3.0, 18.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y

func _focus_se() -> void:
	_camera.position = Vector3(14.0, 8.5, -4.0)
	_camera.look_at_from_position(_camera.position, Vector3(18.0, 3.5, 18.0))
	_cam_pitch = _camera.rotation.x
	_cam_yaw = _camera.rotation.y


func _run_headless_verification() -> void:
	print("--- VERIFICACIÓN HEADLESS CALLE EN CRUZ CON CASAS PROCEDURALES ---")
	print("Parcelas configuradas: ", _parcels_config.size())
	print("Casas generadas en _houses_root: ", _houses_root.get_child_count())
	assert(_houses_root.get_child_count() > 0, "No se generaron casas")
	print("✓ Verificación headless completada con éxito.")
