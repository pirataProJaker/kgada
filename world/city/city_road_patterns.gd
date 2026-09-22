extends RefCounted
class_name CityRoadPatterns
## Definiciones, especificaciones y reglas arquitectónicas de patrones viales
## para la generación automatizada de ciudades y colonias.

const RoadTrajectorySystem = preload("res://world/city/road_trajectory_system.gd")

## Dimensiones viales y peatonales según contexto
const LANE_WIDTH_RESIDENTIAL: float = RoadTrajectorySystem.LANE_WIDTH_RESIDENTIAL # 3.25m (calles de colonia)
const LANE_WIDTH_AVENUE: float = RoadTrajectorySystem.LANE_WIDTH_AVENUE           # 4.00m (avenidas y bulevares)
const LANE_WIDTH_HIGHWAY: float = RoadTrajectorySystem.LANE_WIDTH_HIGHWAY         # 4.00m (autopistas)
const STANDARD_LANE_WIDTH: float = LANE_WIDTH_RESIDENTIAL

const SIDEWALK_WIDTH_RESIDENTIAL: float = 2.0
const SIDEWALK_WIDTH_AVENUE: float = 3.0
const SIDEWALK_WIDTH_COMMERCIAL: float = 4.0

enum AvenueType {
	DIVIDED_BOULEVARD, # Avenida con 2 calzadas unidireccionales (3 carriles de 4m c/u = 12.00m) y camellón arbolado central
	STREAM_PARKWAY,    # Avenida dividida por un canal/arroyo natural (2 carriles de 4m c/u = 8.00m) con puentes en cruces
	COMMERCIAL_MAIN    # Avenida amplia continua de alta capacidad comercial (4 carriles de 4m = 16.00m)
}

enum NeighborhoodPattern {
	STAGGERED_GRID,    # Retícula residencial escalonada (cruces en T que calman el tráfico)
	RESIDENTIAL_LOOPS, # Manzanas con bucles que nacen y vuelven a la calle colectora
	CUL_DE_SAC_SUBURB  # Calles residenciales con retornos cerrados (privadas)
}

enum NeighborhoodZoneType {
	COLONIA_VIEJA, # Barrio tradicional: lotes variables, casas pared con pared (adosadas 100% al ancho del lote), muros ciegos laterales, estilos y colores variados
	COLONIA_NUEVA, # Fraccionamiento Infonavit: lotes simétricos estandarizados, casas idénticas serializadas
	ZONA_X,        # Zona residencial de lujo / riquillos: lotes gigantes, casas de lujo aisladas con amplios jardines a los 4 vientos
	ZONAS_MIXTAS   # Ciudad mixta: combina manzanas de colonias viejas, colonias nuevas y zonas de lujo
}


class AvenueConfig:
	var type: AvenueType
	var roadway_width: float = 12.00         # Ancho de cada calzada (carriles * 4.00m)
	var median_width: float = 8.0            # Ancho del camellón central o arroyo
	var road_type: RoadTrajectorySystem.RoadType = RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE
	var outer_sidewalk_width: float = SIDEWALK_WIDTH_AVENUE   # Banqueta exterior junto a los lotes
	var inner_sidewalk_width: float = 0.5    # Bordillo/banqueta interior bordeando el camellón
	var tree_spacing: float = 12.0           # Separación entre árboles plantados en el camellón
	var crossover_interval: float = 110.0    # Distancia entre aberturas de retorno en el camellón (cuadras reales amplias)
	var has_stream: bool = false             # Si el camellón aloja un arroyo/canal de agua
	var stream_bed_width: float = 6.0        # Ancho del cauce de agua
	var stream_depth: float = 1.6            # Profundidad del lecho
	var lot_depth: float = 35.0              # Fondo de los terrenos que flanquean la avenida


class StreetConfig:
	var width: float = 2.0 * LANE_WIDTH_RESIDENTIAL # 6.50m (2 carriles de 3.25m)
	var road_type: RoadTrajectorySystem.RoadType = RoadTrajectorySystem.RoadType.TWO_WAY_2LANE
	var sidewalk_width: float = SIDEWALK_WIDTH_RESIDENTIAL # 2.0m
	var has_left_sidewalk: bool = true
	var has_right_sidewalk: bool = true
	var lot_depth: float = 28.0


class NeighborhoodConfig:
	var pattern: NeighborhoodPattern
	var zone_type: NeighborhoodZoneType = NeighborhoodZoneType.COLONIA_VIEJA
	var primary_collector_width: float = 2.0 * LANE_WIDTH_RESIDENTIAL   # 6.50m
	var residential_street_width: float = 2.0 * LANE_WIDTH_RESIDENTIAL  # 6.50m
	var block_length: float = 110.0          # Cuadras amplias de 110m
	var block_depth: float = 72.0            # Profundidad de manzana de 72m
	var lot_frontage_min: float = 8.0
	var lot_frontage_max: float = 14.0
	var lot_depth: float = 28.0


static func get_avenue_config(type: AvenueType) -> AvenueConfig:
	var cfg := AvenueConfig.new()
	cfg.type = type
	match type:
		AvenueType.DIVIDED_BOULEVARD:
			cfg.roadway_width = 3.0 * LANE_WIDTH_AVENUE # 3 carriles de 4m por sentido = 12.00m
			cfg.road_type = RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_3LANE
			cfg.median_width = 8.0        # Camellón verde arbolado de 8m
			cfg.outer_sidewalk_width = SIDEWALK_WIDTH_AVENUE # 3.0m
			cfg.inner_sidewalk_width = 0.5
			cfg.tree_spacing = 12.0
			cfg.crossover_interval = 130.0
			cfg.has_stream = false
			cfg.lot_depth = 40.0

		AvenueType.STREAM_PARKWAY:
			cfg.roadway_width = 2.0 * LANE_WIDTH_AVENUE # 2 carriles de 4m por sentido = 8.00m
			cfg.road_type = RoadTrajectorySystem.RoadType.AVENUE_ONEWAY_2LANE
			cfg.median_width = 16.0       # Arroyo/canal central de 16m
			cfg.outer_sidewalk_width = SIDEWALK_WIDTH_AVENUE # 3.0m
			cfg.inner_sidewalk_width = 1.0
			cfg.tree_spacing = 14.0
			cfg.crossover_interval = 130.0
			cfg.has_stream = true
			cfg.stream_bed_width = 8.0
			cfg.stream_depth = 1.8
			cfg.lot_depth = 38.0

		AvenueType.COMMERCIAL_MAIN:
			cfg.roadway_width = 4.0 * LANE_WIDTH_AVENUE # 4 carriles de 4m (2 por sentido) = 16.00m
			cfg.road_type = RoadTrajectorySystem.RoadType.COMMERCIAL_4LANE
			cfg.median_width = 0.0        # Sin camellón o camellón plano
			cfg.outer_sidewalk_width = SIDEWALK_WIDTH_COMMERCIAL # 4.0m banquetas comerciales amplias
			cfg.inner_sidewalk_width = 0.0
			cfg.tree_spacing = 0.0
			cfg.crossover_interval = 120.0
			cfg.has_stream = false
			cfg.lot_depth = 42.0

	return cfg


static func get_neighborhood_config(pattern: NeighborhoodPattern) -> NeighborhoodConfig:
	var cfg := NeighborhoodConfig.new()
	cfg.pattern = pattern
	cfg.primary_collector_width = 2.0 * STANDARD_LANE_WIDTH # 6.50m
	cfg.residential_street_width = 2.0 * STANDARD_LANE_WIDTH # 6.50m
	match pattern:
		NeighborhoodPattern.STAGGERED_GRID:
			cfg.block_length = 130.0
			cfg.block_depth = 82.0
			cfg.lot_frontage_min = 8.0
			cfg.lot_frontage_max = 14.0
			cfg.lot_depth = 36.0

		NeighborhoodPattern.RESIDENTIAL_LOOPS:
			cfg.block_length = 140.0
			cfg.block_depth = 86.0
			cfg.lot_frontage_min = 8.0
			cfg.lot_frontage_max = 14.0
			cfg.lot_depth = 38.0

		NeighborhoodPattern.CUL_DE_SAC_SUBURB:
			cfg.block_length = 125.0
			cfg.block_depth = 80.0
			cfg.lot_frontage_min = 8.0
			cfg.lot_frontage_max = 14.0
			cfg.lot_depth = 35.0

	return cfg


static func get_zone_block_depth(zone: NeighborhoodZoneType) -> float:
	match zone:
		NeighborhoodZoneType.COLONIA_NUEVA:
			return 32.0 # Infonavit: 16m por lote espalda con espalda. Cero terreno baldío en medio.
		NeighborhoodZoneType.COLONIA_VIEJA:
			return 46.0 # Barrio tradicional: 23m por lote espalda con espalda.
		NeighborhoodZoneType.ZONA_X:
			return 85.0 # Residencial de lujo: 42.5m por lote para mansiones con amplios jardines.
		_:
			return 46.0


static func get_zone_lot_depth(zone: NeighborhoodZoneType) -> float:
	return get_zone_block_depth(zone) * 0.5


static func get_default_residential_street() -> StreetConfig:
	var cfg := StreetConfig.new()
	cfg.width = 2.0 * STANDARD_LANE_WIDTH # 6.50m
	cfg.road_type = RoadTrajectorySystem.RoadType.TWO_WAY_2LANE
	cfg.sidewalk_width = SIDEWALK_WIDTH_RESIDENTIAL # 2.0m
	cfg.has_left_sidewalk = true
	cfg.has_right_sidewalk = true
	cfg.lot_depth = 19.0
	return cfg
