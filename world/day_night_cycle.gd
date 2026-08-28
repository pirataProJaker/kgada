extends Node3D
class_name DayNightCycle
## Ciclo dia/noche: alterna entre el HDRI de dia (DAYSKY.hdr) y el de noche
## (PSX_NIGHTSKY.hdr) usando un WorldEnvironment con un shader de cielo que
## ROTA el panorama, y controla la DirectionalLight3D (intensidad/color/
## rotacion) segun la hora.
##
## La hora va de 0.0 a 1.0 (0 = medianoche, 0.25 = amanecer, 0.5 = mediodia,
## 0.75 = atardecer). El cielo rota (via shader rotating_sky.gdshader) y la
## transicion entre dia y noche es suave (se interpola la energia/color del
## ambiente y la luz, y el cielo cambia de material en el punto medio).

const DAY_SKY_PATH := "res://assets/entorno/PSX_Daysky_HDRI/DAYSKY.hdr"
const NIGHT_SKY_PATH := "res://assets/entorno/PSX_Nightsky_HDRI/PSX_NIGHTSKY.hdr"
const ROTATING_SKY_SHADER := preload("res://shaders/rotating_sky.gdshader")

# Duracion de un ciclo completo en segundos (por defecto 120s = 2 min por dia)
@export var cycle_duration := 120.0
# Hora inicial (0.5 = mediodia para que empiece de dia)
@export var start_time := 0.5
# Velocidad de rotacion del cielo (radianes por segundo)
@export var sky_rotation_speed := 0.02

# Referencias opcionales (si no se asignan, se buscan por nombre)
@export var sun_path: NodePath

var _time := 0.5
var _world_env: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _sky_material: ShaderMaterial = null
var _sky: Sky = null


func _ready() -> void:
	_time = start_time

	# Crear el ShaderMaterial del cielo con ambos panoramas (dia y noche) y
	# el shader que los mezcla suavemente segun day_night_factor.
	_sky_material = _build_sky_material()

	# Crear el WorldEnvironment si no existe
	_world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_env == null:
		_world_env = WorldEnvironment.new()
		_world_env.name = "WorldEnvironment"
		add_child(_world_env)

	# Crear el Sky compartido
	_sky = Sky.new()
	var env := _world_env.environment
	if env == null:
		env = Environment.new()
		_world_env.environment = env
	env.background_mode = Environment.BG_SKY
	env.sky = _sky
	if _sky_material != null:
		_sky.sky_material = _sky_material

	# Buscar el sol
	if not sun_path.is_empty():
		_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun == null:
		_sun = _find_sun(self)

	_update_environment()


func _process(delta: float) -> void:
	_time += delta / cycle_duration
	if _time >= 1.0:
		_time -= 1.0
	_update_environment()


## Construye el ShaderMaterial del cielo con el shader rotatorio y ambos
## panoramas (dia y noche). El shader mezcla los dos segun day_night_factor.
func _build_sky_material() -> ShaderMaterial:
	var day_tex := load(DAY_SKY_PATH) as Texture2D
	var night_tex := load(NIGHT_SKY_PATH) as Texture2D
	if day_tex == null or night_tex == null:
		push_warning("[daynight] No se pudieron cargar los HDRs de dia/noche")
		return null
	var mat := ShaderMaterial.new()
	mat.shader = ROTATING_SKY_SHADER
	mat.set_shader_parameter("panorama_day", day_tex)
	mat.set_shader_parameter("panorama_night", night_tex)
	mat.set_shader_parameter("rotation_speed", sky_rotation_speed)
	return mat


## Busca la primera DirectionalLight3D en el arbol.
func _find_sun(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node
	for child in node.get_children():
		var found := _find_sun(child)
		if found != null:
			return found
	return null


## Actualiza el cielo y la luz segun la hora actual.
func _update_environment() -> void:
	# Altura del sol: -1 en medianoche, +1 en mediodia.
	var sun_height := sin(_time * TAU - PI * 0.5)
	sun_height = clampf(sun_height, -1.0, 1.0)

	# Factor de dia: 0 = noche, 1 = dia. Smoothstep para transiciones suaves.
	var day_factor := clampf((sun_height + 0.2) / 0.6, 0.0, 1.0)

	# Mezclar suavemente los dos panoramas en el shader segun day_factor. El
	# shader interpola entre el cielo de noche y el de dia, asi la transicion
	# es natural (se oscurece gradualmente, aparecen las estrellas, etc.) en
	# vez de un corte brusco.
	if _sky_material != null:
		_sky_material.set_shader_parameter("day_night_factor", day_factor)
		_sky_material.set_shader_parameter("energy", lerpf(0.4, 1.0, day_factor))

	# Ajustar el ambiente (energia/color) suavemente segun dia/noche
	if _world_env != null:
		var env := _world_env.environment
		if env != null:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = lerpf(0.15, 1.0, day_factor)
			# Color del ambiente: azul de dia, azul oscuro de noche
			env.ambient_light_color = Color(
				lerpf(0.2, 0.6, day_factor),
				lerpf(0.25, 0.7, day_factor),
				lerpf(0.4, 1.0, day_factor)
			)

	# Controlar el sol
	if _sun != null:
		# Rotar el sol segun la hora (0 = medianoche, 0.5 = mediodia)
		_sun.rotation_degrees = Vector3(-90.0 + sun_height * 80.0, 0.0, 0.0)
		# Energia del sol: maximo 1.0 al mediodia (mas alto satura los
		# materiales y los hace ver como plastico blanco brillante).
		_sun.light_energy = lerpf(0.05, 1.0, day_factor)
		# Color del sol: calido al amanecer/atardecer, blanco al mediodia
		_sun.light_color = Color(
			lerpf(0.3, 1.0, day_factor),
			lerpf(0.3, 0.95, day_factor),
			lerpf(0.4, 0.9, day_factor)
		)
