class_name TerrainEcology
extends RefCounted

## Administrador ecológico del terreno: coordina tipos de suelo (césped vs tierra),
## clústeres de árboles (bosque, arboledas, solitarios, claros) y densidades botánicas asociadas.

# Definición de árbol: position: Vector2, profile_id: String, canopy_radius: float, scale: float, seed_val: int

var trees: Array = []
var _rng: RandomNumberGenerator

func _init(seed_val: int = 45678) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val

## Genera la disposición ecológica de árboles según los biomas de la escena
func generate_layout(seed_val: int = -1) -> void:
	if seed_val >= 0:
		_rng.seed = seed_val
	trees.clear()
	
	# 1. BOSQUE DENSO (Ladera izquierda y fondo: clúster de 6 a 8 árboles)
	# Forma una masa forestal con suelo de tierra/mantillo continuo que enmarca el flanco izquierdo
	var forest_center := Vector2(-5.8, -5.2)
	var forest_count: int = _rng.randi_range(6, 8)
	for i in range(forest_count):
		var angle = _rng.randf() * TAU
		var dist = sqrt(_rng.randf()) * 2.2
		var pos = forest_center + Vector2(cos(angle), sin(angle)) * dist
		
		# Pinos boreales y robles
		var profile = "pine_boreal"
		if i % 3 == 0:
			profile = "classic_oak"
			
		trees.append({
			"position": pos,
			"profile_id": profile,
			"canopy_radius": _rng.randf_range(2.0, 2.5),
			"scale": _rng.randf_range(0.85, 1.15),
			"seed_val": _rng.randi()
		})
	
	# 2. ARBOLEDA PEQUEÑA (Ladera derecha lejana: 2 o 3 árboles agrupados)
	var grove_center := Vector2(5.5, -4.8)
	var grove_count: int = _rng.randi_range(2, 3)
	for i in range(grove_count):
		var angle = _rng.randf() * TAU
		var dist = sqrt(_rng.randf()) * 1.4
		var pos = grove_center + Vector2(cos(angle), sin(angle)) * dist
		trees.append({
			"position": pos,
			"profile_id": "pine_boreal" if i == 0 else "classic_oak",
			"canopy_radius": _rng.randf_range(1.8, 2.3),
			"scale": _rng.randf_range(0.85, 1.10),
			"seed_val": _rng.randi()
		})
	
	# 3. ÁRBOL SOLITARIO MAJESTUOSO (Cresta alta de la loma, fondo central)
	# Silueta icónica recortada contra el cielo crepuscular
	trees.append({
		"position": Vector2(-0.6, -6.2),
		"profile_id": "pine_boreal",
		"canopy_radius": 2.4,
		"scale": 1.30,
		"seed_val": _rng.randi()
	})
	
	# 4. CLARO ABIERTO (Centro y frente: x entre -3 y 4, z entre -4 y 1)
	# Pradera soleada de flores y pasto FBX con sendero natural de tierra

## Consulta de suelo y ecología en cualquier coordenada 2D (x, z)
func get_soil_info(pos2d: Vector2) -> Dictionary:
	var min_tree_dist := 999.0
	var max_tree_dirt := 0.0
	
	for t in trees:
		var d = pos2d.distance_to(t["position"])
		if d < min_tree_dist:
			min_tree_dist = d
		
		var rad: float = t["canopy_radius"]
		if d < rad:
			# Núcleo bajo la copa: tierra intensa (0.7 a 1.0)
			var factor = 1.0 - (d / rad) * 0.35
			if factor > max_tree_dirt:
				max_tree_dirt = factor
		elif d < rad + 1.2:
			# Margen de transición alrededor del árbol
			var t_edge = 1.0 - ((d - rad) / 1.2)
			var factor = t_edge * 0.65
			if factor > max_tree_dirt:
				max_tree_dirt = factor
	
	# Claro/sendero natural de tierra seca (curva orgánica de tierra que cruza entre los árboles)
	var trail_x = sin(pos2d.y * 0.35 + 1.2) * 2.2 - 0.8
	var dist_to_trail = absf(pos2d.x - trail_x)
	var trail_dirt = 0.0
	if pos2d.y < -1.5 and dist_to_trail < 1.0:
		trail_dirt = (1.0 - dist_to_trail / 1.0) * 0.75
	
	var total_dirt = clampf(maxf(max_tree_dirt, trail_dirt), 0.0, 1.0)
	
	# Densidad de pasto FBX:
	# - Pradera verde (dirt ~ 0): 1.0 (100% de pasto)
	# - Transición (dirt ~ 0.5): 0.45
	# - Tierra pura bajo árbol (dirt > 0.7): 0.08 (solo alguna brizna esporádica)
	var grass_dens = lerpf(1.0, 0.08, smoothstep(0.15, 0.75, total_dirt))
	
	# Densidad de flores solares (Margaritas, Amapolas, Lavandas):
	# - Solo crecen en suelo fértil (dirt < 0.25) y lejos de la sombra directa de árboles
	var flower_dens = 0.0
	if total_dirt < 0.25 and min_tree_dist > 2.6:
		flower_dens = (1.0 - total_dirt / 0.25) * clampf((min_tree_dist - 2.6) / 1.5, 0.0, 1.0)
	
	return {
		"dirt_factor": total_dirt,
		"grass_density": grass_dens,
		"flower_density": flower_dens,
		"min_tree_dist": min_tree_dist
	}
