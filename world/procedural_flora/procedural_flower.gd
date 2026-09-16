@tool
class_name ProceduralFlower
extends Node3D

## Nodo 3D botánico para instanciación y crecimiento de flores procedurales.
## Soporta ciclo de vida dinámico (Brote -> Vegetativo -> Capullo -> Floración)
## y modo silvestre con distribución aleatoria por semilla.

const FlowerProfiles = preload("res://world/procedural_flora/procedural_flower_profiles.gd")
const FlowerGenerator = preload("res://world/procedural_flora/procedural_flower_generator.gd")
const FlowerShader = preload("res://world/procedural_flora/flower_shader.gdshader")

signal stage_changed(stage_name: String)
signal bloom_completed()

@export_group("Botánica")
@export var profile_id: String = "shrub_rose":
	set(val):
		profile_id = val
		if is_inside_tree():
			generate()

@export var flower_seed: int = 0:
	set(val):
		flower_seed = val
		if is_inside_tree():
			generate()

@export var color_index: int = -1:
	set(val):
		color_index = val
		if is_inside_tree():
			generate()

@export_group("Ciclo de Crecimiento")
## Progreso del crecimiento de 0.0 (brote recién nacido) a 1.0 (floración plena).
@export_range(0.0, 1.0, 0.01) var growth_progress: float = 1.0:
	set(val):
		var prev_stage = _current_stage_name
		growth_progress = clampf(val, 0.0, 1.0)
		if is_inside_tree():
			generate()
			if _current_stage_name != prev_stage:
				stage_changed.emit(_current_stage_name)
			if growth_progress >= 1.0 and not _has_bloomed:
				_has_bloomed = true
				bloom_completed.emit()

## Si es true, la semilla determina una edad y madurez aleatoria típica de campo abierto.
@export var is_wild: bool = false:
	set(val):
		is_wild = val
		if is_inside_tree():
			generate()

@export_group("Viento y Renderizado")
@export var wind_enabled: bool = true:
	set(val):
		wind_enabled = val
		_update_shader_params()

@export_range(0.0, 1.0, 0.05) var wind_strength: float = 0.25:
	set(val):
		wind_strength = val
		_update_shader_params()

@export var enable_collision_for_shrubs: bool = false

# Nodos internos y estado
var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _current_height: float = 0.0
var _flower_count: int = 0
var _current_stage_name: String = "Floración"
var _flower_positions: Array[Vector3] = []
var _has_bloomed: bool = false

func _ready() -> void:
	_setup_nodes()
	generate()

func _setup_nodes() -> void:
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "FlowerMesh"
		add_child(_mesh_instance)
	
	if not _material:
		_material = ShaderMaterial.new()
		_material.shader = FlowerShader

## Genera o reconstruye la geometría procedural según los parámetros actuales
func generate() -> void:
	if not is_inside_tree():
		return
	
	_setup_nodes()
	
	var effective_growth: float = growth_progress
	var effective_seed: int = flower_seed
	if effective_seed == 0:
		effective_seed = hash(global_position)
		if effective_seed == 0:
			effective_seed = 12345
	
	# En modo silvestre, la semilla determina madurez natural del entorno
	if is_wild:
		var wild_rng := RandomNumberGenerator.new()
		wild_rng.seed = effective_seed
		var roll: float = wild_rng.randf()
		if roll < 0.10:
			effective_growth = wild_rng.randf_range(0.08, 0.20) # 10% brotes jóvenes
		elif roll < 0.30:
			effective_growth = wild_rng.randf_range(0.55, 0.78) # 20% en capullo
		else:
			effective_growth = wild_rng.randf_range(0.85, 1.00) # 70% floración espléndida
	
	var gen_result: ProceduralFlowerGenerator.GenerationResult = FlowerGenerator.generate_flower(
		profile_id,
		effective_seed,
		effective_growth,
		color_index
	)
	
	_current_height = gen_result.height
	_flower_count = gen_result.flower_count
	_current_stage_name = gen_result.stage_name
	_flower_positions = gen_result.flower_positions
	
	_mesh_instance.mesh = gen_result.mesh
	_update_shader_params()
	
	# Colisión física ligera solo para rosales maduros si está habilitada
	_update_collision()

func _update_shader_params() -> void:
	if not _material or not _mesh_instance:
		return
	
	_material.set_shader_parameter("plant_max_height", maxf(_current_height, 0.1))
	_material.set_shader_parameter("wind_strength", wind_strength if wind_enabled else 0.0)
	_material.set_shader_parameter("wind_speed", 2.2)
	
	# Aplicar el material a todas las superficies
	if _mesh_instance.mesh:
		for s in range(_mesh_instance.mesh.get_surface_count()):
			_mesh_instance.set_surface_override_material(s, _material)

func _update_collision() -> void:
	# Limpiar colisión existente
	for child in get_children():
		if child is StaticBody3D and child.name == "FlowerCollider":
			child.queue_free()
	
	if not enable_collision_for_shrubs:
		return
	
	var profile: Dictionary = FlowerProfiles.get_profile(profile_id)
	if profile["morphology"] == FlowerProfiles.MORPHOLOGY_SHRUB and growth_progress > 0.6:
		var sb := StaticBody3D.new()
		sb.name = "FlowerCollider"
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.height = _current_height * 0.75
		cyl.radius = _current_height * 0.35
		col.shape = cyl
		col.position = Vector3(0, cyl.height * 0.5, 0)
		sb.add_child(col)
		add_child(sb)

# ==============================================================================
# API PÚBLICA PARA GAMEPLAY Y SIEMBRA
# ==============================================================================

## Ajusta directamente el progreso de crecimiento (0.0 a 1.0)
func set_growth(value: float) -> void:
	growth_progress = value

## Avanza el crecimiento por tiempo o riego (ej: al recibir agua o transcurrir minutos)
func advance_growth(delta_time: float, growth_speed: float = 0.05) -> void:
	set_growth(growth_progress + delta_time * growth_speed)

func get_flower_height() -> float:
	return _current_height

func get_flower_count() -> int:
	return _flower_count

func get_stage_name() -> String:
	return _current_stage_name

func get_flower_positions() -> Array[Vector3]:
	return _flower_positions
