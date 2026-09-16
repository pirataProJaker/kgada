extends RefCounted
class_name ProceduralTreeProfiles
## Catalogo de especies y perfiles clasificados para la generacion procedural
## de arboles en diferentes biomas y bosques.
## Cada perfil define las reglas parametricas de escala, ramificacion, conos y follaje.

class TreeProfile:
	var id: String = ""
	var name: String = ""
	var biome_description: String = ""
	
	# Parametros del tronco
	var trunk_height_min: float = 6.0
	var trunk_height_max: float = 9.0
	var trunk_radius_base: float = 0.50
	var trunk_segments: int = 6
	var trunk_taper: float = 0.82 # Ratio de conicidad por segmento
	var trunk_max_tilt_deg: float = 6.0 # Inclinacion maxima entre segmentos consecutivos
	var trunk_split_chance: float = 0.25 # Probabilidad de bifurcacion principal
	
	# Parametros de ramificacion jerarquica (ramas sobre ramas)
	var branch_start_ratio: float = 0.35 # Altura minima relativa del tronco donde empiezan ramas
	var branch_density: int = 14 # Cantidad de ramas primarias (Nivel 1)
	var branch_length_ratio: float = 0.55 # Longitud relativa al tronco
	var branch_elevation_deg: float = 35.0 # Angulo hacia arriba respecto a la horizontal
	var branch_droop: float = 0.0 # Caida/curvatura hacia el suelo
	var branch_radius_ratio: float = 0.48 # Radio base de la rama relativo al tronco
	var branch_segments: int = 3 # Segmentos de cono por rama principal
	var secondary_branches_per_branch: int = 3 # Ramas secundarias (Nivel 2) por cada rama primaria
	var twigs_per_secondary: int = 2 # Brotes terciarios (Nivel 3) por cada rama secundaria
	
	# Parametros de follaje (hojas triangulares)
	var has_leaves: bool = true
	var leaves_per_tip: int = 6 # Hojas fanning en abanico por cada punta/brote
	var leaf_size: float = 0.85 # Tamano del triangulo (base a punta)
	var leaf_spread_radius: float = 0.50 # Expansion del abanico alrededor del brote
	var leaf_conical_cluster: bool = false # Si es true, forma penachos conicos de aguja (pino)
	
	# Colores base
	var bark_color: Color = Color(0.32, 0.22, 0.15)
	var leaf_color_primary: Color = Color(0.18, 0.48, 0.15)
	var leaf_color_secondary: Color = Color(0.24, 0.58, 0.18)


## Obtiene la lista con todos los IDs de perfiles disponibles.
static func get_profile_ids() -> Array[String]:
	return [
		"pine_boreal",
		"classic_oak",
		"autumn_birch",
		"weeping_willow",
		"dead_tree",
		"shrub_sapling"
	]


## Devuelve un perfil configurado segun su ID.
static func get_profile(profile_id: String) -> TreeProfile:
	match profile_id.to_lower():
		"pine_boreal", "pine", "canada":
			return _create_pine_boreal()
		"classic_oak", "oak", "green":
			return _create_classic_oak()
		"autumn_birch", "birch", "autumn", "yellow":
			return _create_autumn_birch()
		"weeping_willow", "willow":
			return _create_weeping_willow()
		"dead_tree", "dead", "burnt":
			return _create_dead_tree()
		"shrub_sapling", "shrub", "bush":
			return _create_shrub_sapling()
		_:
			push_warning("[ProceduralTreeProfiles] Perfil desconocido '%s', usando classic_oak" % profile_id)
			return _create_classic_oak()


# --- DEFINICIONES DE BIOMAS Y ESPECIES ---

## 1. Conifera / Pino Canadiense (Bosque boreal / Taiga)
## Tronco recto y conico, ramas horizontales escalonadas, agujas de pino.
static func _create_pine_boreal() -> TreeProfile:
	var p := TreeProfile.new()
	p.id = "pine_boreal"
	p.name = "Pino Canadiense (Boreal)"
	p.biome_description = "Bosque boreal o taiga con coniferas rectas de gran porte."
	
	p.trunk_height_min = 9.0
	p.trunk_height_max = 13.0
	p.trunk_radius_base = 0.65 # Tronco robusto
	p.trunk_segments = 7
	p.trunk_taper = 0.82
	p.trunk_max_tilt_deg = 2.0 # Muy vertical
	p.trunk_split_chance = 0.0
	
	p.branch_start_ratio = 0.18 # Ramas densas desde abajo
	p.branch_density = 20
	p.branch_length_ratio = 0.45
	p.branch_elevation_deg = 10.0 # Ramas horizontales hacia afuera
	p.branch_droop = 0.16
	p.branch_radius_ratio = 0.50
	p.branch_segments = 2
	p.secondary_branches_per_branch = 3
	p.twigs_per_secondary = 2
	
	p.has_leaves = true
	p.leaves_per_tip = 5
	p.leaf_size = 1.35
	p.leaf_spread_radius = 0.65
	p.leaf_conical_cluster = true
	
	p.bark_color = Color(0.24, 0.16, 0.11)
	p.leaf_color_primary = Color(0.08, 0.26, 0.12)
	p.leaf_color_secondary = Color(0.14, 0.35, 0.18)
	return p


## 2. Roble Clasico Templado (Bosque caducifolio templado)
## Tronco robusto y bifurcado, ramas amplias en copa redondeada, hojas verdes.
static func _create_classic_oak() -> TreeProfile:
	var p := TreeProfile.new()
	p.id = "classic_oak"
	p.name = "Roble Templado (Clasico)"
	p.biome_description = "Bosque templado con copas anchas, robustas y frondosas."
	
	p.trunk_height_min = 6.5
	p.trunk_height_max = 9.5
	p.trunk_radius_base = 0.78 # Tronco muy robusto y ancho
	p.trunk_segments = 6
	p.trunk_taper = 0.82
	p.trunk_max_tilt_deg = 7.0
	p.trunk_split_chance = 0.75 # Grandes andamios bifurcados
	
	p.branch_start_ratio = 0.35
	p.branch_density = 16
	p.branch_length_ratio = 0.72 # Ramas que se abren ampliamente hacia los lados
	p.branch_elevation_deg = 25.0 # Elevacion lateral amplia
	p.branch_droop = 0.08
	p.branch_radius_ratio = 0.55
	p.branch_segments = 3
	p.secondary_branches_per_branch = 3
	p.twigs_per_secondary = 2
	
	p.has_leaves = true
	p.leaves_per_tip = 5
	p.leaf_size = 1.45
	p.leaf_spread_radius = 0.75
	p.leaf_conical_cluster = false
	
	p.bark_color = Color(0.34, 0.23, 0.15)
	p.leaf_color_primary = Color(0.18, 0.50, 0.14)
	p.leaf_color_secondary = Color(0.26, 0.60, 0.18)
	return p


## 3. Abedul / Alamo Dorado (Bosque de otono)
## Tronco claro, ramas ascendentes pobladas, follaje dorado/naranja abundante.
static func _create_autumn_birch() -> TreeProfile:
	var p := TreeProfile.new()
	p.id = "autumn_birch"
	p.name = "Abedul Dorado (Otono)"
	p.biome_description = "Bosque de transicion otonal con copa dorada espesa y tronco claro."
	
	p.trunk_height_min = 7.5
	p.trunk_height_max = 11.0
	p.trunk_radius_base = 0.52
	p.trunk_segments = 6
	p.trunk_taper = 0.82
	p.trunk_max_tilt_deg = 5.0
	p.trunk_split_chance = 0.30
	
	p.branch_start_ratio = 0.40
	p.branch_density = 15
	p.branch_length_ratio = 0.62
	p.branch_elevation_deg = 35.0
	p.branch_droop = 0.04
	p.branch_radius_ratio = 0.50
	p.branch_segments = 3
	p.secondary_branches_per_branch = 3
	p.twigs_per_secondary = 2
	
	p.has_leaves = true
	p.leaves_per_tip = 5
	p.leaf_size = 1.40
	p.leaf_spread_radius = 0.75
	p.leaf_conical_cluster = false
	
	p.bark_color = Color(0.74, 0.71, 0.66)
	p.leaf_color_primary = Color(0.94, 0.70, 0.10)
	p.leaf_color_secondary = Color(0.88, 0.46, 0.08)
	return p


## 4. Sauce Lloron (Humedal / Ribera)
## Ramas arqueadas con caida pronunciada hacia el suelo y follaje colgante frondoso.
static func _create_weeping_willow() -> TreeProfile:
	var p := TreeProfile.new()
	p.id = "weeping_willow"
	p.name = "Sauce Lloron (Humedal)"
	p.biome_description = "Riberas y humedales con ramas arqueadas colgantes y follaje denso."
	
	p.trunk_height_min = 6.0
	p.trunk_height_max = 8.5
	p.trunk_radius_base = 0.68
	p.trunk_segments = 5
	p.trunk_taper = 0.82
	p.trunk_max_tilt_deg = 10.0
	p.trunk_split_chance = 0.65
	
	p.branch_start_ratio = 0.35
	p.branch_density = 16
	p.branch_length_ratio = 0.75
	p.branch_elevation_deg = 20.0
	p.branch_droop = 0.60
	p.branch_radius_ratio = 0.50
	p.branch_segments = 4
	p.secondary_branches_per_branch = 3
	p.twigs_per_secondary = 2
	
	p.has_leaves = true
	p.leaves_per_tip = 6
	p.leaf_size = 1.50
	p.leaf_spread_radius = 0.80
	p.leaf_conical_cluster = false
	
	p.bark_color = Color(0.28, 0.22, 0.17)
	p.leaf_color_primary = Color(0.30, 0.48, 0.20)
	p.leaf_color_secondary = Color(0.40, 0.56, 0.26)
	return p


## 5. Arbol Seco / Quemado (Tierras baldias / Bosque muerto)
## Ramas retorcidas desnudas sin ninguna hoja.
static func _create_dead_tree() -> TreeProfile:
	var p := TreeProfile.new()
	p.id = "dead_tree"
	p.name = "Arbol Muerto (Baldio)"
	p.biome_description = "Madera seca o calcinada con ramas angulares y retorcidas."
	
	p.trunk_height_min = 5.5
	p.trunk_height_max = 9.0
	p.trunk_radius_base = 0.55
	p.trunk_segments = 6
	p.trunk_taper = 0.82
	p.trunk_max_tilt_deg = 14.0
	p.trunk_split_chance = 0.60
	
	p.branch_start_ratio = 0.28
	p.branch_density = 12
	p.branch_length_ratio = 0.60
	p.branch_elevation_deg = 30.0
	p.branch_droop = 0.10
	p.branch_radius_ratio = 0.52
	p.branch_segments = 3
	p.secondary_branches_per_branch = 3
	p.twigs_per_secondary = 2
	
	p.has_leaves = false
	p.leaves_per_tip = 0
	p.leaf_size = 0.0
	p.leaf_spread_radius = 0.0
	p.leaf_conical_cluster = false
	
	p.bark_color = Color(0.22, 0.20, 0.19)
	p.leaf_color_primary = Color.BLACK
	p.leaf_color_secondary = Color.BLACK
	return p


## 6. Arbusto o Brote (Sotobosque)
## Altura reducida, ramificacion inmediata desde la base, follaje muy tupido.
static func _create_shrub_sapling() -> TreeProfile:
	var p := TreeProfile.new()
	p.id = "shrub_sapling"
	p.name = "Arbusto / Brote (Sotobosque)"
	p.biome_description = "Vegetacion baja densa y tupida para poblar el suelo forestal."
	
	p.trunk_height_min = 2.2
	p.trunk_height_max = 3.6
	p.trunk_radius_base = 0.28
	p.trunk_segments = 4
	p.trunk_taper = 0.82
	p.trunk_max_tilt_deg = 10.0
	p.trunk_split_chance = 0.80
	
	p.branch_start_ratio = 0.12
	p.branch_density = 12
	p.branch_length_ratio = 0.70
	p.branch_elevation_deg = 35.0
	p.branch_droop = 0.08
	p.branch_radius_ratio = 0.55
	p.branch_segments = 2
	p.secondary_branches_per_branch = 3
	p.twigs_per_secondary = 2
	
	p.has_leaves = true
	p.leaves_per_tip = 4
	p.leaf_size = 1.20
	p.leaf_spread_radius = 0.60
	p.leaf_conical_cluster = false
	
	p.bark_color = Color(0.30, 0.22, 0.15)
	p.leaf_color_primary = Color(0.22, 0.54, 0.15)
	p.leaf_color_secondary = Color(0.32, 0.64, 0.22)
	return p
