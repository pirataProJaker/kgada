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

@export var tree_seed: int = 12345
@export var profile_id: String = "pine_boreal"
@export var use_foliage_textures: bool = true:
	set(value):
		use_foliage_textures = value
		_apply_shared_materials()

# Distancias de transicion para los niveles de detalle (LOD)
# LOD0 (0-18m): Follaje denso + ramas completas + SOMBRAS REALES DE HOJAS Y TRONCO
# LOD1 (18-45m): Follaje al 25% + ramas principales + sombra sólida de tronco
# LOD2 (45-85m): Silueta exterior hiperliviana sin sombras para no cargar el horizonte
@export var lod0_range_end: float = 18.0
@export var lod1_range_end: float = 45.0
@export var lod2_range_end: float = 85.0

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
	if forced_lod_level >= 0:
		_update_forced_lod_visibility()
		return
	
	# LOD 0: visible de 0m a lod0_range_end
	_set_visibility_range(_mi_branches_lod0, 0.0, lod0_range_end)
	_set_visibility_range(_mi_leaves_lod0, 0.0, lod0_range_end)
	
	# LOD 1: visible de lod0_range_end a lod1_range_end
	_set_visibility_range(_mi_branches_lod1, lod0_range_end, lod1_range_end)
	_set_visibility_range(_mi_leaves_lod1, lod0_range_end, lod1_range_end)
	
	# LOD 2: visible de lod1_range_end a lod2_range_end
	_set_visibility_range(_mi_branches_lod2, lod1_range_end, lod2_range_end)
	_set_visibility_range(_mi_leaves_lod2, lod1_range_end, lod2_range_end)


func _set_visibility_range(mmi: GeometryInstance3D, range_begin: float, range_end: float) -> void:
	if mmi == null:
		return
	mmi.visible = true
	mmi.visibility_range_begin = range_begin
	mmi.visibility_range_end = range_end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Aplica visibilidad forzada manual cuando se depura un nivel especifico.
func _update_forced_lod_visibility() -> void:
	if _mi_branches_lod0 == null:
		return
	
	if forced_lod_level < 0:
		# Restaurar comportamiento automatico por distancia
		_apply_lod_distance_ranges()
		return
	
	# Desactivar rangos de distancia en modo forzado
	for mmi in [_mi_branches_lod0, _mi_leaves_lod0, _mi_branches_lod1, _mi_leaves_lod1, _mi_branches_lod2, _mi_leaves_lod2]:
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
	
	if new_seed >= 0:
		tree_seed = new_seed
	if not new_profile_id.is_empty():
		profile_id = new_profile_id
	
	current_profile = ProceduralTreeProfiles.get_profile(profile_id)
	_apply_shared_materials()
	
	# Invocar el generador matematico
	current_generation_result = ProceduralTreeGenerator.generate_tree(current_profile, tree_seed)
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
