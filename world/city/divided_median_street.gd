class_name DividedMedianStreet
extends Node3D
## Calle Urbana de 3 Carriles por Sentido (6 Carriles en total) con Camellón Central Integrado de 2.0m.
## Basada en avenidas y vialidades primarias mexicanas:
## - 3 carriles de 3.50m en calzada izquierda (10.50m) con 2 líneas discontinuas blancas y orillas continuas.
## - Camellón/separador central elevado (2.00m) con bordillos y losa superior para luminarias y árboles.
## - 3 carriles de 3.50m en calzada derecha (10.50m) con 2 líneas discontinuas blancas y orillas continuas.
## - Postes de luz instanciados por GPU con el cilindro low-poly de 12 lados (estándar medidor CFE).
## - Árboles generados proceduralmente en el camellón central con ProceduralTree.
##
## Siguiendo la directiva arquitectónica del motor: esta clase NO tiene lógica
## geométrica propia; delega toda la parametrización, mallado, colisiones, luminarias
## y árboles al motor procedural central (RoadTrajectorySystem).

const RoadTrajectorySystem = preload("res://world/city/road_trajectory_system.gd")

enum MedianDecorationType {
	TREES,            # Árboles ProceduralTree
	SQUARE_PLANTERS,  # Macetas cuadradas inteligentes (con arbustos shrub_sapling)
	BOTH,             # Árboles y macetas combinados
	NONE              # Solo postes de luz en camellón
}

@export var length: float = 80.0:
	set(val):
		length = maxf(val, 15.0)
		if is_node_ready():
			rebuild()

@export var median_decoration: MedianDecorationType = MedianDecorationType.TREES:
	set(val):
		median_decoration = val
		if is_node_ready():
			rebuild()

@export var has_left_sidewalk: bool = true:
	set(val):
		has_left_sidewalk = val
		if is_node_ready():
			rebuild()

@export var has_right_sidewalk: bool = true:
	set(val):
		has_right_sidewalk = val
		if is_node_ready():
			rebuild()

@export var sidewalk_width: float = 2.0:
	set(val):
		sidewalk_width = val
		if is_node_ready():
			rebuild()

var road_system: RoadTrajectorySystem
var segment_id: int = -1


func _ready() -> void:
	rebuild()


## Reconstruye el tramo delegando enteramente al motor
func rebuild() -> void:
	if road_system == null:
		road_system = RoadTrajectorySystem.new()
		road_system.name = "RoadSystem"
		add_child(road_system)

	road_system.clear()

	var half_len := length * 0.5
	var ep0 := road_system.add_endpoint(
		Vector3(0.0, 0.0, -half_len),
		Vector3(0.0, 0.0, 1.0),
		RoadTrajectorySystem.STANDARD_WIDTH_DIVIDED_3LANE,
		RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE
	)
	var ep1 := road_system.add_endpoint(
		Vector3(0.0, 0.0, half_len),
		Vector3(0.0, 0.0, 1.0),
		RoadTrajectorySystem.STANDARD_WIDTH_DIVIDED_3LANE,
		RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE
	)

	var seg := road_system.connect_endpoints(
		ep0.id,
		ep1.id,
		RoadTrajectorySystem.STANDARD_WIDTH_DIVIDED_3LANE,
		RoadTrajectorySystem.RoadType.DIVIDED_MEDIAN_3LANE
	)
	if seg != null:
		segment_id = seg.id
		road_system.set_both_sidewalks(segment_id, has_left_sidewalk, has_right_sidewalk, sidewalk_width)

	# Auto-instanciar luminarias y elementos de camellón (árboles o macetas cuadradas)
	var old_decor := get_node_or_null("Decor_Elements")
	if old_decor != null:
		old_decor.queue_free()

	var decor_root := Node3D.new()
	decor_root.name = "Decor_Elements"
	add_child(decor_root)

	spawn_streetlights(decor_root)

	match median_decoration:
		MedianDecorationType.TREES:
			spawn_median_trees(decor_root)
		MedianDecorationType.SQUARE_PLANTERS:
			spawn_median_planters(decor_root, true)
		MedianDecorationType.BOTH:
			spawn_median_trees(decor_root)
			spawn_median_planters(decor_root, true)
		MedianDecorationType.NONE:
			pass


## Consulta al motor las posiciones y orientaciones calculadas proceduralmente para postes de luz
func get_streetlight_transforms() -> Array[Transform3D]:
	if road_system == null or segment_id == -1:
		return []
	return road_system.get_streetlight_transforms_for_segment(segment_id)


## Instancia en la escena los postes de luz calculados por el motor (GPU Hardware Instanced por defecto)
func spawn_streetlights(parent_node: Node3D = self, custom_factory_or_scene = null) -> Array[Node3D]:
	if road_system == null:
		return []
	return road_system.spawn_streetlights(parent_node, custom_factory_or_scene, segment_id)


## Consulta al motor las posiciones y orientaciones calculadas para árboles en el camellón central
func get_median_tree_transforms() -> Array[Transform3D]:
	if road_system == null or segment_id == -1:
		return []
	return road_system.get_median_tree_transforms_for_segment(segment_id)


## Instancia árboles procedurales (ProceduralTree) en el camellón central de 2m
func spawn_median_trees(parent_node: Node3D = self, profile_id: String = "classic_oak") -> Array[Node3D]:
	if road_system == null:
		return []
	return road_system.spawn_median_trees(parent_node, profile_id, segment_id)


## Consulta al motor las posiciones y orientaciones calculadas para macetas cuadradas
func get_median_planter_transforms() -> Array[Transform3D]:
	if road_system == null or segment_id == -1:
		return []
	return road_system.get_median_planter_transforms_for_segment(segment_id)


## Instancia macetas cuadradas en el camellón central con GPU Hardware Instancing y vegetación
func spawn_median_planters(parent_node: Node3D = self, with_vegetation: bool = true) -> Dictionary:
	if road_system == null:
		return {}
	return road_system.spawn_median_planters(parent_node, with_vegetation, segment_id)
