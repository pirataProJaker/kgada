extends Node3D
class_name CityLayoutGenerator
## Generador procedural automatizado de trazados urbanos completos.
## Genera avenidas jerarquizadas (boulevards con camellón arbolado, arroyos naturales,
## avenidas comerciales) y colonias residenciales con patrones de manzana orgánicos
## utilizando exclusivamente el motor matemático RoadTrajectorySystem.

const RoadTrajectorySystem = preload("res://world/city/road_trajectory_system.gd")
const CityRoadPatterns = preload("res://world/city/city_road_patterns.gd")
const ProceduralRoadMaterials = preload("res://world/city/procedural_road_materials.gd")
const HOUSE_GENERATOR_SCRIPT := preload("res://world/city/house_generator.gd")
const DECORATION_GENERATOR_SCRIPT := preload("res://world/city/city_decoration.gd")


@export_group("Configuración de Ciudad")
@export var rng_seed: int = 0
@export var randomize_seed_on_run: bool = false
@export var avenue_type: CityRoadPatterns.AvenueType = CityRoadPatterns.AvenueType.DIVIDED_BOULEVARD
@export var neighborhood_pattern: CityRoadPatterns.NeighborhoodPattern = CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID
@export var neighborhood_zone: CityRoadPatterns.NeighborhoodZoneType = CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS
@export_range(200.0, 3000.0, 20.0) var city_length: float = 720.0
@export_range(1, 8, 1) var neighborhood_blocks_per_side: int = 4

@export_group("Casas")
@export var generate_houses: bool = true
@export var house_randomize_seed_on_run: bool = false
@export var house_rng_seed_offset: int = 1009
@export var house_show_debug_labels: bool = false
@export var house_show_roofs: bool = true
@export var house_show_fences: bool = true
@export_range(0.0, 1.0, 0.05) var house_fence_probability: float = 0.70
@export_range(0.0, 1.0, 0.05) var vacant_lot_probability: float = 0.15

@export_group("Decoraciones Urbanas")
@export var scatter_decorations: bool = true
@export var decoration_randomize_seed_on_run: bool = false
@export var decoration_rng_seed_offset: int = 2027

@export_group("Visualización de Lotes")
@export var show_parcel_outlines: bool = true
@export var parcel_outline_color: Color = Color(1.0, 0.05, 0.45, 1.0)
@export var parcel_outline_thickness: float = 0.6

# Propiedades públicas consumidas por CityWorldSpawner y HouseGenerator
var block_parcels: Array[Dictionary] = []
var block_rects: Array[Rect2] = []
var generated_footprint_aabb: AABB = AABB()

var _road_system: RoadTrajectorySystem
var _median_root: Node3D
var _parcel_outline_root: Node3D
var _house_generator: HouseGenerator
var _decoration_generator: CityDecoration
var _rng: RandomNumberGenerator


func _ready() -> void:
	generate_city()


func get_generated_footprint_aabb() -> AABB:
	if generated_footprint_aabb.size.x <= 0.0 or generated_footprint_aabb.size.z <= 0.0:
		_compute_footprint()
	return generated_footprint_aabb


## Punto de entrada principal para generar la ciudad completa
func generate_city() -> void:
	_rng = RandomNumberGenerator.new()
	if randomize_seed_on_run:
		_rng.randomize()
		rng_seed = _rng.seed
	else:
		_rng.seed = rng_seed

	_cleanup_children()

	_road_system = RoadTrajectorySystem.new()
	_road_system.name = "RoadTrajectorySystem"
	add_child(_road_system)

	_median_root = Node3D.new()
	_median_root.name = "CentralMedians"
	add_child(_median_root)

	var avenue_cfg := CityRoadPatterns.get_avenue_config(avenue_type)
	var hood_cfg := CityRoadPatterns.get_neighborhood_config(neighborhood_pattern)

	# 1. Trazado jerárquico de la red vial
	_road_system.begin_batch()
	var layout_data := _build_road_network(avenue_cfg, hood_cfg)

	# 2. Generación geométrica procedural continua (asfalto, banquetas, bordillos, señalización)
	_road_system.end_batch()

	# 3. Construcción y ambientación del camellón central / arroyo con árboles
	_build_median_features(avenue_cfg, layout_data["crossover_z"])

	# 4. Cálculo de manzanas y parcelamiento de lotes
	_build_parcels(layout_data["blocks"], avenue_cfg, hood_cfg, layout_data.get("block_zones", []))

	# 5. Medir huella total para el aplanado de terreno
	_compute_footprint()

	# 6. Spawners de casas y decoración urbana
	_create_house_generator()
	_create_decoration_generator()

	print("[CityLayoutGenerator] Ciudad generada: %d tramos viales, %d manzanas, %d parcelas (Semilla: %d)" % [
		_road_system.get_all_segments().size(),
		block_rects.size(),
		block_parcels.size(),
		rng_seed
	])


func _cleanup_children() -> void:
	block_parcels.clear()
	block_rects.clear()
	for child in get_children():
		child.queue_free()
	_road_system = null
	_median_root = null
	_parcel_outline_root = null
	_house_generator = null
	_decoration_generator = null


# ==============================================================================
# TRAZADO JERÁRQUICO VIAL (AVENIDAS Y COLONIAS)
# ==============================================================================

func _build_road_network(avenue_cfg: CityRoadPatterns.AvenueConfig, hood_cfg: CityRoadPatterns.NeighborhoodConfig) -> Dictionary:
	var half_len := city_length * 0.5
	var half_width := half_len
	var cols := 3
	var rows := 3

	var step_z := city_length / float(rows)
	var z_splits: Array[float] = []
	for i in range(rows + 1):
		z_splits.append(-half_len + float(i) * step_z)

	var step_x := (half_width * 2.0) / float(cols)
	var x_splits: Array[float] = []
	for i in range(cols + 1):
		x_splits.append(-half_width + float(i) * step_x)

	# 1. Asignación de Zonificación Urbana (Macro-Colonias con reglas contiguas)
	var sector_zones := _assign_sector_zones(cols, rows)

	# 2. Asignación de Orientación por Sector ("Calles acostadas" vs "Calles paradas")
	var sector_orientations := _assign_sector_orientations(cols, rows)

	# 3. Trazado de Avenida Central / Boulevard Longitudinal (Eje X = 0)
	var crossover_z: Array[float] = []
	for i in range(z_splits.size()):
		crossover_z.append(z_splits[i])
		if i < z_splits.size() - 1:
			var mid_z := (z_splits[i] + z_splits[i + 1]) * 0.5
			crossover_z.append(mid_z)
	crossover_z.sort()

	if avenue_cfg.type == CityRoadPatterns.AvenueType.COMMERCIAL_MAIN:
		_build_commercial_avenue(avenue_cfg, crossover_z)
	else:
		_build_divided_avenue(avenue_cfg, crossover_z, hood_cfg)

	# 4. Trazado de Avenidas Transversales Colectoras (Este-Oeste)
	_build_transverse_avenues(z_splits, x_splits, avenue_cfg, hood_cfg)

	# 5. Trazado de Avenidas Secundarias Longitudinales (Norte-Sur)
	_build_secondary_avenues(x_splits, z_splits, hood_cfg)

	# 6. Trazado de Manzanas e Internos de cada Sector con medidas y orientaciones irregulares
	var blocks: Array[Rect2] = []
	var block_zones: Array = []

	var r_w := avenue_cfg.roadway_width
	var m_w := avenue_cfg.median_width
	var avenue_outer_w: float
	var avenue_outer_e: float
	if avenue_cfg.type == CityRoadPatterns.AvenueType.COMMERCIAL_MAIN:
		avenue_outer_w = -r_w * 0.5
		avenue_outer_e = +r_w * 0.5
	else:
		avenue_outer_w = -(m_w * 0.5 + r_w)
		avenue_outer_e = +(m_w * 0.5 + r_w)

	for gx in range(cols):
		for gz in range(rows):
			var z0: float = z_splits[gz]
			var z1: float = z_splits[gz + 1]
			var zone: CityRoadPatterns.NeighborhoodZoneType = sector_zones[gx][gz]
			var is_horiz: bool = sector_orientations[gx][gz]

			if gx == 0:
				# Flanco Oeste exterior: de x_splits[0] a x_splits[1]
				_build_sector_blocks(x_splits[0], x_splits[1], z0, z1, zone, is_horiz, hood_cfg, blocks, block_zones)
			elif gx == 1:
				# Columna Central dividida por el boulevard en Ala Oeste y Ala Este:
				if avenue_outer_w > x_splits[1] + 25.0:
					_build_sector_blocks(x_splits[1], avenue_outer_w, z0, z1, zone, is_horiz, hood_cfg, blocks, block_zones)
				if x_splits[2] > avenue_outer_e + 25.0:
					_build_sector_blocks(avenue_outer_e, x_splits[2], z0, z1, zone, is_horiz, hood_cfg, blocks, block_zones)
			elif gx == 2:
				# Flanco Este exterior: de x_splits[2] a x_splits[3]
				_build_sector_blocks(x_splits[2], x_splits[3], z0, z1, zone, is_horiz, hood_cfg, blocks, block_zones)

	return {
		"crossover_z": crossover_z,
		"blocks": blocks,
		"block_zones": block_zones
	}


func _build_divided_avenue(avenue_cfg: CityRoadPatterns.AvenueConfig, crossover_z: Array[float], hood_cfg: CityRoadPatterns.NeighborhoodConfig = null) -> void:
	var r_w := avenue_cfg.roadway_width
	var m_w := avenue_cfg.median_width
	var x_west := -(m_w * 0.5 + r_w * 0.5)
	var x_east := +(m_w * 0.5 + r_w * 0.5)
	var cross_w: float = hood_cfg.primary_collector_width if hood_cfg != null else (2.0 * RoadTrajectorySystem.STANDARD_LANE_WIDTH)

	var z_count := crossover_z.size()
	# Calzadas longitudinales de la avenida
	for i in range(z_count - 1):
		var z0: float = crossover_z[i]
		var z1: float = crossover_z[i + 1]

		# 1. Calzada Oeste (sentido Sur, dirección +Z)
		var p0_w := Vector3(x_west, 0.0, z0)
		var p1_w := Vector3(x_west, 0.0, z1)
		var ep0_w := _road_system.add_endpoint(p0_w, Vector3(0.0, 0.0, 1.0), r_w, avenue_cfg.road_type)
		var ep1_w := _road_system.add_endpoint(p1_w, Vector3(0.0, 0.0, 1.0), r_w, avenue_cfg.road_type)
		var seg_w = _road_system.connect_endpoints(ep0_w.id, ep1_w.id, r_w, avenue_cfg.road_type)
		# Banqueta exterior amplia hacia lotes (derecha en sentido +Z)
		_road_system.set_sidewalk(seg_w.id, false, true, avenue_cfg.outer_sidewalk_width)
		# Banqueta interior angosta hacia el camellón (izquierda en sentido +Z)
		_road_system.set_sidewalk(seg_w.id, true, avenue_cfg.inner_sidewalk_width > 0.1, avenue_cfg.inner_sidewalk_width)

		# 2. Calzada Este (sentido Norte, dirección -Z)
		var p0_e := Vector3(x_east, 0.0, z1)
		var p1_e := Vector3(x_east, 0.0, z0)
		var ep0_e := _road_system.add_endpoint(p0_e, Vector3(0.0, 0.0, -1.0), r_w, avenue_cfg.road_type)
		var ep1_e := _road_system.add_endpoint(p1_e, Vector3(0.0, 0.0, -1.0), r_w, avenue_cfg.road_type)
		var seg_e = _road_system.connect_endpoints(ep0_e.id, ep1_e.id, r_w, avenue_cfg.road_type)
		# Banqueta exterior amplia hacia lotes (derecha en sentido -Z)
		_road_system.set_sidewalk(seg_e.id, false, true, avenue_cfg.outer_sidewalk_width)
		# Banqueta interior angosta hacia el camellón (izquierda en sentido -Z)
		_road_system.set_sidewalk(seg_e.id, true, avenue_cfg.inner_sidewalk_width > 0.1, avenue_cfg.inner_sidewalk_width)

	# Cruces transversales (retornos y conectores entre calzadas)
	for i in range(z_count):
		var z_c: float = crossover_z[i]
		# Segmento conector cruzando el camellón de x_west a x_east
		var ep_c_w := _road_system.add_endpoint(Vector3(x_west, 0.0, z_c), Vector3(1.0, 0.0, 0.0), cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		var ep_c_e := _road_system.add_endpoint(Vector3(x_east, 0.0, z_c), Vector3(1.0, 0.0, 0.0), cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		var seg_cross = _road_system.connect_endpoints(ep_c_w.id, ep_c_e.id, cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		if i == 0:
			# Extremo Norte de la avenida: banqueta exterior continua cerrando la avenida hacia el Norte (lado izquierdo)
			_road_system.set_sidewalk(seg_cross.id, true, true, CityRoadPatterns.SIDEWALK_WIDTH_RESIDENTIAL)
			_road_system.set_sidewalk(seg_cross.id, false, false)
		elif i == z_count - 1:
			# Extremo Sur de la avenida: banqueta exterior continua cerrando la avenida hacia el Sur (lado derecho)
			_road_system.set_sidewalk(seg_cross.id, true, false)
			_road_system.set_sidewalk(seg_cross.id, false, true, CityRoadPatterns.SIDEWALK_WIDTH_RESIDENTIAL)
		else:
			# Cruces intermedios del camellón: sin banquetas laterales para permitir giros vehiculares limpios
			_road_system.set_sidewalk(seg_cross.id, true, false)
			_road_system.set_sidewalk(seg_cross.id, false, false)


func _build_commercial_avenue(avenue_cfg: CityRoadPatterns.AvenueConfig, crossover_z: Array[float]) -> void:
	var r_w := avenue_cfg.roadway_width
	var z_count := crossover_z.size()
	for i in range(z_count - 1):
		var z0: float = crossover_z[i]
		var z1: float = crossover_z[i + 1]
		var ep0 := _road_system.add_endpoint(Vector3(0.0, 0.0, z0), Vector3(0.0, 0.0, 1.0), r_w, avenue_cfg.road_type)
		var ep1 := _road_system.add_endpoint(Vector3(0.0, 0.0, z1), Vector3(0.0, 0.0, 1.0), r_w, avenue_cfg.road_type)
		var seg = _road_system.connect_endpoints(ep0.id, ep1.id, r_w, avenue_cfg.road_type)
		_road_system.set_sidewalk(seg.id, true, true, avenue_cfg.outer_sidewalk_width)
		_road_system.set_sidewalk(seg.id, false, true, avenue_cfg.outer_sidewalk_width)


# ==============================================================================
# SUB-SISTEMA DE MACRO-SECTORES, ZONIFICACIÓN Y MANZANAS IRREGULARES
# ==============================================================================

func _assign_sector_zones(cols: int, rows: int) -> Array:
	var zones: Array = []
	for x in range(cols):
		var col_arr: Array = []
		for z in range(rows):
			col_arr.append(CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA)
		zones.append(col_arr)

	if neighborhood_zone != CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS:
		for x in range(cols):
			for z in range(rows):
				zones[x][z] = neighborhood_zone
		return zones

	# REGLAS DE ZONIFICACIÓN URBANA:
	# 1. El Centro de la ciudad (1, 1) es SIEMPRE Colonia Vieja / Centro Histórico
	zones[1][1] = CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA

	# 2. Zona X (Zona de Ricos): Cluster contiguo obligatorio (en flanco/esquina Norte-Oeste)
	zones[0][0] = CityRoadPatterns.NeighborhoodZoneType.ZONA_X
	zones[0][1] = CityRoadPatterns.NeighborhoodZoneType.ZONA_X

	# 3. Colonia Nueva (Fraccionamiento Infonavit): Cluster contiguo obligatorio (en flanco/esquina Sur-Este)
	zones[2][1] = CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA
	zones[2][2] = CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA

	# 4. Los demás sectores ([0, 2], [1, 0], [1, 2], [2, 0]) son Barrios Tradicionales (Colonia Vieja)
	zones[0][2] = CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA
	zones[1][0] = CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA
	zones[1][2] = CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA
	zones[2][0] = CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA

	return zones


func _assign_sector_orientations(cols: int, rows: int) -> Array:
	var orientations: Array = []
	for x in range(cols):
		var col_arr: Array = []
		for z in range(rows):
			# Alternancia en patrón ortogonal:
			# true = Calles acostadas (orientación Este-Oeste, eje X)
			# false = Calles paradas (orientación Norte-Sur, eje Z)
			var is_horiz := ((x + z) % 2 == 0)
			col_arr.append(is_horiz)
		orientations.append(col_arr)
	return orientations


func _build_transverse_avenues(
	z_splits: Array[float],
	x_splits: Array[float],
	avenue_cfg: CityRoadPatterns.AvenueConfig,
	hood_cfg: CityRoadPatterns.NeighborhoodConfig
) -> void:
	var trans_w: float = hood_cfg.primary_collector_width
	var x_min: float = x_splits[0]
	var x_max: float = x_splits[x_splits.size() - 1]

	var r_w := avenue_cfg.roadway_width
	var m_w := avenue_cfg.median_width
	var x_center_w := -(m_w * 0.5 + r_w * 0.5) if avenue_cfg.type != CityRoadPatterns.AvenueType.COMMERCIAL_MAIN else 0.0
	var x_center_e := +(m_w * 0.5 + r_w * 0.5) if avenue_cfg.type != CityRoadPatterns.AvenueType.COMMERCIAL_MAIN else 0.0

	for i in range(1, z_splits.size() - 1):
		var z_c: float = z_splits[i]

		# 1. Tramo Oeste: desde x_min hasta el centro de la calzada oeste de la avenida
		var ep_w0 := _road_system.add_endpoint(Vector3(x_min, 0.0, z_c), Vector3(1.0, 0.0, 0.0), trans_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		var ep_w1 := _road_system.add_endpoint(Vector3(x_center_w, 0.0, z_c), Vector3(1.0, 0.0, 0.0), trans_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		var seg_w := _road_system.connect_endpoints(ep_w0.id, ep_w1.id, trans_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		_road_system.set_both_sidewalks(seg_w.id, true, true, CityRoadPatterns.SIDEWALK_WIDTH_AVENUE)

		# 2. Tramo Este: desde el centro de la calzada este de la avenida hasta x_max
		var ep_e0 := _road_system.add_endpoint(Vector3(x_center_e, 0.0, z_c), Vector3(1.0, 0.0, 0.0), trans_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		var ep_e1 := _road_system.add_endpoint(Vector3(x_max, 0.0, z_c), Vector3(1.0, 0.0, 0.0), trans_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		var seg_e := _road_system.connect_endpoints(ep_e0.id, ep_e1.id, trans_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
		_road_system.set_both_sidewalks(seg_e.id, true, true, CityRoadPatterns.SIDEWALK_WIDTH_AVENUE)


func _build_secondary_avenues(
	x_splits: Array[float],
	z_splits: Array[float],
	hood_cfg: CityRoadPatterns.NeighborhoodConfig
) -> void:
	var sec_w: float = hood_cfg.primary_collector_width

	for i in range(1, x_splits.size() - 1):
		var x_c: float = x_splits[i]
		for z_idx in range(z_splits.size() - 1):
			var z0: float = z_splits[z_idx]
			var z1: float = z_splits[z_idx + 1]
			var ep0 := _road_system.add_endpoint(Vector3(x_c, 0.0, z0), Vector3(0.0, 0.0, 1.0), sec_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			var ep1 := _road_system.add_endpoint(Vector3(x_c, 0.0, z1), Vector3(0.0, 0.0, 1.0), sec_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			var seg := _road_system.connect_endpoints(ep0.id, ep1.id, sec_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			_road_system.set_both_sidewalks(seg.id, true, true, CityRoadPatterns.SIDEWALK_WIDTH_RESIDENTIAL)


func _build_sector_blocks(
	sec_x0: float, sec_x1: float,
	sec_z0: float, sec_z1: float,
	zone: CityRoadPatterns.NeighborhoodZoneType,
	default_is_horiz: bool,
	hood_cfg: CityRoadPatterns.NeighborhoodConfig,
	out_blocks: Array[Rect2],
	out_zones: Array
) -> void:
	var res_w := hood_cfg.residential_street_width
	var sw_w := CityRoadPatterns.SIDEWALK_WIDTH_RESIDENTIAL
	var margin := res_w * 0.5 + sw_w # 5.25m
	var corridor_w := res_w + 2.0 * sw_w # 10.5m

	var sec_w := absf(sec_x1 - sec_x0)
	var sec_h := absf(sec_z1 - sec_z0)

	if sec_w < 35.0 or sec_h < 35.0:
		return

	var b_rng := RandomNumberGenerator.new()
	b_rng.seed = rng_seed + int(absf(sec_x0) * 19.0 + absf(sec_z0) * 37.0)

	# Subdividir el sector en macro-bloques (super-cuadras) para permitir alternancia
	# entre cuadras de casas horizontales y verticales (como en plano real de México / Imagen 2).
	var macro_cols := 2 if sec_w >= 150.0 else 1
	var macro_rows := 2 if sec_h >= 150.0 else 1

	var step_mx := sec_w / float(macro_cols)
	var step_mz := sec_h / float(macro_rows)

	# 1. Calles secundarias divisorias continuas y completamente rectas (cero quiebres)
	if macro_cols > 1:
		for c in range(1, macro_cols):
			var div_x := sec_x0 + float(c) * step_mx
			var ep0 := _road_system.add_endpoint(Vector3(div_x, 0.0, sec_z0), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			var ep1 := _road_system.add_endpoint(Vector3(div_x, 0.0, sec_z1), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			var seg := _road_system.connect_endpoints(ep0.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

	if macro_rows > 1:
		for r in range(1, macro_rows):
			var div_z := sec_z0 + float(r) * step_mz
			var ep0 := _road_system.add_endpoint(Vector3(sec_x0, 0.0, div_z), Vector3(1.0, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			var ep1 := _road_system.add_endpoint(Vector3(sec_x1, 0.0, div_z), Vector3(1.0, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			var seg := _road_system.connect_endpoints(ep0.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
			_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

	# 2. Generar cada macro-cuadra con su orientación congruente (Horizontal vs Vertical)
	var target_depth := CityRoadPatterns.get_zone_block_depth(zone)

	for mc in range(macro_cols):
		for mr in range(macro_rows):
			var mx0 := sec_x0 + float(mc) * step_mx
			var mx1 := mx0 + step_mx
			var mz0 := sec_z0 + float(mr) * step_mz
			var mz1 := mz0 + step_mz

			var mb_w := mx1 - mx0
			var mb_h := mz1 - mz0

			# Alternancia natural de orientación entre cuadras vecinas (tablero o variabilidad orgánica)
			var is_horiz := ((mc + mr) % 2 == 0) if default_is_horiz else ((mc + mr) % 2 == 1)
			if b_rng.randf() < 0.15:
				is_horiz = not is_horiz

			if is_horiz:
				# CUADRA DE CASAS EN HORIZONTAL: calles corren en X (Este-Oeste), profundidad en Z
				var num_tiers := maxi(int(round(mb_h / (target_depth + corridor_w))), 1)
				var pitch_z := mb_h / float(num_tiers)

				# Calles internas horizontales rectas
				for t in range(1, num_tiers):
					var z_line := mz0 + float(t) * pitch_z
					var ep0 := _road_system.add_endpoint(Vector3(mx0, 0.0, z_line), Vector3(1.0, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
					var ep1 := _road_system.add_endpoint(Vector3(mx1, 0.0, z_line), Vector3(1.0, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
					var seg := _road_system.connect_endpoints(ep0.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
					_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

				# Cortes transversales en X rectos para todo el macro-bloque (sin quiebres!)
				var target_len := 150.0 if zone != CityRoadPatterns.NeighborhoodZoneType.ZONA_X else 200.0
				var num_cuts := maxi(int(round(mb_w / target_len)), 1)
				var pitch_x := mb_w / float(num_cuts)

				if num_cuts > 1:
					for c in range(1, num_cuts):
						var cut_x := mx0 + float(c) * pitch_x
						var ep0 := _road_system.add_endpoint(Vector3(cut_x, 0.0, mz0), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
						var ep1 := _road_system.add_endpoint(Vector3(cut_x, 0.0, mz1), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
						var seg := _road_system.connect_endpoints(ep0.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
						_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

				for t in range(num_tiers):
					var bz0 := mz0 + float(t) * pitch_z
					var bz1 := bz0 + pitch_z
					for c in range(num_cuts):
						var bx0 := mx0 + float(c) * pitch_x
						var bx1 := bx0 + pitch_x

						var block_rect := Rect2(
							Vector2(bx0 + margin, bz0 + margin),
							Vector2((bx1 - bx0) - margin * 2.0, (bz1 - bz0) - margin * 2.0)
						)
						if block_rect.size.x >= 14.0 and block_rect.size.y >= 14.0:
							out_blocks.append(block_rect)
							out_zones.append(zone)

			else:
				# CUADRA DE CASAS EN VERTICAL: calles corren en Z (Norte-Sur), profundidad en X
				var num_tiers := maxi(int(round(mb_w / (target_depth + corridor_w))), 1)
				var pitch_x := mb_w / float(num_tiers)

				# Calles internas verticales rectas
				for t in range(1, num_tiers):
					var x_line := mx0 + float(t) * pitch_x
					var ep0 := _road_system.add_endpoint(Vector3(x_line, 0.0, mz0), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
					var ep1 := _road_system.add_endpoint(Vector3(x_line, 0.0, mz1), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
					var seg := _road_system.connect_endpoints(ep0.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
					_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

				# Cortes transversales en Z rectos para todo el macro-bloque (sin quiebres!)
				var target_len := 150.0 if zone != CityRoadPatterns.NeighborhoodZoneType.ZONA_X else 200.0
				var num_cuts := maxi(int(round(mb_h / target_len)), 1)
				var pitch_z := mb_h / float(num_cuts)

				if num_cuts > 1:
					for c in range(1, num_cuts):
						var cut_z := mz0 + float(c) * pitch_z
						var ep0 := _road_system.add_endpoint(Vector3(mx0, 0.0, cut_z), Vector3(1.0, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
						var ep1 := _road_system.add_endpoint(Vector3(mx1, 0.0, cut_z), Vector3(1.0, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
						var seg := _road_system.connect_endpoints(ep0.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_2LANE)
						_road_system.set_both_sidewalks(seg.id, true, true, sw_w)

				for t in range(num_tiers):
					var bx0 := mx0 + float(t) * pitch_x
					var bx1 := bx0 + pitch_x
					for c in range(num_cuts):
						var bz0 := mz0 + float(c) * pitch_z
						var bz1 := bz0 + pitch_z

						var block_rect := Rect2(
							Vector2(bx0 + margin, bz0 + margin),
							Vector2((bx1 - bx0) - margin * 2.0, (bz1 - bz0) - margin * 2.0)
						)
						if block_rect.size.x >= 14.0 and block_rect.size.y >= 14.0:
							out_blocks.append(block_rect)
							out_zones.append(zone)


# ==============================================================================
# CAMELLONES CENTRALES, ÁRBOLES Y ARROYOS
# ==============================================================================

func _build_median_features(avenue_cfg: CityRoadPatterns.AvenueConfig, crossover_z: Array[float]) -> void:
	if avenue_cfg.type == CityRoadPatterns.AvenueType.COMMERCIAL_MAIN:
		return

	var m_w := avenue_cfg.median_width
	var half_m := m_w * 0.5
	var z_count := crossover_z.size()

	for i in range(z_count - 1):
		var z0: float = crossover_z[i]
		var z1: float = crossover_z[i + 1]
		# Dejar abertura en los cruces transversales
		var cross_gap := 9.0
		var seg_z0 := z0 + cross_gap
		var seg_z1 := z1 - cross_gap
		var seg_len := seg_z1 - seg_z0
		if seg_len <= 5.0:
			continue

		if avenue_cfg.has_stream:
			_create_stream_segment(seg_z0, seg_z1, m_w, avenue_cfg)
		else:
			_create_boulevard_median_segment(seg_z0, seg_z1, m_w, avenue_cfg)


func _create_boulevard_median_segment(z0: float, z1: float, m_w: float, avenue_cfg: CityRoadPatterns.AvenueConfig) -> void:
	var half_m := m_w * 0.5
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Median_Grass_%.0f" % z0
	var plane := PlaneMesh.new()
	plane.size = Vector2(m_w, z1 - z0)
	mesh_inst.mesh = plane

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.25, 0.42, 0.20) # Verde pasto cuidado de camellón
	grass_mat.roughness = 0.90
	mesh_inst.material_override = grass_mat
	mesh_inst.position = Vector3(0.0, 0.12, (z0 + z1) * 0.5)
	_median_root.add_child(mesh_inst)

	# Plantar árboles procedurales alineados en el camellón
	var tree_step: float = avenue_cfg.tree_spacing
	var tree_count := int(floor((z1 - z0) / tree_step))
	var start_z := z0 + ((z1 - z0) - float(tree_count - 1) * tree_step) * 0.5

	for t in range(tree_count):
		var tz := start_z + float(t) * tree_step
		var tree := ProceduralTree.new()
		tree.profile_id = "classic_oak" if _rng.randf() < 0.7 else "autumn_birch"
		tree.tree_seed = _rng.randi()
		_median_root.add_child(tree)
		tree.position = Vector3(_rng.randf_range(-0.4, 0.4), 0.12, tz)
		tree.rotation.y = _rng.randf_range(0.0, TAU)


func _create_stream_segment(z0: float, z1: float, m_w: float, avenue_cfg: CityRoadPatterns.AvenueConfig) -> void:
	var bed_w := avenue_cfg.stream_bed_width
	var half_len := (z1 - z0)

	# Pasto y taludes a los lados del canal
	var bank_mesh := MeshInstance3D.new()
	bank_mesh.name = "Stream_Bank_%.0f" % z0
	var bank_plane := PlaneMesh.new()
	bank_plane.size = Vector2(m_w, half_len)
	bank_mesh.mesh = bank_plane
	var bank_mat := StandardMaterial3D.new()
	bank_mat.albedo_color = Color(0.24, 0.38, 0.18) # Verde ribereño
	bank_mat.roughness = 0.90
	bank_mesh.material_override = bank_mat
	bank_mesh.position = Vector3(0.0, 0.04, (z0 + z1) * 0.5)
	_median_root.add_child(bank_mesh)

	# Lecho rocoso del canal
	var bed_mesh := MeshInstance3D.new()
	bed_mesh.name = "Stream_Bed_%.0f" % z0
	var bed_plane := PlaneMesh.new()
	bed_plane.size = Vector2(bed_w + 1.5, half_len)
	bed_mesh.mesh = bed_plane
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.35, 0.36, 0.32) # Gravilla / piedra de río
	stone_mat.roughness = 0.85
	bed_mesh.material_override = stone_mat
	bed_mesh.position = Vector3(0.0, 0.06, (z0 + z1) * 0.5)
	_median_root.add_child(bed_mesh)

	# Lámina de agua del arroyo
	var water_mesh := MeshInstance3D.new()
	water_mesh.name = "Stream_Water_%.0f" % z0
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(bed_w, half_len)
	water_mesh.mesh = water_plane
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.14, 0.48, 0.65, 0.92) # Azul agua cristalina
	water_mat.roughness = 0.08
	water_mat.metallic = 0.25
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mesh.material_override = water_mat
	water_mesh.position = Vector3(0.0, 0.09, (z0 + z1) * 0.5)
	_median_root.add_child(water_mesh)

	# Vegetación de ribera a los lados del arroyo con ProceduralTree
	var tree_step := avenue_cfg.tree_spacing * 1.2
	var tree_count := int(floor((z1 - z0) / tree_step))
	var start_z := z0 + ((z1 - z0) - float(tree_count - 1) * tree_step) * 0.5
	for t in range(tree_count):
		var tz := start_z + float(t) * tree_step
		for side in [-1.0, 1.0]:
			var tree := ProceduralTree.new()
			tree.profile_id = "weeping_willow" if _rng.randf() < 0.65 else "classic_oak"
			tree.tree_seed = _rng.randi()
			_median_root.add_child(tree)
			tree.position = Vector3(side * (bed_w * 0.5 + 2.0), 0.05, tz)
			tree.rotation.y = _rng.randf_range(0.0, TAU)



# ==============================================================================
# SUBDIVISIÓN DE MANZANAS EN PARCELAS / LOTES (block_parcels)
# ==============================================================================

func _build_parcels(blocks: Array[Rect2], avenue_cfg: CityRoadPatterns.AvenueConfig, hood_cfg: CityRoadPatterns.NeighborhoodConfig, block_zones: Array = []) -> void:
	block_rects = blocks
	block_parcels.clear()

	if show_parcel_outlines:
		_parcel_outline_root = Node3D.new()
		_parcel_outline_root.name = "ParcelOutlines"
		add_child(_parcel_outline_root)

	for b_idx in range(blocks.size()):
		var block := blocks[b_idx]
		
		# Determinar la zona de la manzana
		var eff_zone := neighborhood_zone
		if b_idx < block_zones.size() and block_zones[b_idx] != null:
			eff_zone = block_zones[b_idx]
		elif neighborhood_zone == CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS:
			var b_center := block.position + block.size * 0.5
			if b_center.x < 0.0:
				if b_center.y < 0.0:
					eff_zone = CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA
				else:
					eff_zone = CityRoadPatterns.NeighborhoodZoneType.ZONA_X
			else:
				eff_zone = CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA

		var block_prototype_seed := rng_seed + b_idx * 1337
		var lots := _subdivide_single_block(block, eff_zone, block_prototype_seed)
		for l_idx in range(lots.size()):
			var lot: Dictionary = lots[l_idx]
			lot["source_index"] = block_parcels.size()
			lot["block_index"] = b_idx
			lot["lot_index"] = l_idx
			lot["zone_type"] = eff_zone
			lot["prototype_seed"] = block_prototype_seed
			block_parcels.append(lot)

			if show_parcel_outlines and _parcel_outline_root != null:
				_add_parcel_outline_visual(lot["rect"])


func _subdivide_single_block(block: Rect2, zone: CityRoadPatterns.NeighborhoodZoneType, b_seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var w := block.size.x
	var h := block.size.y

	var b_rng := RandomNumberGenerator.new()
	b_rng.seed = b_seed

	if w >= h:
		# Manzana horizontal: calles en Norte y Sur. Slices a lo largo del eje X, fondo transversal en eje Y.
		var cur_x := block.position.x
		var end_x := block.position.x + w

		while cur_x < end_x - 0.5:
			var rem_x := end_x - cur_x
			var slice_len: float

			match zone:
				CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA:
					var target_len := 6.50
					var count := maxi(int(round(rem_x / target_len)), 1)
					slice_len = rem_x / float(count) if count == 1 else target_len

				CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA:
					if rem_x <= 15.0:
						slice_len = rem_x
					else:
						slice_len = b_rng.randf_range(8.0, 14.0)
						if rem_x - slice_len < 7.5:
							slice_len = rem_x * 0.5

				CityRoadPatterns.NeighborhoodZoneType.ZONA_X:
					if rem_x <= 46.0:
						slice_len = rem_x
					else:
						slice_len = b_rng.randf_range(22.0, 44.0)
						if rem_x - slice_len < 20.0:
							slice_len = rem_x * 0.5

				_:
					var count := maxi(int(round(rem_x / 12.0)), 1)
					slice_len = rem_x / float(count)

			# Partición en el eje transversal Y (fondo h entre Norte y Sur)
			# ¡Garantía matemática: depth_norte + depth_sur = h EXACTO (cero traslapes, cero vacíos)!
			match zone:
				CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA:
					var d := h * 0.50
					var r_n := Rect2(Vector2(cur_x, block.position.y), Vector2(slice_len, d))
					var r_s := Rect2(Vector2(cur_x, block.position.y + d), Vector2(slice_len, d))
					result.append({ "rect": r_n, "front_side": 0 })
					result.append({ "rect": r_s, "front_side": 2 })

				CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA:
					var split := b_rng.randf_range(0.46, 0.54)
					var d_n := h * split
					var d_s := h - d_n
					var r_n := Rect2(Vector2(cur_x, block.position.y), Vector2(slice_len, d_n))
					var r_s := Rect2(Vector2(cur_x, block.position.y + d_n), Vector2(slice_len, d_s))
					result.append({ "rect": r_n, "front_side": 0 })
					result.append({ "rect": r_s, "front_side": 2 })

				CityRoadPatterns.NeighborhoodZoneType.ZONA_X:
					var roll := b_rng.randf()
					if roll < 0.15 and slice_len >= 26.0 and slice_len <= 38.0:
						# Lote pasante / mega finca de doble frente (abarca todo el fondo de calle a calle)
						var r_full := Rect2(Vector2(cur_x, block.position.y), Vector2(slice_len, h))
						result.append({ "rect": r_full, "front_side": 0 })
					elif roll < 0.45 and slice_len >= 38.0:
						# Asimétrico: 1 lote monumental de un lado frente a 2 lotes en la espalda
						var wide_is_north := b_rng.randf() < 0.5
						var split := b_rng.randf_range(0.42, 0.48)
						var sub_len := slice_len * 0.5
						if wide_is_north:
							var d_n := h * split
							var d_s := h - d_n
							var r_n := Rect2(Vector2(cur_x, block.position.y), Vector2(slice_len, d_n))
							var r_s1 := Rect2(Vector2(cur_x, block.position.y + d_n), Vector2(sub_len, d_s))
							var r_s2 := Rect2(Vector2(cur_x + sub_len, block.position.y + d_n), Vector2(sub_len, d_s))
							result.append({ "rect": r_n, "front_side": 0 })
							result.append({ "rect": r_s1, "front_side": 2 })
							result.append({ "rect": r_s2, "front_side": 2 })
						else:
							var d_s := h * split
							var d_n := h - d_s
							var r_n1 := Rect2(Vector2(cur_x, block.position.y), Vector2(sub_len, d_n))
							var r_n2 := Rect2(Vector2(cur_x + sub_len, block.position.y), Vector2(sub_len, d_n))
							var r_s := Rect2(Vector2(cur_x, block.position.y + d_n), Vector2(slice_len, d_s))
							result.append({ "rect": r_n1, "front_side": 0 })
							result.append({ "rect": r_n2, "front_side": 0 })
							result.append({ "rect": r_s, "front_side": 2 })
					else:
						# Dos lotes espalda con espalda con fondo aleatorio complementario
						var split := b_rng.randf_range(0.38, 0.62)
						var d_n := h * split
						var d_s := h - d_n
						var r_n := Rect2(Vector2(cur_x, block.position.y), Vector2(slice_len, d_n))
						var r_s := Rect2(Vector2(cur_x, block.position.y + d_n), Vector2(slice_len, d_s))
						result.append({ "rect": r_n, "front_side": 0 })
						result.append({ "rect": r_s, "front_side": 2 })

				_:
					var d := h * 0.50
					var r_n := Rect2(Vector2(cur_x, block.position.y), Vector2(slice_len, d))
					var r_s := Rect2(Vector2(cur_x, block.position.y + d), Vector2(slice_len, d))
					result.append({ "rect": r_n, "front_side": 0 })
					result.append({ "rect": r_s, "front_side": 2 })

			cur_x += slice_len

	else:
		# Manzana vertical (más común, paralela a la avenida en eje Z)
		# Slices a lo largo del eje Z, fondo transversal en eje X (entre Oeste y Este).
		var cur_z := block.position.y
		var end_z := block.position.y + h

		while cur_z < end_z - 0.5:
			var rem_z := end_z - cur_z
			var slice_len: float

			match zone:
				CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA:
					var target_len := 6.50
					var count := maxi(int(round(rem_z / target_len)), 1)
					slice_len = rem_z / float(count) if count == 1 else target_len

				CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA:
					if rem_z <= 15.0:
						slice_len = rem_z
					else:
						slice_len = b_rng.randf_range(8.0, 14.0)
						if rem_z - slice_len < 7.5:
							slice_len = rem_z * 0.5

				CityRoadPatterns.NeighborhoodZoneType.ZONA_X:
					if rem_z <= 46.0:
						slice_len = rem_z
					else:
						slice_len = b_rng.randf_range(22.0, 44.0)
						if rem_z - slice_len < 20.0:
							slice_len = rem_z * 0.5

				_:
					var count := maxi(int(round(rem_z / 12.0)), 1)
					slice_len = rem_z / float(count)

			# Partición en el eje transversal X (fondo w entre Oeste y Este)
			# ¡Garantía matemática: depth_oeste + depth_este = w EXACTO (cero traslapes, cero vacíos)!
			match zone:
				CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA:
					var d := w * 0.50
					var r_w := Rect2(Vector2(block.position.x, cur_z), Vector2(d, slice_len))
					var r_e := Rect2(Vector2(block.position.x + d, cur_z), Vector2(d, slice_len))
					result.append({ "rect": r_w, "front_side": 3 })
					result.append({ "rect": r_e, "front_side": 1 })

				CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA:
					var split := b_rng.randf_range(0.46, 0.54)
					var d_w := w * split
					var d_e := w - d_w
					var r_w := Rect2(Vector2(block.position.x, cur_z), Vector2(d_w, slice_len))
					var r_e := Rect2(Vector2(block.position.x + d_w, cur_z), Vector2(d_e, slice_len))
					result.append({ "rect": r_w, "front_side": 3 })
					result.append({ "rect": r_e, "front_side": 1 })

				CityRoadPatterns.NeighborhoodZoneType.ZONA_X:
					var roll := b_rng.randf()
					if roll < 0.15 and slice_len >= 26.0 and slice_len <= 38.0:
						# Lote pasante / mega finca de doble frente (abarca todo el fondo de calle a calle)
						var r_full := Rect2(Vector2(block.position.x, cur_z), Vector2(w, slice_len))
						result.append({ "rect": r_full, "front_side": 3 })
					elif roll < 0.45 and slice_len >= 38.0:
						# Asimétrico: 1 lote monumental de un lado frente a 2 lotes en la espalda
						var wide_is_west := b_rng.randf() < 0.5
						var split := b_rng.randf_range(0.42, 0.48)
						var sub_len := slice_len * 0.5
						if wide_is_west:
							var d_w := w * split
							var d_e := w - d_w
							var r_w := Rect2(Vector2(block.position.x, cur_z), Vector2(d_w, slice_len))
							var r_e1 := Rect2(Vector2(block.position.x + d_w, cur_z), Vector2(d_e, sub_len))
							var r_e2 := Rect2(Vector2(block.position.x + d_w, cur_z + sub_len), Vector2(d_e, sub_len))
							result.append({ "rect": r_w, "front_side": 3 })
							result.append({ "rect": r_e1, "front_side": 1 })
							result.append({ "rect": r_e2, "front_side": 1 })
						else:
							var d_e := w * split
							var d_w := w - d_e
							var r_w1 := Rect2(Vector2(block.position.x, cur_z), Vector2(d_w, sub_len))
							var r_w2 := Rect2(Vector2(block.position.x, cur_z + sub_len), Vector2(d_w, sub_len))
							var r_e := Rect2(Vector2(block.position.x + d_w, cur_z), Vector2(d_e, slice_len))
							result.append({ "rect": r_w1, "front_side": 3 })
							result.append({ "rect": r_w2, "front_side": 3 })
							result.append({ "rect": r_e, "front_side": 1 })
					else:
						# Dos lotes espalda con espalda con fondo aleatorio complementario
						var split := b_rng.randf_range(0.38, 0.62)
						var d_w := w * split
						var d_e := w - d_w
						var r_w := Rect2(Vector2(block.position.x, cur_z), Vector2(d_w, slice_len))
						var r_e := Rect2(Vector2(block.position.x + d_w, cur_z), Vector2(d_e, slice_len))
						result.append({ "rect": r_w, "front_side": 3 })
						result.append({ "rect": r_e, "front_side": 1 })

				_:
					var d := w * 0.50
					var r_w := Rect2(Vector2(block.position.x, cur_z), Vector2(d, slice_len))
					var r_e := Rect2(Vector2(block.position.x + d, cur_z), Vector2(d, slice_len))
					result.append({ "rect": r_w, "front_side": 3 })
					result.append({ "rect": r_e, "front_side": 1 })

			cur_z += slice_len

	return result


func _add_parcel_outline_visual(rect: Rect2) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var y := 0.20
	im.surface_add_vertex(Vector3(rect.position.x, y, rect.position.y))
	im.surface_add_vertex(Vector3(rect.position.x + rect.size.x, y, rect.position.y))
	im.surface_add_vertex(Vector3(rect.position.x + rect.size.x, y, rect.position.y + rect.size.y))
	im.surface_add_vertex(Vector3(rect.position.x, y, rect.position.y + rect.size.y))
	im.surface_add_vertex(Vector3(rect.position.x, y, rect.position.y))
	im.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = parcel_outline_color
	mi.material_override = mat
	_parcel_outline_root.add_child(mi)


# ==============================================================================
# HUELLA FÍSICA TOTAL
# ==============================================================================

func _compute_footprint() -> void:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for seg in _road_system.get_all_segments():
		min_x = minf(min_x, minf(seg.start_pos.x - seg.width, seg.end_pos.x - seg.width))
		max_x = maxf(max_x, maxf(seg.start_pos.x + seg.width, seg.end_pos.x + seg.width))
		min_z = minf(min_z, minf(seg.start_pos.z - seg.width, seg.end_pos.z - seg.width))
		max_z = maxf(max_z, maxf(seg.start_pos.z + seg.width, seg.end_pos.z + seg.width))

	for b in block_rects:
		min_x = minf(min_x, b.position.x)
		max_x = maxf(max_x, b.position.x + b.size.x)
		min_z = minf(min_z, b.position.y)
		max_z = maxf(max_z, b.position.y + b.size.y)

	if min_x == INF:
		generated_footprint_aabb = AABB(Vector3(-100.0, 0.0, -100.0), Vector3(200.0, 10.0, 200.0))
	else:
		var size_x := maxf(max_x - min_x, 10.0)
		var size_z := maxf(max_z - min_z, 10.0)
		generated_footprint_aabb = AABB(Vector3(min_x, 0.0, min_z), Vector3(size_x, 25.0, size_z))


# ==============================================================================
# INTEGRACIÓN CON HOUSE_GENERATOR Y CITY_DECORATION
# ==============================================================================

func _create_house_generator() -> void:
	if not generate_houses or block_parcels.is_empty():
		return

	_house_generator = HOUSE_GENERATOR_SCRIPT.new() as HouseGenerator
	if _house_generator == null:
		return

	_house_generator.name = "HouseGenerator"
	_house_generator.auto_generate = false
	_house_generator.parcel_source_path = NodePath("..")
	_house_generator.house_count = block_parcels.size()
	_house_generator.randomize_seed_on_run = house_randomize_seed_on_run
	_house_generator.rng_seed = rng_seed + house_rng_seed_offset
	_house_generator.show_debug_labels = house_show_debug_labels
	_house_generator.show_roofs = house_show_roofs
	_house_generator.show_fences = house_show_fences
	_house_generator.fence_probability = house_fence_probability
	_house_generator.vacant_lot_probability = vacant_lot_probability
	_house_generator.front_yard_depth = 4.5
	_house_generator.rear_yard_depth = 2.5
	add_child(_house_generator)
	_house_generator.generate_houses()


func _create_decoration_generator() -> void:
	if not scatter_decorations or _house_generator == null:
		return

	_decoration_generator = DECORATION_GENERATOR_SCRIPT.new() as CityDecoration
	if _decoration_generator == null:
		return

	_decoration_generator.name = "CityDecoration"
	if decoration_randomize_seed_on_run:
		_decoration_generator.rng_seed = randi()
	else:
		_decoration_generator.rng_seed = rng_seed + decoration_rng_seed_offset

	add_child(_decoration_generator)
	_run_decoration_pass()


func _run_decoration_pass() -> void:
	if _decoration_generator != null and is_instance_valid(_decoration_generator) and _house_generator != null:
		_decoration_generator.generate_decorations(_house_generator)
