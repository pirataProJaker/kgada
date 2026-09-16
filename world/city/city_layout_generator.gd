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
@export_range(160.0, 480.0, 20.0) var city_length: float = 240.0
@export_range(1, 3, 1) var neighborhood_blocks_per_side: int = 2

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
	_build_parcels(layout_data["blocks"], avenue_cfg, hood_cfg)

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
	var crossover_interval: float = avenue_cfg.crossover_interval
	var crossover_count := clampi(int(round(city_length / crossover_interval)), 2, 6)
	var step_z := city_length / float(crossover_count)

	var crossover_z: Array[float] = []
	for i in range(crossover_count + 1):
		var z := -half_len + float(i) * step_z
		crossover_z.append(z)

	var blocks: Array[Rect2] = []

	if avenue_cfg.type == CityRoadPatterns.AvenueType.COMMERCIAL_MAIN:
		_build_commercial_avenue(avenue_cfg, crossover_z)
	else:
		_build_divided_avenue(avenue_cfg, crossover_z, hood_cfg)

	# Trazado de colonias a ambos lados (Oeste y Este)
	var west_blocks := _build_neighborhood_half(avenue_cfg, hood_cfg, crossover_z, -1.0)
	var east_blocks := _build_neighborhood_half(avenue_cfg, hood_cfg, crossover_z, 1.0)

	blocks.append_array(west_blocks)
	blocks.append_array(east_blocks)

	return {
		"crossover_z": crossover_z,
		"blocks": blocks
	}


func _build_divided_avenue(avenue_cfg: CityRoadPatterns.AvenueConfig, crossover_z: Array[float], hood_cfg: CityRoadPatterns.NeighborhoodConfig = null) -> void:
	var r_w := avenue_cfg.roadway_width
	var m_w := avenue_cfg.median_width
	var x_west := -(m_w * 0.5 + r_w * 0.5)
	var x_east := +(m_w * 0.5 + r_w * 0.5)
	var cross_w: float = hood_cfg.primary_collector_width if hood_cfg != null else 8.5

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
		var ep_c_w := _road_system.add_endpoint(Vector3(x_west, 0.0, z_c), Vector3(1.0, 0.0, 0.0), cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
		var ep_c_e := _road_system.add_endpoint(Vector3(x_east, 0.0, z_c), Vector3(1.0, 0.0, 0.0), cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
		var seg_cross = _road_system.connect_endpoints(ep_c_w.id, ep_c_e.id, cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
		if i == 0:
			# Extremo Norte de la avenida: banqueta exterior continua cerrando la avenida hacia el Norte (lado izquierdo)
			_road_system.set_sidewalk(seg_cross.id, true, true, 2.2)
			_road_system.set_sidewalk(seg_cross.id, false, false)
		elif i == z_count - 1:
			# Extremo Sur de la avenida: banqueta exterior continua cerrando la avenida hacia el Sur (lado derecho)
			_road_system.set_sidewalk(seg_cross.id, true, false)
			_road_system.set_sidewalk(seg_cross.id, false, true, 2.2)
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


## Construye medio cuadrante de colonia residencial (lado Oeste side_sign=-1, o Este side_sign=+1)
func _build_neighborhood_half(
	avenue_cfg: CityRoadPatterns.AvenueConfig,
	hood_cfg: CityRoadPatterns.NeighborhoodConfig,
	crossover_z: Array[float],
	side_sign: float
) -> Array[Rect2]:
	var blocks: Array[Rect2] = []
	var r_w := avenue_cfg.roadway_width
	var m_w := avenue_cfg.median_width

	var avenue_center_x: float
	var avenue_outer_x: float
	if avenue_cfg.type == CityRoadPatterns.AvenueType.COMMERCIAL_MAIN:
		avenue_center_x = 0.0
		avenue_outer_x = side_sign * (r_w * 0.5)
	else:
		avenue_center_x = side_sign * (m_w * 0.5 + r_w * 0.5)
		avenue_outer_x = side_sign * (m_w * 0.5 + r_w)

	var block_depth := hood_cfg.block_depth
	var num_blocks := neighborhood_blocks_per_side
	var z_count := crossover_z.size()

	# Calles transversales colectoras que entran a la colonia
	var cross_w := hood_cfg.primary_collector_width
	var res_w := hood_cfg.residential_street_width

	# Tiers en X: tier 0 = eje de la calzada de avenida, tiers 1..N = calles residenciales
	var x_tiers: Array[float] = [avenue_center_x]
	for b in range(1, num_blocks + 1):
		var x := avenue_outer_x + side_sign * (float(b) * block_depth)
		x_tiers.append(x)

	# 1. Calles transversales colectoras: conectar tramo por tramo entre cada tier (0->1, 1->2, ...)
	# De esta forma cada cruce con una calle longitudinal es un nodo compartido real (intersección +).
	for z_c in crossover_z:
		var dir_x := Vector3(side_sign, 0.0, 0.0)
		for b in range(num_blocks):
			var x0: float = x_tiers[b]
			var x1: float = x_tiers[b + 1]
			var ep_start := _road_system.add_endpoint(Vector3(x0, 0.0, z_c), dir_x, cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
			var ep_end := _road_system.add_endpoint(Vector3(x1, 0.0, z_c), dir_x, cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
			var seg = _road_system.connect_endpoints(ep_start.id, ep_end.id, cross_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
			_road_system.set_sidewalk(seg.id, true, true, 2.2)
			_road_system.set_sidewalk(seg.id, false, true, 2.2)

	# 2. Calles longitudinales residenciales y calles intermedias
	for b in range(1, num_blocks + 1):
		var street_x: float = x_tiers[b]
		for i in range(z_count - 1):
			var z0: float = crossover_z[i]
			var z1: float = crossover_z[i + 1]
			var mid_z := (z0 + z1) * 0.5

			match hood_cfg.pattern:
				CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID:
					if b == num_blocks and b > 1:
						# En el bloque exterior, se divide en dos tramos longitudinales en mid_z
						var ep0 := _road_system.add_endpoint(Vector3(street_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var ep_m := _road_system.add_endpoint(Vector3(street_x, 0.0, mid_z), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var ep1 := _road_system.add_endpoint(Vector3(street_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var seg0 = _road_system.connect_endpoints(ep0.id, ep_m.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg0.id, true, true, 2.0)
						_road_system.set_sidewalk(seg0.id, false, true, 2.0)

						var seg1 = _road_system.connect_endpoints(ep_m.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg1.id, true, true, 2.0)
						_road_system.set_sidewalk(seg1.id, false, true, 2.0)

						# Calle intermedia transversal que forma cruces en T
						var prev_x: float = x_tiers[b - 1]
						var ep_t0 := _road_system.add_endpoint(Vector3(prev_x, 0.0, mid_z), Vector3(side_sign, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var seg_t = _road_system.connect_endpoints(ep_t0.id, ep_m.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg_t.id, true, true, 2.0)
						_road_system.set_sidewalk(seg_t.id, false, true, 2.0)
					else:
						# Si es el tier anterior al exterior, también lo dividimos en mid_z para recibir el cruce en T
						var ep0 := _road_system.add_endpoint(Vector3(street_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var ep_m := _road_system.add_endpoint(Vector3(street_x, 0.0, mid_z), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var ep1 := _road_system.add_endpoint(Vector3(street_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var seg0 = _road_system.connect_endpoints(ep0.id, ep_m.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg0.id, true, true, 2.0)
						_road_system.set_sidewalk(seg0.id, false, true, 2.0)

						var seg1 = _road_system.connect_endpoints(ep_m.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg1.id, true, true, 2.0)
						_road_system.set_sidewalk(seg1.id, false, true, 2.0)

				CityRoadPatterns.NeighborhoodPattern.CUL_DE_SAC_SUBURB:
					if b < num_blocks:
						var ep0 := _road_system.add_endpoint(Vector3(street_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var ep_m := _road_system.add_endpoint(Vector3(street_x, 0.0, mid_z), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var ep1 := _road_system.add_endpoint(Vector3(street_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var seg0 = _road_system.connect_endpoints(ep0.id, ep_m.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg0.id, true, true, 2.0)
						_road_system.set_sidewalk(seg0.id, false, true, 2.0)

						var seg1 = _road_system.connect_endpoints(ep_m.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg1.id, true, true, 2.0)
						_road_system.set_sidewalk(seg1.id, false, true, 2.0)

						# Cerrada residencial adentrándose en el bloque exterior
						var next_x: float = x_tiers[b + 1]
						var ep_c_end := _road_system.add_endpoint(Vector3(next_x, 0.0, mid_z), Vector3(side_sign, 0.0, 0.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						var seg_c = _road_system.connect_endpoints(ep_m.id, ep_c_end.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
						_road_system.set_sidewalk(seg_c.id, true, true, 2.0)
						_road_system.set_sidewalk(seg_c.id, false, true, 2.0)

				CityRoadPatterns.NeighborhoodPattern.RESIDENTIAL_LOOPS, _:
					var ep0 := _road_system.add_endpoint(Vector3(street_x, 0.0, z0), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
					var ep1 := _road_system.add_endpoint(Vector3(street_x, 0.0, z1), Vector3(0.0, 0.0, 1.0), res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
					var seg = _road_system.connect_endpoints(ep0.id, ep1.id, res_w, RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW)
					_road_system.set_sidewalk(seg.id, true, true, 2.0)
					_road_system.set_sidewalk(seg.id, false, true, 2.0)

			# 3. Registrar manzanas para generación de parcelas
			var x_inner: float = avenue_outer_x if b == 1 else x_tiers[b - 1]
			var x_outer: float = x_tiers[b]
			var x_a := minf(x_inner, x_outer)
			var x_b := maxf(x_inner, x_outer)
			var margin_x := (res_w * 0.5 + 2.5)
			var margin_z := (cross_w * 0.5 + 2.2)

			# Si la manzana exterior está dividida por una calle intermedia en mid_z:
			var has_subdivision := (hood_cfg.pattern == CityRoadPatterns.NeighborhoodPattern.STAGGERED_GRID and b == num_blocks) or \
				(hood_cfg.pattern == CityRoadPatterns.NeighborhoodPattern.CUL_DE_SAC_SUBURB and b == num_blocks)

			if has_subdivision:
				var z_min := minf(z0, z1)
				var z_max := maxf(z0, z1)
				var rect1 := Rect2(
					Vector2(x_a + margin_x, z_min + margin_z),
					Vector2((x_b - x_a) - margin_x * 2.0, (mid_z - z_min) - margin_z * 2.0)
				)
				if rect1.size.x > 14.0 and rect1.size.y > 14.0:
					blocks.append(rect1)

				var rect2 := Rect2(
					Vector2(x_a + margin_x, mid_z + margin_z),
					Vector2((x_b - x_a) - margin_x * 2.0, (z_max - mid_z) - margin_z * 2.0)
				)
				if rect2.size.x > 14.0 and rect2.size.y > 14.0:
					blocks.append(rect2)
			else:
				var z_min := minf(z0, z1)
				var z_max := maxf(z0, z1)
				var inner_rect := Rect2(
					Vector2(x_a + margin_x, z_min + margin_z),
					Vector2((x_b - x_a) - margin_x * 2.0, (z_max - z_min) - margin_z * 2.0)
				)
				if inner_rect.size.x > 14.0 and inner_rect.size.y > 14.0:
					blocks.append(inner_rect)

	return blocks


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

func _build_parcels(blocks: Array[Rect2], avenue_cfg: CityRoadPatterns.AvenueConfig, hood_cfg: CityRoadPatterns.NeighborhoodConfig) -> void:
	block_rects = blocks
	block_parcels.clear()

	if show_parcel_outlines:
		_parcel_outline_root = Node3D.new()
		_parcel_outline_root.name = "ParcelOutlines"
		add_child(_parcel_outline_root)

	var lot_f_min := hood_cfg.lot_frontage_min
	var lot_f_max := hood_cfg.lot_frontage_max
	var lot_d := hood_cfg.lot_depth

	for b_idx in range(blocks.size()):
		var block := blocks[b_idx]
		var lots := _subdivide_single_block(block, lot_f_min, lot_f_max, lot_d)
		for l_idx in range(lots.size()):
			var lot: Dictionary = lots[l_idx]
			lot["source_index"] = block_parcels.size()
			lot["block_index"] = b_idx
			lot["lot_index"] = l_idx
			block_parcels.append(lot)

			if show_parcel_outlines and _parcel_outline_root != null:
				_add_parcel_outline_visual(lot["rect"])


func _subdivide_single_block(block: Rect2, f_min: float, f_max: float, depth: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var w := block.size.x
	var h := block.size.y

	# Si la manzana es alargada horizontalmente (eje X mayor que Z)
	if w >= h:
		# Fila Norte (lotes mirando al Norte, front_side = 0)
		var lots_n := _divide_edge_into_lots(block.position.x, w, f_min, f_max)
		for l in lots_n:
			var lot_rect := Rect2(Vector2(l["start"], block.position.y), Vector2(l["len"], minf(depth, h * 0.5)))
			result.append({ "rect": lot_rect, "front_side": 0 })

		# Fila Sur (lotes mirando al Sur, front_side = 2)
		var lots_s := _divide_edge_into_lots(block.position.x, w, f_min, f_max)
		for l in lots_s:
			var lot_rect := Rect2(Vector2(l["start"], block.position.y + h - minf(depth, h * 0.5)), Vector2(l["len"], minf(depth, h * 0.5)))
			result.append({ "rect": lot_rect, "front_side": 2 })
	else:
		# Fila Oeste (lotes mirando al Oeste, front_side = 3)
		var lots_w := _divide_edge_into_lots(block.position.y, h, f_min, f_max)
		for l in lots_w:
			var lot_rect := Rect2(Vector2(block.position.x, l["start"]), Vector2(minf(depth, w * 0.5), l["len"]))
			result.append({ "rect": lot_rect, "front_side": 3 })

		# Fila Este (lotes mirando al Este, front_side = 1)
		var lots_e := _divide_edge_into_lots(block.position.y, h, f_min, f_max)
		for l in lots_e:
			var lot_rect := Rect2(Vector2(block.position.x + w - minf(depth, w * 0.5), l["start"]), Vector2(minf(depth, w * 0.5), l["len"]))
			result.append({ "rect": lot_rect, "front_side": 1 })

	return result


func _divide_edge_into_lots(start_coord: float, total_length: float, f_min: float, f_max: float) -> Array[Dictionary]:
	var lots: Array[Dictionary] = []
	if total_length < f_min:
		return lots

	var count := clampi(int(round(total_length / ((f_min + f_max) * 0.5))), 1, 16)
	var avg_len := total_length / float(count)
	var cur := start_coord

	for i in range(count):
		var lot_len := avg_len
		if i < count - 1:
			var var_span := minf(avg_len - f_min, f_max - avg_len) * 0.4
			lot_len += _rng.randf_range(-var_span, var_span)
		else:
			lot_len = (start_coord + total_length) - cur

		lots.append({
			"start": cur,
			"len": lot_len
		})
		cur += lot_len

	return lots


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
	_house_generator.call_deferred("generate_houses")


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
	call_deferred("_run_decoration_pass")


func _run_decoration_pass() -> void:
	if _decoration_generator != null and is_instance_valid(_decoration_generator) and _house_generator != null:
		_decoration_generator.generate_decorations(_house_generator)
