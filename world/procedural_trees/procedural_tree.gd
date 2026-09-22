extends Node3D
class_name ProceduralTree

const ProceduralTreeProfiles = preload("res://world/procedural_trees/procedural_tree_profiles.gd")
const ProceduralTreeGenerator = preload("res://world/procedural_trees/procedural_tree_generator.gd")
const ProceduralTreeTextures = preload("res://world/procedural_trees/procedural_tree_textures.gd")
const ProceduralTreeMaterials = preload("res://world/procedural_trees/procedural_tree_materials.gd")
## Nodo visual de arbol procedural hiperoptimizado.
## Administra las instancias de MultiMeshInstance3D para ramas y hojas en 3 niveles de LOD.
## Soporta conmutacion automatica de LOD por distancia de Godot (visibility_range)
## o seleccion manual forzada para depuracion y pruebas.

enum FoliageStyle {
	STANDARD = 0,
	LOW_SPEC_TRIANGLE = 1
}

## Interruptor maestro para diagnóstico de rendimiento: si es verdadero, ningún árbol renderiza nada
static var trees_disabled: bool = false

@export var tree_seed: int = 12345
@export var profile_id: String = "pine_boreal"
@export var foliage_style: FoliageStyle = FoliageStyle.STANDARD:
	set(value):
		foliage_style = value
		if is_node_ready() and current_profile != null:
			generate(tree_seed, profile_id)

@export var use_foliage_textures: bool = true:
	set(value):
		use_foliage_textures = value
		_apply_shared_materials()

@export var cast_shadows: bool = false:
	set(value):
		cast_shadows = value
		_update_shadow_settings()

## Desactiva por completo el sistema de LOD: siempre muestra los árboles normales completos (LOD0) sin importar la distancia.
@export var disable_lod: bool = true:
	set(value):
		disable_lod = value
		if is_node_ready():
			_apply_lod_distance_ranges()

## Modo diagnóstico/rendimiento: desactiva totalmente las hojas, mostrando únicamente troncos.
@export var trunks_only: bool = false:
	set(value):
		trunks_only = value
		if is_node_ready():
			_apply_lod_distance_ranges()

# Distancias de transicion para los niveles de detalle (LOD)
# LOD0 (0-15m): Follaje de cáscara exterior 1:1 + ramas completas + SOMBRAS REALES DE HOJAS Y TRONCO
# LOD1 (15-40m): Follaje al 50% a escala idéntica 1:1 (cero pop) + sombra sólida de tronco
# LOD2 (40-80m): Tronco 2D en cruz (8 triángulos) + silueta perimetral 1:1 sin sombras
@export var lod0_range_end: float = 15.0
@export var lod1_range_end: float = 40.0
@export var lod2_range_end: float = 80.0

var tree_height: float = 0.0

# -1 = Auto (controlado por distancia de camara), 0 = LOD0, 1 = LOD1, 2 = LOD2
var forced_lod_level: int = -1:
	set(value):
		forced_lod_level = value
		_update_forced_lod_visibility()

# Nodos MultiMeshInstance3D para cada LOD (exactamente 2 llamadas de dibujo activas)
var _mi_branches_lod0: MultiMeshInstance3D
var _mi_leaves_lod0: MultiMeshInstance3D

var _mi_branches_lod1: MultiMeshInstance3D
var _mi_leaves_lod1: MultiMeshInstance3D

var _mi_branches_lod2: MultiMeshInstance3D
var _mi_leaves_lod2: MultiMeshInstance3D

var current_profile: ProceduralTreeProfiles.TreeProfile = null
var current_generation_result: ProceduralTreeGenerator.TreeGenerationResult = null


func _ready() -> void:
	_init_nodes_and_materials()
	if current_profile == null:
		generate(tree_seed, profile_id)


## Inicializa los nodos visuales de MultiMeshInstance3D y asigna los materiales compartidos.
func _init_nodes_and_materials() -> void:
	if _mi_branches_lod0 != null:
		return
	
	_mi_branches_lod0 = _create_mmi("Branches_LOD0")
	_mi_leaves_lod0 = _create_mmi("Leaves_LOD0")
	
	_mi_branches_lod1 = _create_mmi("Branches_LOD1")
	_mi_leaves_lod1 = _create_mmi("Leaves_LOD1")
	
	_mi_branches_lod2 = _create_mmi("Branches_LOD2")
	_mi_leaves_lod2 = _create_mmi("Leaves_LOD2")
	
	_apply_shared_materials()
	_update_shadow_settings()
	_apply_lod_distance_ranges()


## Aplica las configuraciones de sombra selectivas para optimización máxima de GPU.
## LOD0 proyecta sombras orgánicas completas (hojas y ramas).
## LOD1 proyecta sombra sólida de tronco.
## LOD2 no proyecta sombras para mantener los FPS en 60 al mirar hacia el horizonte.
func _update_shadow_settings() -> void:
	if _mi_branches_lod0 == null:
		return
	
	if not cast_shadows:
		_mi_branches_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_branches_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_branches_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	
	# LOD 0: Sombra completa y hermosa de tronco + hojas (auto-sombra en copa y suelo)
	_mi_branches_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mi_leaves_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# LOD 1: Sombra sólida de tronco; hojas apagadas para ahorrar pasadas de fragmento
	_mi_branches_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mi_leaves_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# LOD 2: Sin sombras lejanas
	_mi_branches_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi_leaves_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Asigna los materiales compartidos desde la caché global (batching GPU óptimo).
func _apply_shared_materials() -> void:
	if _mi_branches_lod0 == null:
		return
	var target_pid := profile_id if not profile_id.is_empty() else "classic_oak"
	var bark_mat := ProceduralTreeMaterials.get_bark_material(target_pid, use_foliage_textures)
	var leaf_mat := ProceduralTreeMaterials.get_leaf_material(target_pid, use_foliage_textures)
	
	_mi_branches_lod0.material_override = bark_mat
	_mi_branches_lod1.material_override = bark_mat
	_mi_branches_lod2.material_override = bark_mat
	
	_mi_leaves_lod0.material_override = leaf_mat
	_mi_leaves_lod1.material_override = leaf_mat
	_mi_leaves_lod2.material_override = leaf_mat


## Crea un MultiMeshInstance3D hijo.
func _create_mmi(node_name: String) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	add_child(mmi)
	return mmi


## Configura los rangos de visibilidad nativos de Godot (GeometryInstance3D).
func _apply_lod_distance_ranges() -> void:
	if trees_disabled:
		visible = false
		if _mi_branches_lod0 != null: _mi_branches_lod0.visible = false
		if _mi_leaves_lod0 != null: _mi_leaves_lod0.visible = false
		if _mi_branches_lod1 != null: _mi_branches_lod1.visible = false
		if _mi_leaves_lod1 != null: _mi_leaves_lod1.visible = false
		if _mi_branches_lod2 != null: _mi_branches_lod2.visible = false
		if _mi_leaves_lod2 != null: _mi_leaves_lod2.visible = false
		return

	if forced_lod_level >= 0:
		_update_forced_lod_visibility()
		return
	
	if disable_lod:
		# Sistema LOD desactivado: siempre renderizar arboles normales completos (LOD0) a cualquier distancia
		_set_visibility_range(_mi_branches_lod0, 0.0, 0.0)
		_set_visibility_range(_mi_leaves_lod0, 0.0, 0.0)
		
		# Apagar por completo niveles de detalle reducidos
		if _mi_branches_lod1 != null:
			_mi_branches_lod1.visible = false
			_mi_branches_lod1.visibility_range_begin = 99999.0
			_mi_branches_lod1.visibility_range_end = 99999.0
		if _mi_leaves_lod1 != null:
			_mi_leaves_lod1.visible = false
			_mi_leaves_lod1.visibility_range_begin = 99999.0
			_mi_leaves_lod1.visibility_range_end = 99999.0
		if _mi_branches_lod2 != null:
			_mi_branches_lod2.visible = false
			_mi_branches_lod2.visibility_range_begin = 99999.0
			_mi_branches_lod2.visibility_range_end = 99999.0
		if _mi_leaves_lod2 != null:
			_mi_leaves_lod2.visible = false
			_mi_leaves_lod2.visibility_range_begin = 99999.0
			_mi_leaves_lod2.visibility_range_end = 99999.0
		return
	
	# LOD 0 (0-15m): visible de 0m a lod0_range_end
	_set_visibility_range(_mi_branches_lod0, 0.0, lod0_range_end)
	if trunks_only:
		_mi_leaves_lod0.visible = false
		_mi_leaves_lod0.visibility_range_begin = 99999.0
		_mi_leaves_lod0.visibility_range_end = 99999.0
	else:
		_set_visibility_range(_mi_leaves_lod0, 0.0, lod0_range_end)
	
	# LOD 1 (15-40m):
	_set_visibility_range(_mi_branches_lod1, lod0_range_end, lod1_range_end)
	if trunks_only:
		if _mi_leaves_lod1 != null:
			_mi_leaves_lod1.visible = false
			_mi_leaves_lod1.visibility_range_begin = 99999.0
			_mi_leaves_lod1.visibility_range_end = 99999.0
	else:
		_set_visibility_range(_mi_leaves_lod1, lod0_range_end, lod1_range_end)
	
	# LOD 2 (40-80m):
	_set_visibility_range(_mi_branches_lod2, lod1_range_end, lod2_range_end)
	if trunks_only:
		if _mi_leaves_lod2 != null:
			_mi_leaves_lod2.visible = false
			_mi_leaves_lod2.visibility_range_begin = 99999.0
			_mi_leaves_lod2.visibility_range_end = 99999.0
	else:
		_set_visibility_range(_mi_leaves_lod2, lod1_range_end, lod2_range_end)


func _set_visibility_range(mmi: GeometryInstance3D, range_begin: float, range_end: float) -> void:
	if mmi == null:
		return
	mmi.visible = true
	mmi.visibility_range_begin = range_begin
	mmi.visibility_range_end = range_end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mmi.visibility_range_begin_margin = 0.0
	mmi.visibility_range_end_margin = 0.0


## Aplica visibilidad forzada manual cuando se depura un nivel especifico.
func _update_forced_lod_visibility() -> void:
	if trees_disabled:
		visible = false
		return
	if _mi_branches_lod0 == null:
		return
	
	if forced_lod_level < 0:
		# Restaurar comportamiento automatico por distancia
		_apply_lod_distance_ranges()
		return
	
	# Desactivar rangos de distancia en modo forzado
	for mmi in [_mi_branches_lod0, _mi_leaves_lod0, _mi_branches_lod1, _mi_leaves_lod1, _mi_branches_lod2, _mi_leaves_lod2]:
		if mmi != null:
			mmi.visibility_range_begin = 0.0
			mmi.visibility_range_end = 0.0
	
	_mi_branches_lod0.visible = (forced_lod_level == 0)
	_mi_leaves_lod0.visible = (forced_lod_level == 0)
	
	_mi_branches_lod1.visible = (forced_lod_level == 1)
	_mi_leaves_lod1.visible = (forced_lod_level == 1)
	
	_mi_branches_lod2.visible = (forced_lod_level == 2)
	_mi_leaves_lod2.visible = (forced_lod_level == 2)


## Genera o regenera el arbol con la semilla y perfil dados.
func generate(new_seed: int = -1, new_profile_id: String = "") -> ProceduralTreeGenerator.TreeGenerationResult:
	_init_nodes_and_materials()
	if trees_disabled:
		visible = false
		return null
	
	if new_seed >= 0:
		tree_seed = new_seed
	if not new_profile_id.is_empty():
		profile_id = new_profile_id
	
	current_profile = ProceduralTreeProfiles.get_profile(profile_id)
	_apply_shared_materials()
	
	# Invocar el generador matematico
	var gen_foliage_mode: int = ProceduralTreeGenerator.FoliageMode.LOW_SPEC_TRIANGLE if foliage_style == FoliageStyle.LOW_SPEC_TRIANGLE else ProceduralTreeGenerator.FoliageMode.STANDARD
	current_generation_result = ProceduralTreeGenerator.generate_tree(current_profile, tree_seed, gen_foliage_mode)
	tree_height = current_generation_result.tree_height
	
	# Asignar los MultiMeshes generados a los nodos visuales
	_mi_branches_lod0.multimesh = current_generation_result.mm_branches_lod0
	_mi_leaves_lod0.multimesh = current_generation_result.mm_leaves_lod0
	
	_mi_branches_lod1.multimesh = current_generation_result.mm_branches_lod1
	_mi_leaves_lod1.multimesh = current_generation_result.mm_leaves_lod1
	
	_mi_branches_lod2.multimesh = current_generation_result.mm_branches_lod2
	_mi_leaves_lod2.multimesh = current_generation_result.mm_leaves_lod2
	
	_update_shadow_settings()
	_update_forced_lod_visibility()
	return current_generation_result


## Aplica un resultado de generacion precalculado (ej. desde un hilo de fondo WorkerThreadPool).
## Costo en el hilo principal: ~0.005 ms (solo asignacion de referencias de MultiMesh).
func apply_generation_result(result: ProceduralTreeGenerator.TreeGenerationResult) -> void:
	if trees_disabled:
		visible = false
		return
	_init_nodes_and_materials()
	current_generation_result = result
	if result != null:
		tree_height = result.tree_height
		if result.profile != null:
			profile_id = result.profile.id
			current_profile = result.profile
		_apply_shared_materials()
		
		_mi_branches_lod0.multimesh = result.mm_branches_lod0
		_mi_leaves_lod0.multimesh = result.mm_leaves_lod0
		
		_mi_branches_lod1.multimesh = result.mm_branches_lod1
		_mi_leaves_lod1.multimesh = result.mm_leaves_lod1
		
		_mi_branches_lod2.multimesh = result.mm_branches_lod2
		_mi_leaves_lod2.multimesh = result.mm_leaves_lod2
	
	_update_shadow_settings()
	_update_forced_lod_visibility()
