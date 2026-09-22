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
		if profile_id == val:
			return
		profile_id = val
		if is_inside_tree() and not _is_updating_batch:
			generate()

@export var flower_seed: int = 0:
	set(val):
		if flower_seed == val:
			return
		flower_seed = val
		if is_inside_tree() and not _is_updating_batch:
			generate()

@export var color_index: int = -1:
	set(val):
		if color_index == val:
			return
		color_index = val
		if is_inside_tree() and not _is_updating_batch:
			generate()

@export_group("Ciclo de Crecimiento")
## Progreso del crecimiento de 0.0 (brote recién nacido) a 1.0 (floración plena).
@export_range(0.0, 1.0, 0.01) var growth_progress: float = 1.0:
	set(val):
		var prev_stage = _current_stage_name
		growth_progress = clampf(val, 0.0, 1.0)
		if is_inside_tree() and not _is_updating_batch:
			var profile: Dictionary = FlowerProfiles.get_profile(profile_id)
			var stages: Dictionary = profile["growth_stages"]
			var crossed_boundary := false
			for key in ["sprout_end", "veg_end", "bud_end"]:
				var border: float = float(stages[key])
				if (_last_generated_growth < border and growth_progress >= border) or (_last_generated_growth >= border and growth_progress < border):
					crossed_boundary = true
					break
			if _last_generated_growth < 0.0 or absf(growth_progress - _last_generated_growth) >= 0.02 or growth_progress == 0.0 or growth_progress == 1.0 or crossed_boundary:
				generate()
				if _current_stage_name != prev_stage:
					stage_changed.emit(_current_stage_name)
				if growth_progress >= 1.0 and not _has_bloomed:
					_has_bloomed = true
					bloom_completed.emit()

## Crecimiento natural continuo con el tiempo (simulación activa de siembra)
@export var auto_grow: bool = false
## Duración total en segundos desde semilla (0.0) hasta floración plena (1.0)
@export_range(5.0, 300.0, 1.0) var growth_duration: float = 45.0

## Si es true, la semilla determina una edad y madurez aleatoria típica de campo abierto.
@export var is_wild: bool = false:
	set(val):
		if is_wild == val:
			return
		is_wild = val
		if is_inside_tree() and not _is_updating_batch:
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

@export_group("LOD y Rendimiento")
## Desactiva por completo el sistema de LOD: siempre muestra la calidad máxima (LOD 0)
@export var disable_lod: bool = false:
	set(val):
		disable_lod = val
		if is_inside_tree():
			_apply_lod_distance_ranges()

@export var lod0_range_end: float = 12.0:
	set(val):
		lod0_range_end = val
		if is_inside_tree():
			_apply_lod_distance_ranges()

@export var lod1_range_end: float = 28.0:
	set(val):
		lod1_range_end = val
		if is_inside_tree():
			_apply_lod_distance_ranges()

@export var lod2_range_end: float = 70.0:
	set(val):
		lod2_range_end = val
		if is_inside_tree():
			_apply_lod_distance_ranges()

## Control forzado de LOD para pruebas: -1 = Automático por distancia, 0 = LOD0, 1 = LOD1, 2 = LOD2
@export var forced_lod_level: int = -1:
	set(val):
		forced_lod_level = val
		_update_forced_lod_visibility()

@export var cast_shadows: bool = true:
	set(val):
		cast_shadows = val
		_update_shadow_settings()

@export var enable_collision_for_shrubs: bool = false

# Nodos internos y mallas por LOD
var _mesh_lod0: MeshInstance3D
var _mesh_lod1: MeshInstance3D
var _mesh_lod2: MeshInstance3D
var _mesh_instance: MeshInstance3D # Alias para retrocompatibilidad con LOD 0

var _material_veg: ShaderMaterial
var _material_flower: ShaderMaterial
var _current_height: float = 0.0
var _flower_count: int = 0
var _current_stage_name: String = "Floración"
var _flower_positions: Array[Vector3] = []
var _has_bloomed: bool = false
var _last_generated_growth: float = -1.0

var _cached_triangles: int = 0
var _cached_vertices: int = 0
var _cached_triangles_lod1: int = 0
var _cached_vertices_lod1: int = 0
var _cached_triangles_lod2: int = 0
var _cached_vertices_lod2: int = 0
var _is_updating_batch: bool = false

func begin_batch_update() -> void:
	_is_updating_batch = true

func end_batch_update() -> void:
	_is_updating_batch = false
	if is_inside_tree():
		generate()

func _ready() -> void:
	_setup_nodes()
	generate()

func _process(delta: float) -> void:
	if auto_grow and growth_progress < 1.0:
		var rate: float = delta / maxf(growth_duration, 1.0)
		var next_growth := minf(growth_progress + rate, 1.0)
		
		var profile: Dictionary = FlowerProfiles.get_profile(profile_id)
		var stages: Dictionary = profile["growth_stages"]
		var should_rebuild := false
		if _last_generated_growth < 0.0 or absf(next_growth - _last_generated_growth) >= 0.05 or next_growth >= 1.0:
			should_rebuild = true
		
		for key in ["sprout_end", "veg_end", "bud_end"]:
			var border: float = float(stages[key])
			if growth_progress < border and next_growth >= border:
				should_rebuild = true
				break
		
		growth_progress = next_growth
		if should_rebuild:
			_last_generated_growth = next_growth
			generate()

func _setup_nodes() -> void:
	if not _mesh_lod0:
		_mesh_lod0 = MeshInstance3D.new()
		_mesh_lod0.name = "FlowerMesh_LOD0"
		add_child(_mesh_lod0)
		_mesh_instance = _mesh_lod0
	
	if not _mesh_lod1:
		_mesh_lod1 = MeshInstance3D.new()
		_mesh_lod1.name = "FlowerMesh_LOD1"
		add_child(_mesh_lod1)
	
	if not _mesh_lod2:
		_mesh_lod2 = MeshInstance3D.new()
		_mesh_lod2.name = "FlowerMesh_LOD2"
		add_child(_mesh_lod2)
	
	if not _material_veg:
		_material_veg = ShaderMaterial.new()
		_material_veg.shader = FlowerShader
	
	if not _material_flower:
		_material_flower = ShaderMaterial.new()
		_material_flower.shader = FlowerShader


class FlowerGenerationPackage:
	var res_lod0: ProceduralFlowerGenerator.GenerationResult
	var res_lod1: ProceduralFlowerGenerator.GenerationResult
	var res_lod2: ProceduralFlowerGenerator.GenerationResult

## Genera un paquete de mallas desacoplado en los 3 LODs (para pre-cálculo y pooling en streaming)
static func generate_package(p_id: String, s_val: int, growth: float = 1.0, c_idx: int = -1) -> FlowerGenerationPackage:
	var pkg := FlowerGenerationPackage.new()
	pkg.res_lod0 = FlowerGenerator.generate_flower(p_id, s_val, growth, c_idx, 0)
	pkg.res_lod1 = FlowerGenerator.generate_flower(p_id, s_val, growth, c_idx, 1)
	pkg.res_lod2 = FlowerGenerator.generate_flower(p_id, s_val, growth, c_idx, 2)
	return pkg

## Aplica un paquete de generación precalculado instantáneamente (0.02 ms)
func apply_generation_package(pkg: FlowerGenerationPackage) -> void:
	_setup_nodes()
	_current_height = pkg.res_lod0.height
	_flower_count = pkg.res_lod0.flower_count
	_current_stage_name = pkg.res_lod0.stage_name
	_flower_positions = pkg.res_lod0.flower_positions
	
	_cached_triangles = pkg.res_lod0.triangle_count
	_cached_vertices = pkg.res_lod0.vertex_count
	_cached_triangles_lod1 = pkg.res_lod1.triangle_count
	_cached_vertices_lod1 = pkg.res_lod1.vertex_count
	_cached_triangles_lod2 = pkg.res_lod2.triangle_count
	_cached_vertices_lod2 = pkg.res_lod2.vertex_count
	
	_last_generated_growth = 1.0
	
	_mesh_lod0.mesh = pkg.res_lod0.mesh
	_mesh_lod1.mesh = pkg.res_lod1.mesh
	_mesh_lod2.mesh = pkg.res_lod2.mesh
	
	_update_shader_params()
	_apply_surface_materials()
	_update_shadow_settings()
	_apply_lod_distance_ranges()
	_update_collision()


## Genera o reconstruye la geometría procedural en los 3 niveles de LOD
func generate() -> void:
	_setup_nodes()
	
	var effective_growth: float = growth_progress
	var effective_seed: int = flower_seed
	if effective_seed == 0:
		effective_seed = hash(global_position if is_inside_tree() else position)
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
	
	# 1. Generar LOD 0 (Cerca: Calidad máxima botánica)
	var res_lod0: ProceduralFlowerGenerator.GenerationResult = FlowerGenerator.generate_flower(
		profile_id, effective_seed, effective_growth, color_index, 0
	)
	# 2. Generar LOD 1 (Distancia media: Prisma pentagonal 3D + planos de hojas)
	var res_lod1: ProceduralFlowerGenerator.GenerationResult = FlowerGenerator.generate_flower(
		profile_id, effective_seed, effective_growth, color_index, 1
	)
	# 3. Generar LOD 2 (Lejana: 1 solo triángulo 2D billboard + planos mínimos)
	var res_lod2: ProceduralFlowerGenerator.GenerationResult = FlowerGenerator.generate_flower(
		profile_id, effective_seed, effective_growth, color_index, 2
	)
	
	_current_height = res_lod0.height
	_flower_count = res_lod0.flower_count
	_current_stage_name = res_lod0.stage_name
	_flower_positions = res_lod0.flower_positions
	
	_cached_triangles = res_lod0.triangle_count
	_cached_vertices = res_lod0.vertex_count
	_cached_triangles_lod1 = res_lod1.triangle_count
	_cached_vertices_lod1 = res_lod1.vertex_count
	_cached_triangles_lod2 = res_lod2.triangle_count
	_cached_vertices_lod2 = res_lod2.vertex_count
	
	_last_generated_growth = effective_growth
	
	_mesh_lod0.mesh = res_lod0.mesh
	_mesh_lod1.mesh = res_lod1.mesh
	_mesh_lod2.mesh = res_lod2.mesh
	
	_update_shader_params()
	_apply_surface_materials()
	_update_shadow_settings()
	_apply_lod_distance_ranges()
	
	# Colisión física ligera solo para rosales maduros si está habilitada
	_update_collision()

func _apply_surface_materials() -> void:
	for mi in [_mesh_lod0, _mesh_lod1, _mesh_lod2]:
		if mi != null and mi.mesh != null:
			if mi.mesh.get_surface_count() > 0:
				mi.set_surface_override_material(0, _material_veg)
			if mi.mesh.get_surface_count() > 1:
				mi.set_surface_override_material(1, _material_flower)

func _update_shadow_settings() -> void:
	if _mesh_lod0 == null:
		return
	if not cast_shadows:
		_mesh_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _mesh_lod1: _mesh_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _mesh_lod2: _mesh_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	
	# LOD 0: Sombras completas de alta calidad
	_mesh_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# LOD 1: Sombras estándar normales (evita auto-oclusión negra excesiva por doble cara)
	if _mesh_lod1: _mesh_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# LOD 2: Sombras apagadas a larga distancia para ahorrar pasadas de shadow map
	if _mesh_lod2: _mesh_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _apply_lod_distance_ranges() -> void:
	if forced_lod_level >= 0:
		_update_forced_lod_visibility()
		return
	
	if disable_lod:
		_set_visibility_range(_mesh_lod0, 0.0, 0.0)
		_set_visibility_range(_mesh_lod1, 99999.0, 99999.0)
		_set_visibility_range(_mesh_lod2, 99999.0, 99999.0)
		_mesh_lod0.visible = true
		if _mesh_lod1: _mesh_lod1.visible = false
		if _mesh_lod2: _mesh_lod2.visible = false
		return
	
	# Conmutación nativa por GPU de Godot (0 ciclos de GDScript en _process)
	_set_visibility_range(_mesh_lod0, 0.0, lod0_range_end)
	_set_visibility_range(_mesh_lod1, lod0_range_end, lod1_range_end)
	_set_visibility_range(_mesh_lod2, lod1_range_end, lod2_range_end)

func _set_visibility_range(mi: GeometryInstance3D, range_begin: float, range_end: float) -> void:
	if mi == null:
		return
	mi.visible = true
	mi.visibility_range_begin = range_begin
	mi.visibility_range_end = range_end
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mi.visibility_range_begin_margin = 1.0 # 1m de histéresis para evitar popping por fluctuación de cámara
	mi.visibility_range_end_margin = 1.0

func _update_forced_lod_visibility() -> void:
	if _mesh_lod0 == null:
		return
	
	if forced_lod_level < 0:
		_apply_lod_distance_ranges()
		return
	
	# Desactivar rangos de distancia en modo forzado
	for mi in [_mesh_lod0, _mesh_lod1, _mesh_lod2]:
		if mi != null:
			mi.visibility_range_begin = 0.0
			mi.visibility_range_end = 0.0
	
	_mesh_lod0.visible = (forced_lod_level == 0)
	if _mesh_lod1: _mesh_lod1.visible = (forced_lod_level == 1)
	if _mesh_lod2: _mesh_lod2.visible = (forced_lod_level == 2)

func _update_shader_params() -> void:
	var h := maxf(_current_height, 0.1)
	var w_str := wind_strength if wind_enabled else 0.0
	
	if _material_veg:
		_material_veg.set_shader_parameter("plant_max_height", h)
		_material_veg.set_shader_parameter("wind_strength", w_str)
		_material_veg.set_shader_parameter("wind_speed", 2.2)
		_material_veg.set_shader_parameter("backlight_tint", Vector3(0.06, 0.28, 0.04))
		_material_veg.set_shader_parameter("roughness", 0.82)
		_material_veg.set_shader_parameter("specular", 0.03)
	
	if _material_flower:
		_material_flower.set_shader_parameter("plant_max_height", h)
		_material_flower.set_shader_parameter("wind_strength", w_str)
		_material_flower.set_shader_parameter("wind_speed", 2.2)
		_material_flower.set_shader_parameter("backlight_tint", Vector3(0.48, 0.18, 0.18))
		_material_flower.set_shader_parameter("roughness", 0.48)
		_material_flower.set_shader_parameter("specular", 0.18)

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

func get_mesh() -> Mesh:
	if _mesh_instance:
		return _mesh_instance.mesh
	return null

func get_triangle_count() -> int:
	return _cached_triangles

func get_vertex_count() -> int:
	return _cached_vertices

func get_mesh_lod(level: int) -> Mesh:
	match level:
		0: return _mesh_lod0.mesh if _mesh_lod0 else null
		1: return _mesh_lod1.mesh if _mesh_lod1 else null
		2: return _mesh_lod2.mesh if _mesh_lod2 else null
		_: return _mesh_lod0.mesh if _mesh_lod0 else null

func get_triangle_count_lod(level: int) -> int:
	match level:
		0: return _cached_triangles
		1: return _cached_triangles_lod1
		2: return _cached_triangles_lod2
		_: return _cached_triangles

func get_vertex_count_lod(level: int) -> int:
	match level:
		0: return _cached_vertices
		1: return _cached_vertices_lod1
		2: return _cached_vertices_lod2
		_: return _cached_vertices

## Permite alternar la rosa entre flor solitaria (corte) y rosal arbustivo
func set_rose_morphology(is_shrub: bool) -> void:
	profile_id = "shrub_rose" if is_shrub else "solitary_rose"

## Cosecha la flor si está en floración plena (>= 0.8)
func harvest() -> Dictionary:
	if growth_progress < 0.8:
		return {} # Aún no madura para cosecha
	
	var profile: Dictionary = FlowerProfiles.get_profile(profile_id)
	var palettes: Array = profile["color_palettes"]
	var c_idx := color_index if color_index >= 0 and color_index < palettes.size() else 0
	var flower_col: Color = palettes[c_idx]
	var col_name := "Rojo"
	if profile_id in ["solitary_rose", "shrub_rose"] and c_idx < FlowerProfiles.ROSE_COLOR_NAMES.size():
		col_name = FlowerProfiles.ROSE_COLOR_NAMES[c_idx]
	
	var yield_data := {
		"profile_id": profile_id,
		"species_name": profile["name"],
		"color": flower_col,
		"color_name": col_name,
		"flower_count": _flower_count,
		"height": _current_height
	}
	
	# Podar un rosal arbustivo lo regresa a etapa vegetativa (0.52) para volver a florecer
	# Cortar una flor solitaria poda el tallo a la base (0.15)
	if profile["morphology"] == FlowerProfiles.MORPHOLOGY_SHRUB:
		growth_progress = 0.52
	else:
		growth_progress = 0.15
	
	_has_bloomed = false
	generate()
	return yield_data
