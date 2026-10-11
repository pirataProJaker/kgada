extends Node3D
## Escena de Exhibición y Catálogo de Tipos de Calles Procedurales de Play Sector X.
## Muestra todos los tipos de calles y avenidas actuales en bahías de inspección lado a lado,
## junto con un demostrador interactivo que demuestra cómo el largo se adapta
## automáticamente al tamaño de la manzana sin ninguna medida fija o hardcodeada.

const RoadTrajectorySystem = preload("res://world/city/road_trajectory_system.gd")
const CityRoadPatterns = preload("res://world/city/city_road_patterns.gd")
const PROCEDURAL_TREE_SCRIPT = preload("res://world/procedural_trees/procedural_tree.gd")
const Sedan80sScript = preload("res://vehicles/models/sedan_80s/sedan_80s.gd")

class StreetShowcaseInfo:
	var id: String
	var name: String
	var category_title: String
	var lanes_description: String
	var roadway_width: float
	var sidewalk_left: float
	var sidewalk_right: float
	var median_width: float
	var median_type: String
	var total_footprint: float
	var camera_focus_pos: Vector3
	var description: String

var _catalog_road_system: RoadTrajectorySystem
var _interactive_road_system: RoadTrajectorySystem
var _catalog_decor_root: Node3D
var _catalog_vehicles_root: Node3D
var _interactive_decor_root: Node3D
var _interactive_vehicles_root: Node3D
var _interactive_lot_box: MeshInstance3D

var _camera: Camera3D
var _sun: DirectionalLight3D
var _world_env: WorldEnvironment

# UI
var _canvas: CanvasLayer
var _bottom_panel: PanelContainer
var _bottom_lbl: Label
var _current_focus_index: int = 0
var _street_infos: Array[StreetShowcaseInfo] = []

# Cámara libre
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.45
const CAM_MOVE_SPEED: float = 35.0
const CAM_TURBO_MULT: float = 2.5
var _mouse_captured: bool = false
var is_capture_mode: bool = false

# Manzana interactiva elástica
var interactive_block_length: float = 80.0
const MIN_BLOCK_LEN: float = 30.0
const MAX_BLOCK_LEN: float = 160.0
const STEP_BLOCK_LEN: float = 10.0


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_roots()
	_setup_ui()

	_build_catalog_streets()
	_build_interactive_block()

	_update_ui_info(0)

	if DisplayServer.get_name() == "headless" and not is_capture_mode:
		_run_headless_verification()


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.42, 0.68)
	sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.86)
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.70, 0.74, 0.80)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	_sun.light_color = Color(1.0, 0.98, 0.93)
	_sun.light_energy = 1.3
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.02
	add_child(_sun)

	# Suelo verde natural circundante
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 500.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.38, 0.20)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	ground.position.y = -0.02
	add_child(ground)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.current = true
	_camera.fov = 65.0
	_camera.position = Vector3(0.0, 35.0, 95.0)
	_cam_yaw = 0.0
	_cam_pitch = -0.42
	_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	add_child(_camera)

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = true


func _setup_roots() -> void:
	_catalog_road_system = RoadTrajectorySystem.new()
	_catalog_road_system.name = "CatalogRoadSystem"
	add_child(_catalog_road_system)

	_catalog_decor_root = Node3D.new()
	_catalog_decor_root.name = "CatalogDecorations"
	add_child(_catalog_decor_root)

	_catalog_vehicles_root = Node3D.new()
	_catalog_vehicles_root.name = "CatalogVehicles"
	add_child(_catalog_vehicles_root)

	_interactive_road_system = RoadTrajectorySystem.new()
	_interactive_road_system.name = "InteractiveRoadSystem"
	add_child(_interactive_road_system)

	_interactive_decor_root = Node3D.new()
	_interactive_decor_root.name = "InteractiveDecorations"
	add_child(_interactive_decor_root)

	_interactive_vehicles_root = Node3D.new()
	_interactive_vehicles_root.name = "InteractiveVehicles"
	add_child(_interactive_vehicles_root)

	_interactive_lot_box = MeshInstance3D.new()
	_interactive_lot_box.name = "InteractiveLotSurface"
	_interactive_decor_root.add_child(_interactive_lot_box)


func _spawn_showcase_car(parent: Node3D, pos: Vector3, yaw_deg: float) -> BaseVehicleController:
	var car := Sedan80sScript.new()
	car.freeze = true # Congelado para estabilidad de visualización en exhibición
	parent.add_child(car)
	car.position = pos
	car.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	return car


# ==============================================================================
# CONSTRUCCIÓN DE LAS BAHÍAS DEL CATÁLOGO VIAL
# ==============================================================================

func _build_catalog_streets() -> void:
	_catalog_road_system.clear()
	for child in _catalog_decor_root.get_children():
		child.queue_free()
	for child in _catalog_vehicles_root.get_children():
		child.queue_free()
	_street_infos.clear()

	_catalog_road_system.begin_batch()

	var z_start: float = -45.0
	var z_end: float = 45.0

	# BAHÍA 1: Bulevar Dividido con Camellón Arbolado (X = -150.0)
	_build_bay_divided_boulevard(-150.0, z_start, z_end)

	# BAHÍA 2: Bulevar con Arroyo / Parkway Natural (X = -105.0)
	_build_bay_stream_parkway(-105.0, z_start, z_end)

	# BAHÍA 3: Avenida de 6 Carriles con Camellón Arbolado 2.0m (X = -65.0)
	_build_bay_divided_median_3lane(-65.0, z_start, z_end)

	# BAHÍA 4: Avenida de 6 Carriles con Macetas Cuadradas 2.0m (X = -25.0)
	_build_bay_divided_median_planters(-25.0, z_start, z_end)

	# BAHÍA 5: Avenida Comercial Principal de 4 Carriles (X = +14.0)
	_build_bay_commercial_avenue(+14.0, z_start, z_end)

	# BAHÍA 6: Calle Residencial Estándar de 2 Sentidos (X = +42.0)
	_build_bay_residential_standard(+42.0, z_start, z_end)

	# BAHÍA 7: Calle Residencial Angosta / Callejón (X = +68.0)
	_build_bay_residential_narrow(+68.0, z_start, z_end)

	# BAHÍA 8: Carretera Rural Libre (X = +94.0)
	_build_bay_rural_road(+94.0, z_start, z_end)

	_catalog_road_system.end_batch()


## Bahía 1: Bulevar Dividido
func _build_bay_divided_boulevard(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = 13.0 # 3 carriles de 4.0m netos + pintura de división y orillas = 13.0m
	var m_w: float = 8.0  # Camellón central de 8m
	var sw_w: float = 3.0 # Banqueta exterior
	var x_west := center_x - (m_w * 0.5 + r_w * 0.5)
	var x_east := center_x + (m_w * 0.5 + r_w * 0.5)

	# Calzada Oeste (sentido Sur, +Z)
	var ep_w0 := _catalog_road_system.add_endpoint(Vector3(x_west, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var ep_w1 := _catalog_road_system.add_endpoint(Vector3(x_west, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var seg_w := _catalog_road_system.connect_endpoints(ep_w0.id, ep_w1.id, r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	_catalog_road_system.set_sidewalk(seg_w.id, false, true, sw_w) # Exterior
	_catalog_road_system.set_sidewalk(seg_w.id, true, false, 0.5)  # Interior camellón

	# Calzada Este (sentido Norte, -Z)
	var ep_e0 := _catalog_road_system.add_endpoint(Vector3(x_east, 0.0, z1), Vector3(0.0, 0.0, -1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var ep_e1 := _catalog_road_system.add_endpoint(Vector3(x_east, 0.0, z0), Vector3(0.0, 0.0, -1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var seg_e := _catalog_road_system.connect_endpoints(ep_e0.id, ep_e1.id, r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	_catalog_road_system.set_sidewalk(seg_e.id, false, true, sw_w) # Exterior
	_catalog_road_system.set_sidewalk(seg_e.id, true, false, 0.5)  # Interior camellón

	# Cruce central transversal / retorno
	var mid_z := (z0 + z1) * 0.5
	var ep_cw := _catalog_road_system.add_endpoint(Vector3(x_west, 0.0, mid_z), Vector3(1.0, 0.0, 0.0), 7.50, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var ep_ce := _catalog_road_system.add_endpoint(Vector3(x_east, 0.0, mid_z), Vector3(1.0, 0.0, 0.0), 7.50, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var seg_c := _catalog_road_system.connect_endpoints(ep_cw.id, ep_ce.id, 7.50, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	_catalog_road_system.set_both_sidewalks(seg_c.id, false, false)

	# Camellón central verde con árboles procedurales
	_create_median_strip(_catalog_decor_root, center_x, z0, mid_z - 4.5, m_w, "trees", 12.0)
	_create_median_strip(_catalog_decor_root, center_x, mid_z + 4.5, z1, m_w, "trees", 12.0)

	# Postes de luz de gran avenida / bulevar (Tono Metal CFE con óxido ocasional)
	_catalog_road_system.spawn_streetlights(_catalog_decor_root, null, seg_w.id)
	_catalog_road_system.spawn_streetlights(_catalog_decor_root, null, seg_e.id)

	# Autos de demostración dentro del carril
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(x_west, 0.05, 0.0), 180.0) # Calzada Oeste, carril central hacia el Sur
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(x_east, 0.05, -12.0), 0.0) # Calzada Este, carril central hacia el Norte

	# Cartel 3D
	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "1. BULEVAR DIVIDIDO", "2 calzadas de 13.0m (3 carriles c/u)\nCamellón arbolado 8m | Huella total: 40m")

	var info := StreetShowcaseInfo.new()
	info.id = "divided_boulevard"
	info.name = "Bulevar Dividido Clásico"
	info.category_title = "VÍA PRIMARIA METROPOLITANA"
	info.lanes_description = "2 Calzadas x 3 Carriles (4.0m netos + pintura) = 6 Carriles"
	info.roadway_width = 26.0
	info.sidewalk_left = 3.0
	info.sidewalk_right = 3.0
	info.median_width = 8.0
	info.median_type = "Pasto verde del mundo al nivel de banqueta con Árboles Procedurales"
	info.total_footprint = 40.0
	info.camera_focus_pos = Vector3(center_x, 8.5, 20.0)
	info.description = "Avenida insignia de alta velocidad y flujo masivo. Separa sentidos de circulación con un camellón arbolado central para seguridad y estética urbana."
	_street_infos.append(info)


## Bahía 2: Bulevar con Arroyo / Parkway
func _build_bay_stream_parkway(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = 13.0 # 3 carriles de 4.0m netos + pintura = 13.0m
	var m_w: float = 16.0 # Arroyo central de 16m
	var sw_w: float = 3.0
	var x_west := center_x - (m_w * 0.5 + r_w * 0.5)
	var x_east := center_x + (m_w * 0.5 + r_w * 0.5)

	# Calzada Oeste (sentido Sur)
	var ep_w0 := _catalog_road_system.add_endpoint(Vector3(x_west, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var ep_w1 := _catalog_road_system.add_endpoint(Vector3(x_west, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var seg_w := _catalog_road_system.connect_endpoints(ep_w0.id, ep_w1.id, r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	_catalog_road_system.set_sidewalk(seg_w.id, false, true, sw_w)
	_catalog_road_system.set_sidewalk(seg_w.id, true, false, 0.5)

	# Calzada Este (sentido Norte)
	var ep_e0 := _catalog_road_system.add_endpoint(Vector3(x_east, 0.0, z1), Vector3(0.0, 0.0, -1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var ep_e1 := _catalog_road_system.add_endpoint(Vector3(x_east, 0.0, z0), Vector3(0.0, 0.0, -1.0), r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	var seg_e := _catalog_road_system.connect_endpoints(ep_e0.id, ep_e1.id, r_w, RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE)
	_catalog_road_system.set_sidewalk(seg_e.id, false, true, sw_w)
	_catalog_road_system.set_sidewalk(seg_e.id, true, false, 0.5)

	# Puente central conectando ambos márgenes
	var mid_z := (z0 + z1) * 0.5
	var ep_cw := _catalog_road_system.add_endpoint(Vector3(x_west, 0.0, mid_z), Vector3(1.0, 0.0, 0.0), 7.50, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var ep_ce := _catalog_road_system.add_endpoint(Vector3(x_east, 0.0, mid_z), Vector3(1.0, 0.0, 0.0), 7.50, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var seg_c := _catalog_road_system.connect_endpoints(ep_cw.id, ep_ce.id, 7.50, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	_catalog_road_system.set_both_sidewalks(seg_c.id, true, true, 2.0)

	# Canal / Arroyo natural en el camellón
	_create_stream_strip(_catalog_decor_root, center_x, z0, mid_z - 4.5, m_w)
	_create_stream_strip(_catalog_decor_root, center_x, mid_z + 4.5, z1, m_w)

	# Autos de demostración dentro del carril
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(x_west, 0.05, 0.0), 180.0) # Calzada Oeste hacia el Sur
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(x_east, 0.05, -12.0), 0.0) # Calzada Este hacia el Norte

	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "2. BULEVAR CON ARROYO", "2 calzadas de 13.0m (3 carriles c/u)\nCauce natural 16m con agua | Huella: 48m")

	var info := StreetShowcaseInfo.new()
	info.id = "stream_parkway"
	info.name = "Bulevar Parkway Fluvial"
	info.category_title = "AVENIDA PAISAJÍSTICA"
	info.lanes_description = "2 Calzadas x 3 Carriles (4.0m netos + pintura) = 6 Carriles"
	info.roadway_width = 26.0
	info.sidewalk_left = 3.0
	info.sidewalk_right = 3.0
	info.median_width = 16.0
	info.median_type = "Arroyo natural con agua, piedra y taludes de pasto"
	info.total_footprint = 48.0
	info.camera_focus_pos = Vector3(center_x, 9.5, 22.0)
	info.description = "Canaliza un cuerpo de agua natural o canal pluvial entre dos vías vehiculares de 3 carriles. Incluye cruces a manera de puentes urbanos."
	_street_infos.append(info)


## Bahía 3: Avenida de 6 Carriles con Camellón Central (3+3 / Separador de 2.0m)
func _build_bay_divided_median_3lane(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = RoadTrajectorySystem.STANDARD_WIDTH_DIVIDED_3LANE # 23.00m (10.5m + 2.0m + 10.5m)
	var sw_w: float = 2.5 # Banquetas exteriores

	var ep0 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE)
	var ep1 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE)
	var seg := _catalog_road_system.connect_endpoints(ep0.id, ep1.id, r_w, RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE)
	_catalog_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

	# 1. Postes de luz en el camellón: GPU Hardware Instancing con el cilindro de 12 segmentos del medidor CFE
	_catalog_road_system.spawn_streetlights(_catalog_decor_root, null, seg.id)

	# 2. Árboles en el camellón central de 2m: generados estrictamente con ProceduralTree (Regla AGENTS.md)
	_catalog_road_system.spawn_median_trees(_catalog_decor_root, "classic_oak", seg.id)

	# 3. Autos de demostración situados en los 6 carriles (3 por calzada / vía):
	# Calzada izquierda (3 carriles hacia el Sur, 180°):
	# Carril 1 exterior: center_x - 9.75m
	# Carril 2 medio:    center_x - 6.25m
	# Carril 3 interior: center_x - 2.75m
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - 9.75, 0.05, 12.0), 180.0)  # Vía Oeste: Carril exterior
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - 6.25, 0.05, -4.0), 180.0)  # Vía Oeste: Carril medio
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - 2.75, 0.05, -20.0), 180.0) # Vía Oeste: Carril interior rebase

	# Calzada derecha (3 carriles hacia el Norte, 0°):
	# Carril 1 interior: center_x + 2.75m
	# Carril 2 medio:    center_x + 6.25m
	# Carril 3 exterior: center_x + 9.75m
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + 2.75, 0.05, -14.0), 0.0)   # Vía Este: Carril interior rebase
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + 6.25, 0.05, 2.0), 0.0)     # Vía Este: Carril medio
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + 9.75, 0.05, 18.0), 0.0)    # Vía Este: Carril exterior

	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "3. AVENIDA 6C CAMELLÓN CENTRAL", "2 vías x 3 carriles (6C total) + Separador 2.0m\nPostes GPU CFE (12-seg) + Árboles ProceduralTree | Huella: 28.0m")

	var info := StreetShowcaseInfo.new()
	info.id = "divided_median_3lane"
	info.name = "Avenida Dividida de 6 Carriles (3+3)"
	info.category_title = "VÍA PRIMARIA DIVIDIDA (2 VÍAS x 3 CARRILES)"
	info.lanes_description = "2 Calzadas x 3 Carriles (3.50m c/u) = 6 Carriles en total"
	info.roadway_width = 23.00
	info.sidewalk_left = 2.50
	info.sidewalk_right = 2.50
	info.median_width = 2.00
	info.median_type = "Camellón central de 2.0m con tierra al nivel de banqueta, árboles ProceduralTree y postes GPU CFE"
	info.total_footprint = 28.00
	info.camera_focus_pos = Vector3(center_x, 8.5, 20.0)
	info.description = "Vía primaria urbana de doble sentido con 3 carriles por calzada (6 en total) y camellón central de 2.00m. Cuenta con postes de luz GPU instanced (mismo cilindro low-poly de 12 lados del medidor CFE) y arbolado procedural (ProceduralTree)."
	_street_infos.append(info)



## Bahía 4: Avenida de 6 Carriles con Macetas Cuadradas Adaptativas (3+3 / Camellón 2.0m)
func _build_bay_divided_median_planters(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = RoadTrajectorySystem.STANDARD_WIDTH_DIVIDED_3LANE # 23.00m (10.5m + 2.0m + 10.5m)
	var sw_w: float = 2.5 # Banquetas exteriores

	var ep0 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE)
	var ep1 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE)
	var seg := _catalog_road_system.connect_endpoints(ep0.id, ep1.id, r_w, RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE)
	_catalog_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

	# 1. Postes de luz en el camellón: GPU Hardware Instancing con el cilindro de 12 segmentos del medidor CFE
	_catalog_road_system.spawn_streetlights(_catalog_decor_root, null, seg.id)

	# 2. Macetas cuadradas adaptativas: colocadas inteligentemente sin medidas estáticas a lo largo de la longitud
	# con GPU Hardware Instancing (MultiMeshInstance3D) para cajón de concreto 1.2m, tierra y arbustos shrub_sapling
	_catalog_road_system.spawn_median_planters(_catalog_decor_root, true, seg.id)

	# 3. Autos de demostración situados en los 6 carriles (3 por calzada / vía):
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - 9.75, 0.05, 10.0), 180.0)  # Vía Oeste: Carril exterior
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - 6.25, 0.05, -6.0), 180.0)  # Vía Oeste: Carril medio
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - 2.75, 0.05, -18.0), 180.0) # Vía Oeste: Carril interior rebase

	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + 2.75, 0.05, -12.0), 0.0)   # Vía Este: Carril interior rebase
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + 6.25, 0.05, 4.0), 0.0)     # Vía Este: Carril medio
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + 9.75, 0.05, 16.0), 0.0)    # Vía Este: Carril exterior

	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "4. AVENIDA 6C MACETAS CUADRADAS", "2 vías x 3 carriles (6C total) + Separador 2.0m\nJardineras Cuadradas Adaptativas GPU + Postes CFE | Huella: 28.0m")

	var info := StreetShowcaseInfo.new()
	info.id = "divided_median_planters"
	info.name = "Avenida 6 Carriles con Macetas Cuadradas"
	info.category_title = "VÍA PRIMARIA DIVIDIDA (MACETAS PROCEDURALES)"
	info.lanes_description = "2 Calzadas x 3 Carriles (3.50m c/u) = 6 Carriles en total"
	info.roadway_width = 23.00
	info.sidewalk_left = 2.50
	info.sidewalk_right = 2.50
	info.median_width = 2.00
	info.median_type = "Camellón de 2.0m con jardineras cuadradas (1.2m) elásticas + arbustos shrub_sapling"
	info.total_footprint = 28.00
	info.camera_focus_pos = Vector3(center_x, 8.5, 20.0)
	info.description = "Variante de avenida primaria con camellón de 2.00m equipada con macetas cuadradas de concreto y arbustos. El sistema calcula procedural e inteligentemente el espaciado elástico entre jardineras sin medidas estáticas fijas, adaptándose a cualquier longitud de tramo y respetando los postes de luz GPU."
	_street_infos.append(info)


## Bahía 5: Avenida Comercial Continua de 4 Carriles
func _build_bay_commercial_avenue(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = 17.30 # 4 carriles de 4.0m netos + doble amarilla + divisorias + orillas = 17.30m
	var sw_w: float = 4.0  # Banquetas comerciales amplias

	var ep0 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.COMMERCIAL_4LANE)
	var ep1 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.COMMERCIAL_4LANE)
	var seg := _catalog_road_system.connect_endpoints(ep0.id, ep1.id, r_w, RoadTrajectorySystem.RoadType.COMMERCIAL_4LANE)
	_catalog_road_system.set_both_sidewalks(seg.id, true, true, sw_w)
	_catalog_road_system.spawn_streetlights(_catalog_decor_root, null, seg.id)

	# Autos de demostración: uno en carril exterior hacia el Sur y otro en carril interior hacia el Norte
	var lane_w := r_w / 4.0
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - lane_w * 1.5, 0.05, 6.0), 180.0) # Sentido Sur, carril exterior
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + lane_w * 0.5, 0.05, -8.0), 0.0)  # Sentido Norte, carril interior

	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "5. AVENIDA COMERCIAL 4L", "Calzada continua 17.30m (2 por sentido)\nBanquetas amplias 4m | Huella: 25.3m")

	var info := StreetShowcaseInfo.new()
	info.id = "commercial_4lane"
	info.name = "Avenida Comercial Principal"
	info.category_title = "CORREDOR COMERCIAL DE ALTA CAPACIDAD"
	info.lanes_description = "4 Carriles de 4.0m netos (2 por sentido continuo + pintura)"
	info.roadway_width = 17.30
	info.sidewalk_left = 4.0
	info.sidewalk_right = 4.0
	info.median_width = 0.0
	info.median_type = "Ninguno (Calzada Continua)"
	info.total_footprint = 25.30
	info.camera_focus_pos = Vector3(center_x, 8.0, 20.0)
	info.description = "Eje comercial continuo con doble raya amarilla y líneas blancas de carril. Sus banquetas anchas de 4m dan paso peatonal frente a locales y negocios."
	_street_infos.append(info)


## Bahía 6: Calle Residencial Estándar
func _build_bay_residential_standard(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = 7.50 # 2 carriles de 3.25m netos + doble amarilla central + orillas blancas = 7.50m
	var sw_w: float = 2.0 # Banqueta residencial

	var ep0 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var ep1 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var seg := _catalog_road_system.connect_endpoints(ep0.id, ep1.id, r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	_catalog_road_system.set_both_sidewalks(seg.id, true, true, sw_w)
	_catalog_road_system.spawn_streetlights(_catalog_decor_root, null, seg.id)

	# Autos de demostración: un auto en sentido Sur y otro en sentido Norte
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x - r_w * 0.25, 0.05, 8.0), 180.0) # Sentido Sur
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + r_w * 0.25, 0.05, -6.0), 0.0)  # Sentido Norte

	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "6. CALLE RESIDENCIAL 2L", "Calzada estándar 7.50m (2 carriles de 3.25m netos)\nBanquetas 2.0m | Huella: 11.5m")

	var info := StreetShowcaseInfo.new()
	info.id = "residential_2lane"
	info.name = "Calle Residencial de 2 Sentidos"
	info.category_title = "CALLE DE BARRIO / COLECTORA LOCAL"
	info.lanes_description = "2 Carriles de 3.25m netos (1 por sentido con doble amarilla + orillas)"
	info.roadway_width = 7.50
	info.sidewalk_left = 2.0
	info.sidewalk_right = 2.0
	info.median_width = 0.0
	info.median_type = "Ninguno"
	info.total_footprint = 11.50
	info.camera_focus_pos = Vector3(center_x, 6.0, 18.0)
	info.description = "La calle fundamental de las colonias mexicanas y fraccionamientos. Diseñada para tránsito de baja velocidad frente a fachadas y banquetas residenciales."
	_street_infos.append(info)


## Bahía 7: Calle Residencial Angosta / Callejón
func _build_bay_residential_narrow(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = 4.00 # 1 carril de 4m libre
	var sw_w: float = 1.50 # Banqueta de un solo lado

	var ep0 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.ALLEY_1LANE)
	var ep1 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.ALLEY_1LANE)
	var seg := _catalog_road_system.connect_endpoints(ep0.id, ep1.id, r_w, RoadTrajectorySystem.RoadType.ALLEY_1LANE)
	_catalog_road_system.set_sidewalk(seg.id, true, true, sw_w)   # Solo banqueta izquierda
	_catalog_road_system.set_sidewalk(seg.id, false, false, 0.0)  # Lado derecho sin banqueta (muro ciego)
	_catalog_road_system.spawn_streetlights(_catalog_decor_root, null, seg.id)

	# Auto de demostración centrado en el carril único
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x, 0.05, 0.0), 0.0)

	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "7. CALLEJÓN / PRIVADA", "Calzada 4.0m (1 carril libre sin división)\nBanqueta lateral 1.5m | Huella: 5.5m")

	var info := StreetShowcaseInfo.new()
	info.id = "residential_narrow"
	info.name = "Callejón / Privada Angosta"
	info.category_title = "VÍA SECUNDARIA DE ACCESO LIMITADO"
	info.lanes_description = "1 Carril de 4.0m (Sin división central)"
	info.roadway_width = 4.00
	info.sidewalk_left = 1.50
	info.sidewalk_right = 0.0
	info.median_width = 0.0
	info.median_type = "Ninguno"
	info.total_footprint = 5.50
	info.camera_focus_pos = Vector3(center_x, 5.0, 16.0)
	info.description = "Calle angosta típica de centros históricos, callejones coloniales o cerradas privadas. Posee banqueta asimétrica compacta."
	_street_infos.append(info)


## Bahía 8: Carretera Rural Libre
func _build_bay_rural_road(center_x: float, z0: float, z1: float) -> void:
	var r_w: float = 7.00 # 2 carriles de 3.50m sin pintar

	var ep0 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.RURAL_PLAIN_2LANE)
	var ep1 := _catalog_road_system.add_endpoint(Vector3(center_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.RURAL_PLAIN_2LANE)
	var seg := _catalog_road_system.connect_endpoints(ep0.id, ep1.id, r_w, RoadTrajectorySystem.RoadType.RURAL_PLAIN_2LANE)
	_catalog_road_system.set_both_sidewalks(seg.id, false, false)

	# Auto de demostración en el carril derecho hacia el Norte
	_spawn_showcase_car(_catalog_vehicles_root, Vector3(center_x + r_w * 0.25, 0.05, 4.0), 0.0)

	_create_billboard_sign(Vector3(center_x, 4.5, z1 + 6.0), "8. CARRETERA RURAL", "Calzada continua 7.0m sin pintura\nSin banquetas ni bordillos | Huella: 7.0m")

	var info := StreetShowcaseInfo.new()
	info.id = "rural_plain"
	info.name = "Carretera Rural / Libre"
	info.category_title = "VÍA INTERURBANA RÚSTICA"
	info.lanes_description = "2 Carriles sin pintar (3.5m c/u)"
	info.roadway_width = 7.00
	info.sidewalk_left = 0.0
	info.sidewalk_right = 0.0
	info.median_width = 0.0
	info.median_type = "Ninguno"
	info.total_footprint = 7.00
	info.camera_focus_pos = Vector3(center_x, 6.0, 18.0)
	info.description = "Carretera interurbana de terracería o asfalto simple al ras del terreno natural, sin señalamientos ni aceras peatonales."
	_street_infos.append(info)


# ==============================================================================
# BAHÍA 7: DEMOSTRADOR PROCEDURAL DE MANZANA (LONGITUD ELÁSTICA)
# ==============================================================================

func _build_interactive_block() -> void:
	_interactive_road_system.clear()
	_interactive_road_system.begin_batch()

	for child in _interactive_decor_root.get_children():
		if child != _interactive_lot_box:
			child.queue_free()
	for child in _interactive_vehicles_root.get_children():
		child.queue_free()

	var center_x: float = 125.0
	var half_len: float = interactive_block_length * 0.5
	var z0: float = -half_len
	var z1: float = +half_len

	# Creamos una calle residencial adyacente a la manzana
	var road_x := center_x - 18.0
	var r_w := 7.50
	var ep0 := _interactive_road_system.add_endpoint(Vector3(road_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var ep1 := _interactive_road_system.add_endpoint(Vector3(road_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var seg_road := _interactive_road_system.connect_endpoints(ep0.id, ep1.id, r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	_interactive_road_system.set_both_sidewalks(seg_road.id, true, true, 2.0)

	# Y una calle transversal cerrando la manzana en el extremo sur
	var ep_t0 := _interactive_road_system.add_endpoint(Vector3(road_x, 0.0, z1), Vector3(1.0, 0.0, 0.0), r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var ep_t1 := _interactive_road_system.add_endpoint(Vector3(center_x + 20.0, 0.0, z1), Vector3(1.0, 0.0, 0.0), r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	var seg_t := _interactive_road_system.connect_endpoints(ep_t0.id, ep_t1.id, r_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
	_interactive_road_system.set_both_sidewalks(seg_t.id, true, true, 2.0)

	_interactive_road_system.end_batch()

	# Auto en la calle residencial de la manzana
	_spawn_showcase_car(_interactive_vehicles_root, Vector3(road_x + r_w * 0.25, 0.05, 0.0), 0.0)

	# Superficie representativa de la Manzana urbana / lote
	var block_width := 28.0
	var lot_mesh := BoxMesh.new()
	lot_mesh.size = Vector3(block_width, 0.15, interactive_block_length)
	_interactive_lot_box.mesh = lot_mesh
	var lot_mat := StandardMaterial3D.new()
	lot_mat.albedo_color = Color(0.35, 0.32, 0.28) # Tierra / cantera de manzana
	lot_mat.roughness = 0.90
	_interactive_lot_box.material_override = lot_mat
	_interactive_lot_box.position = Vector3(center_x, 0.075, 0.0)

	# Cartel 3D del demostrador
	_create_billboard_sign_interactive(Vector3(center_x - 5.0, 5.0, z1 + 8.0))

	# Actualizar info del demostrador en la lista si ya existe, o agregarla
	if _street_infos.size() == 7:
		var info := StreetShowcaseInfo.new()
		info.id = "interactive_manzana"
		info.name = "Demostrador Procedural de Manzana"
		info.category_title = "ESCALADO ELÁSTICO SEGÚN LA MANZANA"
		info.lanes_description = "Variable en Tiempo Real"
		info.roadway_width = 7.50
		info.sidewalk_left = 2.0
		info.sidewalk_right = 2.0
		info.median_width = 0.0
		info.median_type = "N/A"
		info.total_footprint = 11.50
		info.camera_focus_pos = Vector3(center_x - 10.0, 15.0, z1 + 25.0)
		info.description = "Muestra cómo el tramo de calle NO tiene una longitud fija hardcodeada. Al cambiar el tamaño de la manzana (con las teclas Z / X), la calle, sus banquetas y sus marcas se adaptan en tiempo real."
		_street_infos.append(info)
	elif _street_infos.size() > 7:
		_street_infos[7].camera_focus_pos = Vector3(center_x - 10.0, 15.0, z1 + 25.0)


# ==============================================================================
# ELEMENTOS AMBIENTALES (CAMELLONES, ÁRBOLES Y RÍO)
# ==============================================================================

func _create_median_strip(parent: Node3D, cx: float, z0: float, z1: float, m_w: float, style: String, tree_spacing: float) -> void:
	var len_z := z1 - z0
	if len_z <= 1.0:
		return

	# Losa volumétrica de tierra del camellón elevada exactamente al nivel de la banqueta (ROAD_HEIGHT + SIDEWALK_HEIGHT = 0.30m)
	var y_med_top := RoadTrajectorySystem.ROAD_HEIGHT + RoadTrajectorySystem.SIDEWALK_HEIGHT # 0.30m
	var slab_height := RoadTrajectorySystem.SIDEWALK_HEIGHT # 0.20m
	var y_center := RoadTrajectorySystem.ROAD_HEIGHT + slab_height * 0.5 # 0.20m

	var dirt_mi := MeshInstance3D.new()
	dirt_mi.name = "MedianGrassSlab"
	var box := BoxMesh.new()
	box.size = Vector3(m_w, slab_height, len_z)
	dirt_mi.mesh = box
	dirt_mi.material_override = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_GRASS)
	dirt_mi.position = Vector3(cx, y_center, (z0 + z1) * 0.5)
	parent.add_child(dirt_mi)

	if style == "trees":
		var count := int(floor(len_z / tree_spacing))
		var start_z := z0 + (len_z - float(count - 1) * tree_spacing) * 0.5
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(cx) * 53.0 + z0 * 17.0)

		for i in range(count):
			var tz := start_z + float(i) * tree_spacing
			var tree := PROCEDURAL_TREE_SCRIPT.new()
			tree.profile_id = "classic_oak" if rng.randf() < 0.75 else "autumn_birch"
			tree.tree_seed = rng.randi()
			parent.add_child(tree)
			tree.position = Vector3(cx + rng.randf_range(-0.3, 0.3), y_med_top, tz)
			tree.rotation.y = rng.randf_range(0.0, TAU)


func _create_stream_strip(parent: Node3D, cx: float, z0: float, z1: float, m_w: float) -> void:
	var len_z := z1 - z0
	if len_z <= 1.0:
		return

	var slab_height := RoadTrajectorySystem.SIDEWALK_HEIGHT # 0.20m

	# Taludes de pasto natural a los lados del canal (al nivel de la banqueta)
	var bank_mi := MeshInstance3D.new()
	bank_mi.name = "StreamBanks_Grass"
	var bank_mesh := BoxMesh.new()
	bank_mesh.size = Vector3(m_w, slab_height * 0.8, len_z)
	bank_mi.mesh = bank_mesh
	bank_mi.material_override = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_GRASS)
	bank_mi.position = Vector3(cx, RoadTrajectorySystem.ROAD_HEIGHT + slab_height * 0.4, (z0 + z1) * 0.5)
	parent.add_child(bank_mi)

	# Lecho rocoso
	var bed_w := m_w * 0.55
	var bed_mi := MeshInstance3D.new()
	var bed_mesh := PlaneMesh.new()
	bed_mesh.size = Vector2(bed_w + 1.2, len_z)
	bed_mi.mesh = bed_mesh
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.35, 0.36, 0.32)
	bed_mi.material_override = stone_mat
	bed_mi.position = Vector3(cx, 0.14, (z0 + z1) * 0.5)
	parent.add_child(bed_mi)

	# Lámina de agua cristalina
	var water_mi := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(bed_w, len_z)
	water_mi.mesh = water_mesh
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.46, 0.68, 0.88)
	water_mat.roughness = 0.05
	water_mat.metallic = 0.20
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mi.material_override = water_mat
	water_mi.position = Vector3(cx, 0.18, (z0 + z1) * 0.5)
	parent.add_child(water_mi)


func _create_billboard_sign(pos: Vector3, title: String, subtitle: String) -> void:
	var label := Label3D.new()
	label.text = "%s\n%s" % [title, subtitle]
	label.font_size = 28
	label.outline_size = 8
	label.modulate = Color(1.0, 0.92, 0.40)
	label.outline_modulate = Color(0.08, 0.08, 0.10)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	_catalog_decor_root.add_child(label)


var _interactive_sign: Label3D = null

func _create_billboard_sign_interactive(pos: Vector3) -> void:
	if _interactive_sign == null:
		_interactive_sign = Label3D.new()
		_interactive_sign.font_size = 28
		_interactive_sign.outline_size = 8
		_interactive_sign.modulate = Color(0.35, 1.0, 0.65)
		_interactive_sign.outline_modulate = Color(0.08, 0.08, 0.10)
		_interactive_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_interactive_decor_root.add_child(_interactive_sign)

	_interactive_sign.position = pos
	_interactive_sign.text = "7. DEMOSTRADOR PROCEDURAL DE MANZANA\nLongitud Actual de Manzana: %.0f metros\n[Presiona Z (-10m) / X (+10m) para redimensionar]" % interactive_block_length


# ==============================================================================
# INTERFAZ GRÁFICA (HUD)
# ==============================================================================

func _setup_ui() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	# Barra mínima en el pie de pantalla (cero obstrucción visual)
	_bottom_panel = PanelContainer.new()
	_bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_panel.offset_top = -42.0
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.04, 0.05, 0.08, 0.82)
	b_style.set_content_margin_all(8)
	_bottom_panel.add_theme_stylebox_override("panel", b_style)
	_canvas.add_child(_bottom_panel)

	_bottom_lbl = Label.new()
	_bottom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bottom_lbl.add_theme_font_size_override("font_size", 12)
	_bottom_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_bottom_panel.add_child(_bottom_lbl)


func _update_ui_info(index: int) -> void:
	if index < 0 or index >= _street_infos.size():
		return
	_current_focus_index = index
	var info := _street_infos[index]

	if _bottom_lbl:
		_bottom_lbl.text = "[%d/%d] %s  |  Calzada: %.1fm (Huella: %.1fm)  |  [1-8] Enfocar  |  [9] Manzana: %.0fm [Z/X]  |  [H] Ocultar Barra  |  [WASD/Shift] Volar" % [
			index + 1,
			_street_infos.size(),
			info.name,
			info.roadway_width,
			info.total_footprint,
			interactive_block_length
		]


func _focus_street(index: int) -> void:
	if index < 0 or index >= _street_infos.size():
		return
	_update_ui_info(index)
	var target_pos := _street_infos[index].camera_focus_pos
	_camera.position = target_pos
	_cam_yaw = 0.0
	_cam_pitch = -0.38
	_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


# ==============================================================================
# CONTROL DE ENTRADA Y NAVEGACIÓN
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _focus_street(0)
			KEY_2: _focus_street(1)
			KEY_3: _focus_street(2)
			KEY_4: _focus_street(3)
			KEY_5: _focus_street(4)
			KEY_6: _focus_street(5)
			KEY_7: _focus_street(6)
			KEY_8: _focus_street(7)
			KEY_9:
				_camera.position = Vector3(125.0, 10.0, 25.0)
				_cam_yaw = 0.0
				_cam_pitch = -0.38
				_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
			KEY_Z:
				_change_interactive_length(-STEP_BLOCK_LEN)
			KEY_X:
				_change_interactive_length(+STEP_BLOCK_LEN)
			KEY_H:
				if _bottom_panel:
					_bottom_panel.visible = not _bottom_panel.visible
			KEY_ESCAPE:
				_mouse_captured = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not _mouse_captured:
			_mouse_captured = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	elif event is InputEventMouseMotion and _mouse_captured:
		var sens := 0.0028
		_cam_yaw -= event.relative.x * sens
		_cam_pitch = clampf(_cam_pitch - event.relative.y * sens, -1.45, 1.45)
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _change_interactive_length(delta: float) -> void:
	interactive_block_length = clampf(interactive_block_length + delta, MIN_BLOCK_LEN, MAX_BLOCK_LEN)
	_build_interactive_block()
	_update_ui_info(_current_focus_index)
	print("[StreetShowcase] Longitud de manzana interactiva ajustada a: %.0f metros" % interactive_block_length)


func _process(delta: float) -> void:
	if not _mouse_captured:
		return

	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move += -_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): move += _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): move += -_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): move += _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E): move += Vector3.UP
	if Input.is_key_pressed(KEY_Q): move += Vector3.DOWN

	if move != Vector3.ZERO:
		var speed := CAM_MOVE_SPEED
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= CAM_TURBO_MULT
		_camera.position += move.normalized() * speed * delta


# ==============================================================================
# COMPROBACIÓN HEADLESS AUTOMATIZADA
# ==============================================================================

func _run_headless_verification() -> void:
	print("--- VERIFICACIÓN HEADLESS DEL CATÁLOGO DE CALLES PROCEDURALES ---")
	var catalog_segs := _catalog_road_system.get_all_segments()
	var interactive_segs := _interactive_road_system.get_all_segments()

	print("✓ Tramos en Catálogo Vial: %d" % catalog_segs.size())
	print("✓ Tramos en Manzana Interactiva: %d" % interactive_segs.size())
	print("✓ Fichas Técnicas de Calles Registradas: %d" % _street_infos.size())

	assert(catalog_segs.size() >= 8, "Debe haber al menos 8 tramos construidos en el catálogo")
	assert(interactive_segs.size() >= 2, "Debe haber al menos 2 tramos en la manzana interactiva")
	assert(_street_infos.size() == 8, "Deben estar registradas las 8 fichas (7 calles + 1 interactiva)")
	print("✓ Autos de demostración en Catálogo: %d" % _catalog_vehicles_root.get_child_count())
	print("✓ Autos de demostración en Manzana: %d" % _interactive_vehicles_root.get_child_count())
	assert(_catalog_vehicles_root.get_child_count() >= 9, "Debe haber autos invocados en el catálogo")
	assert(_interactive_vehicles_root.get_child_count() >= 1, "Debe haber auto en la manzana interactiva")
	var streetlights_count := _catalog_road_system.get_all_streetlight_transforms().size()
	print("✓ Postes de luz procedurales calculados en el catálogo: %d" % streetlights_count)
	assert(streetlights_count >= 2, "Debe haber al menos 2 postes de luz calculados proceduralmente en el camellón")

	# Probar escalado en tiempo real en headless
	_change_interactive_length(+20.0)
	assert(interactive_block_length == 100.0, "La manzana interactiva debe escalar a 100m")

	print("✓ ¡TODAS LAS COMPROBACIONES DEL CATÁLOGO DE CALLES PASARON EXITOSAMENTE!")
	get_tree().quit(0)
