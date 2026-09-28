extends Node3D
class_name DayNightCycle
## Ciclo día/noche procedural hiperoptimizado (30s configurable).
## Controla la DirectionalLight3D (rotación y color de sol/luna) y sincroniza
## el Sky shader procedural a puras matemáticas en tiempo real.

const PROCEDURAL_SKY_SHADER := preload("res://shaders/procedural_math_sky.gdshader")

## Duración de un ciclo completo en segundos (30s solicitado por el usuario)
@export var cycle_duration := 30.0
## Hora inicial (0.5 = mediodía, 0.75 = atardecer, 0.0 = medianoche, 0.25 = amanecer)
@export var start_time := 0.5

@export var sun_path: NodePath
@export var world_env_path: NodePath

var _time := 0.5
var _world_env: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _sky_material: ShaderMaterial = null
var _sky: Sky = null


func _ready() -> void:
	_time = start_time

	# Resolver WorldEnvironment
	if not world_env_path.is_empty():
		_world_env = get_node_or_null(world_env_path) as WorldEnvironment
	if _world_env == null and get_parent() != null:
		_world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_env == null:
		_world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment

	# Asegurar Sky y ShaderMaterial
	if _world_env != null:
		if _world_env.environment == null:
			_world_env.environment = Environment.new()
		var env := _world_env.environment
		env.background_mode = Environment.BG_SKY
		if env.sky == null:
			env.sky = Sky.new()
		_sky = env.sky
		if _sky.sky_material is ShaderMaterial:
			_sky_material = _sky.sky_material as ShaderMaterial
		else:
			_sky_material = ShaderMaterial.new()
			_sky_material.shader = PROCEDURAL_SKY_SHADER
			_sky.sky_material = _sky_material

	# Resolver DirectionalLight3D (Sol)
	if not sun_path.is_empty():
		_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun == null and get_parent() != null:
		_sun = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _sun == null:
		_sun = _find_sun(get_tree().current_scene if get_tree() else self)

	_update_environment()
	add_to_group("day_night_cycle")


func set_time(t: float) -> void:
	_time = fposmod(t, 1.0)
	_update_environment()


func get_time() -> float:
	return _time


func _process(delta: float) -> void:
	if cycle_duration > 0.0:
		_time += delta / cycle_duration
		if _time >= 1.0:
			_time -= 1.0
	_update_environment()


func _find_sun(node: Node) -> DirectionalLight3D:
	if node == null:
		return null
	if node is DirectionalLight3D:
		return node
	for child in node.get_children():
		var found := _find_sun(child)
		if found != null:
			return found
	return null


func _update_environment() -> void:
	# _time va de 0.0 a 1.0 (0.0 = medianoche, 0.25 = amanecer, 0.5 = mediodia, 0.75 = atardecer)
	var sun_angle_rad := (_time * TAU) - (PI * 0.5)
	var sun_height := sin(sun_angle_rad) # -1.0 a +1.0
	var sun_h_cos := cos(sun_angle_rad)

	# Vector de direccion del sol en coordenadas de mundo
	var sun_direction := Vector3(-sun_h_cos * 0.9, sun_height, sun_h_cos * 0.4).normalized()

	# Rotar el DirectionalLight3D para que coincida con la posición del sol
	if _sun != null:
		var up_vec := Vector3.UP if absf(sun_direction.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		_sun.look_at_from_position(_sun.global_position, _sun.global_position - sun_direction, up_vec)

	# Enviar direccion al shader de cielo
	if _sky_material != null:
		_sky_material.set_shader_parameter("sun_direction", sun_direction)

	# Factores suaves
	var day_factor := clampf((sun_height + 0.1) / 0.4, 0.0, 1.0)
	var sunset_factor := clampf(1.0 - absf(sun_height - 0.05) / 0.25, 0.0, 1.0)

	# Actualizar color e intensidad de la luz solar / lunar
	if _sun != null:
		var sun_col := Color(1.0, 0.97, 0.88).lerp(Color(1.0, 0.60, 0.30), sunset_factor)
		sun_col = sun_col.lerp(Color(0.40, 0.55, 0.75), 1.0 - day_factor)
		_sun.light_color = sun_col

		var target_energy := lerpf(0.12, 1.35, day_factor)
		if sunset_factor > 0.05:
			target_energy = lerpf(target_energy, 1.05, sunset_factor)
		_sun.light_energy = target_energy

	# Actualizar luz ambiental en el WorldEnvironment
	if _world_env != null and _world_env.environment != null:
		var env := _world_env.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		var amb_col := Color(0.68, 0.76, 0.85).lerp(Color(0.85, 0.55, 0.40), sunset_factor)
		amb_col = amb_col.lerp(Color(0.10, 0.14, 0.25), 1.0 - day_factor)
		env.ambient_light_color = amb_col
		env.ambient_light_energy = lerpf(0.18, 0.95, day_factor)
