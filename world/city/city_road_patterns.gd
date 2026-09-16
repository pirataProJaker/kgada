extends RefCounted
class_name CityRoadPatterns
## Definiciones, especificaciones y reglas arquitectónicas de patrones viales
## para la generación automatizada de ciudades y colonias.

const RoadTrajectorySystem = preload("res://world/city/road_trajectory_system.gd")

enum AvenueType {
	DIVIDED_BOULEVARD, # Avenida con 2 calzadas unidireccionales y camellón arbolado central
	STREAM_PARKWAY,    # Avenida dividida por un canal/arroyo natural con puentes en cruces
	COMMERCIAL_MAIN    # Avenida amplia continua de alta capacidad comercial
}

enum NeighborhoodPattern {
	STAGGERED_GRID,    # Retícula residencial escalonada (cruces en T que calman el tráfico)
	RESIDENTIAL_LOOPS, # Manzanas con bucles que nacen y vuelven a la calle colectora
	CUL_DE_SAC_SUBURB  # Calles residenciales con retornos cerrados (privadas)
}


class AvenueConfig:
	var type: AvenueType
	var roadway_width: float = 9.0           # Ancho de cada calzada (3 carriles = ~9m, 2 carriles = ~7m)
	var median_width: float = 8.0            # Ancho del camellón central o arroyo
	var road_type: RoadTrajectorySystem.RoadType = RoadTrajectorySystem.RoadType.AVENUE_WHITE
	var outer_sidewalk_width: float = 3.0    # Banqueta exterior junto a los lotes
	var inner_sidewalk_width: float = 0.5    # Bordillo/banqueta interior bordeando el camellón
	var tree_spacing: float = 12.0           # Separación entre árboles plantados en el camellón
	var crossover_interval: float = 80.0     # Distancia entre aberturas de retorno en el camellón
	var has_stream: bool = false             # Si el camellón aloja un arroyo/canal de agua
	var stream_bed_width: float = 6.0        # Ancho del cauce de agua
	var stream_depth: float = 1.6            # Profundidad del lecho
	var lot_depth: float = 24.0              # Fondo de los terrenos que flanquean la avenida


class StreetConfig:
	var width: float = 8.0
	var road_type: RoadTrajectorySystem.RoadType = RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW
	var sidewalk_width: float = 2.5
	var has_left_sidewalk: bool = true
	var has_right_sidewalk: bool = true
	var lot_depth: float = 20.0


class NeighborhoodConfig:
	var pattern: NeighborhoodPattern
	var primary_collector_width: float = 8.5
	var residential_street_width: float = 7.5
	var block_length: float = 80.0
	var block_depth: float = 48.0
	var lot_frontage_min: float = 11.0
	var lot_frontage_max: float = 16.0
	var lot_depth: float = 19.0


static func get_avenue_config(type: AvenueType) -> AvenueConfig:
	var cfg := AvenueConfig.new()
	cfg.type = type
	match type:
		AvenueType.DIVIDED_BOULEVARD:
			cfg.roadway_width = 9.0       # 3 carriles por sentido
			cfg.median_width = 8.0        # Camellón verde arbolado de 8m
			cfg.outer_sidewalk_width = 3.0
			cfg.inner_sidewalk_width = 0.5
			cfg.tree_spacing = 10.0
			cfg.crossover_interval = 80.0
			cfg.has_stream = false
			cfg.lot_depth = 26.0

		AvenueType.STREAM_PARKWAY:
			cfg.roadway_width = 7.5       # 2 carriles por sentido
			cfg.median_width = 16.0       # Arroyo/canal central de 16m
			cfg.outer_sidewalk_width = 2.5
			cfg.inner_sidewalk_width = 1.0
			cfg.tree_spacing = 14.0
			cfg.crossover_interval = 90.0
			cfg.has_stream = true
			cfg.stream_bed_width = 8.0
			cfg.stream_depth = 1.8
			cfg.lot_depth = 24.0

		AvenueType.COMMERCIAL_MAIN:
			cfg.roadway_width = 14.0      # Calzada ancha comercial
			cfg.median_width = 0.0        # Sin camellón o camellón angosto
			cfg.road_type = RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW
			cfg.outer_sidewalk_width = 4.0 # Banquetas muy anchas para comercio
			cfg.inner_sidewalk_width = 0.0
			cfg.tree_spacing = 0.0
			cfg.crossover_interval = 60.0
			cfg.has_stream = false
			cfg.lot_depth = 28.0

	return cfg


static func get_neighborhood_config(pattern: NeighborhoodPattern) -> NeighborhoodConfig:
	var cfg := NeighborhoodConfig.new()
	cfg.pattern = pattern
	match pattern:
		NeighborhoodPattern.STAGGERED_GRID:
			cfg.primary_collector_width = 8.0
			cfg.residential_street_width = 7.0
			cfg.block_length = 75.0
			cfg.block_depth = 52.0
			cfg.lot_frontage_min = 12.0
			cfg.lot_frontage_max = 18.0
			cfg.lot_depth = 24.0

		NeighborhoodPattern.RESIDENTIAL_LOOPS:
			cfg.primary_collector_width = 8.0
			cfg.residential_street_width = 7.0
			cfg.block_length = 85.0
			cfg.block_depth = 54.0
			cfg.lot_frontage_min = 12.0
			cfg.lot_frontage_max = 18.0
			cfg.lot_depth = 24.0

		NeighborhoodPattern.CUL_DE_SAC_SUBURB:
			cfg.primary_collector_width = 8.0
			cfg.residential_street_width = 6.5
			cfg.block_length = 65.0
			cfg.block_depth = 50.0
			cfg.lot_frontage_min = 12.0
			cfg.lot_frontage_max = 18.0
			cfg.lot_depth = 22.0

	return cfg


static func get_default_residential_street() -> StreetConfig:
	var cfg := StreetConfig.new()
	cfg.width = 7.5
	cfg.road_type = RoadTrajectorySystem.RoadType.TWO_WAY_YELLOW
	cfg.sidewalk_width = 2.2
	cfg.has_left_sidewalk = true
	cfg.has_right_sidewalk = true
	cfg.lot_depth = 19.0
	return cfg
