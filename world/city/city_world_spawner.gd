extends Node3D
class_name CityWorldSpawner
## Coloca la ciudad procedural (ver world/city/city_block.tscn) en un punto
## FIJO del mundo real, determinado por la semilla del mundo - mismo criterio
## que las aldeas de Minecraft: la semilla decide DONDE aparece, siempre el
## MISMO lugar para la misma semilla, nunca al azar entre partidas.
##
## Sigue el mismo patron que DogSpawner: no se auto-dispara en _ready(),
## world_test.gd llama a spawn(world_seed) explicitamente - y lo hace ANTES
## de que el jugador pueda alejarse lo suficiente como para que sus chunks
## cercanos ya se hayan generado sin la zona de aplanado registrada (ver
## ChunkManager.set_city_flatten_zone).
##
## El tamaño de la zona a aplanar se mide en la ciudad REAL ya generada,
## incluidos los caminos de entrada, en vez de reservar un peor caso teorico
## que podia inflar muchisimo un eje corto. La transicion entre "100% plano"
## y "terreno natural" se mezcla de forma suave (smoothstep) en
## TerrainGenerator.rs para que nunca se vea un escalon brusco en el borde.

const CITY_SCENE := preload("res://world/city/city_block.tscn")

## Cuanto terreno extra (metros), MAS ALLA de outer_radius, se exige antes
## de que el centro de la ciudad pueda aparecer - garantiza que la zona de
## aplanado (que solo llega hasta outer_radius) NUNCA alcance de vuelta el
## origen del mundo (0,0), que es donde arranca el jugador por defecto.
const SPAWN_CLEARANCE := 150.0
## Cuanto varia la distancia real del centro de la ciudad, por ENCIMA del
## minimo seguro (outer_radius + SPAWN_CLEARANCE) - le da variedad a donde
## cae la ciudad sin arriesgar que quede pegada al spawn.
const CITY_DISTANCE_SPREAD := 400.0

## Margen (metros) alrededor del footprint calculado - entradas, props de
## decoracion que sobresalen un poco del rectangulo de manzanas - antes de
## empezar el desvanecido hacia el terreno natural.
const FOOTPRINT_MARGIN := 40.0
## Ancho (metros) de la zona de transicion suave entre el area 100% plana y
## el terreno natural sin tocar - entre mas grande, mas gradual/natural.
const BLEND_MARGIN := 70.0

@export var chunk_manager_path: NodePath

var city_center: Vector2 = Vector2.ZERO


## Punto de entrada unico. Debe llamarse UNA vez al iniciar el mundo real,
## antes de que el jugador pueda alejarse lo suficiente para necesitar
## chunks que ya deberian llevar la zona de aplanado registrada.
func spawn(world_seed: int) -> void:
	var chunk_manager: Node3D = get_node_or_null(chunk_manager_path)
	if chunk_manager == null:
		push_warning("[CityWorldSpawner] chunk_manager_path no apunta a un nodo valido - la ciudad no se generara.")
		return

	# Primero se genera UNA sola ciudad real con la misma semilla que usara el
	# jugador. Asi el RNG decide el eje largo y podemos medir el AABB resultante
	# en vez de reservar el peor caso teorico para ambos ejes.
	var city := CITY_SCENE.instantiate() as CityBlockGenerator
	if city == null:
		push_warning("[CityWorldSpawner] No se pudo instanciar CityBlockGenerator.")
		return
	city.name = "City"
	city.randomize_seed_on_run = false
	city.rng_seed = _derive_city_layout_seed(world_seed)
	add_child(city)

	var city_bounds := city.get_generated_footprint_aabb()
	if city_bounds.size.x <= 0.0 or city_bounds.size.z <= 0.0:
		push_warning("[CityWorldSpawner] No se pudo medir la ciudad generada - se cancela la colocacion.")
		city.queue_free()
		return

	var footprint := Vector2(city_bounds.size.x, city_bounds.size.z)
	var inner_radius := (footprint * 0.5).length() + FOOTPRINT_MARGIN
	var outer_radius := inner_radius + BLEND_MARGIN

	# La distancia minima/maxima al origen se calculan DESPUES de conocer
	# outer_radius real - asi, sin importar que tan grande resulte la ciudad,
	# la zona de aplanado jamas alcanza de vuelta el spawn (0,0).
	var min_distance := outer_radius + SPAWN_CLEARANCE
	var max_distance := min_distance + CITY_DISTANCE_SPREAD
	city_center = _compute_city_center(world_seed, min_distance, max_distance)

	var flat_height: float = chunk_manager.sample_terrain_height(city_center.x, city_center.y)
	chunk_manager.set_city_flatten_zone(city_center, inner_radius, outer_radius, flat_height)

	# El AABB puede empezar en coordenadas negativas (por el centro de los
	# modelos y por los caminos de entrada). Se alinea su centro real con
	# city_center, no se asume que el layout empieza en (0,0).
	var local_bounds_center := Vector2(
		city_bounds.position.x + city_bounds.size.x * 0.5,
		city_bounds.position.z + city_bounds.size.z * 0.5
	)
	var city_origin := city_center - local_bounds_center
	city.position = Vector3(city_origin.x, flat_height, city_origin.y)

	print("[CityWorldSpawner] Ciudad fijada en (%.1f, %.1f), aplanado %.1f-%.1fm, altura=%.2f" % [
		city_center.x, city_center.y, inner_radius, outer_radius, flat_height
	])


## Hash determinista semilla -> punto fijo del mundo (angulo + distancia) -
## igual criterio que las aldeas de Minecraft: la MISMA semilla siempre da
## el MISMO punto, nunca cambia entre partidas ni recargas.
func _compute_city_center(world_seed: int, min_distance: float, max_distance: float) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 7919 + 104729 # sal arbitraria, distinta al ruido del terreno
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(min_distance, max_distance)
	return Vector2(cos(angle), sin(angle)) * distance


## Layout de la ciudad tambien determinista por semilla (misma semilla =
## misma ciudad, no solo la misma ubicacion) - offset distinto al de
## _compute_city_center para no correlacionar ambos sorteos.
func _derive_city_layout_seed(world_seed: int) -> int:
	return world_seed * 486187739 + 1000003
