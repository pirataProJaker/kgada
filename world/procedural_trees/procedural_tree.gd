extends Node3D
class_name ProceduralTree

const ProceduralTreeProfiles = preload("res://world/procedural_trees/procedural_tree_profiles.gd")
const ProceduralTreeGenerator = preload("res://world/procedural_trees/procedural_tree_generator.gd")
const ProceduralTreeTextures = preload("res://world/procedural_trees/procedural_tree_textures.gd")
## Nodo visual de arbol procedural hiperoptimizado.
## Administra las instancias de MultiMeshInstance3D para ramas y hojas en 3 niveles de LOD.
## Soporta conmutacion automatica de LOD por distancia de Godot (visibility_range)
## o seleccion manual forzada para depuracion y pruebas.

@export var tree_seed: int = 12345
@export var profile_id: String = "pine_boreal"
@export var use_foliage_textures: bool = true:
	set(value):
		use_foliage_textures = value
		_update_leaf_material_texture()

# Distancias de transicion para los niveles de detalle (LOD)
@export var lod0_range_end: float = 26.0
@export var lod1_range_end: float = 65.0
@export var lod2_range_end: float = 180.0

# -1 = Auto (controlado por distancia de camara), 0 = LOD0, 1 = LOD1, 2 = LOD2
var forced_lod_level: int = -1:
	set(value):
		forced_lod_level = value
		_update_forced_lod_visibility()

# Nodos MultiMeshInstance3D para cada LOD
var _mi_branches_lod0: MultiMeshInstance3D
var _mi_leaves_lod0: MultiMeshInstance3D

var _mi_branches_lod1: MultiMeshInstance3D
var _mi_leaves_lod1: MultiMeshInstance3D

var _mi_branches_lod2: MultiMeshInstance3D
var _mi_leaves_lod2: MultiMeshInstance3D

# Materiales base compartidos
var _bark_material: Material
var _leaf_material: StandardMaterial3D

var current_profile: ProceduralTreeProfiles.TreeProfile = null
var current_generation_result: ProceduralTreeGenerator.TreeGenerationResult = null


func _ready() -> void:
	_init_nodes_and_materials()
	if current_profile == null:
		generate(tree_seed, profile_id)


## Inicializa los nodos visuales de MultiMeshInstance3D y sus materiales.
func _init_nodes_and_materials() -> void:
	if _mi_branches_lod0 != null:
		return
	
	var bark_shader := load("res://world/procedural_trees/bark_shader.gdshader") as Shader
	var s_mat := ShaderMaterial.new()
	s_mat.shader = bark_shader
	_bark_material = s_mat
	
	_leaf_material = StandardMaterial3D.new()
	_leaf_material.roughness = 0.88
	_leaf_material.metallic_specular = 0.12 # Reduce destellos ruidosos bajo la luz solar en Godot 4
	_leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED # Visible por ambas caras
	_leaf_material.vertex_color_use_as_albedo = true # Aplica el tinte por instancia
	_leaf_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_leaf_material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
	_leaf_material.alpha_antialiasing_edge = 0.30
	_update_leaf_material_texture()
	
	_mi_branches_lod0 = _create_mmi("Branches_LOD0", _bark_material)
	_mi_leaves_lod0 = _create_mmi("Leaves_LOD0", _leaf_material)
	
	_mi_branches_lod1 = _create_mmi("Branches_LOD1", _bark_material)
	_mi_leaves_lod1 = _create_mmi("Leaves_LOD1", _leaf_material)
	
	_mi_branches_lod2 = _create_mmi("Branches_LOD2", _bark_material)
	_mi_leaves_lod2 = _create_mmi("Leaves_LOD2", _leaf_material)
	
	_apply_lod_distance_ranges()


## Crea un MultiMeshInstance3D hijo configurado con su material.
func _create_mmi(node_name: String, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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


func _set_visibility_range(mmi: MultiMeshInstance3D, range_begin: float, range_end: float) -> void:
	if mmi == null:
		return
	mmi.visible = true
	mmi.visibility_range_begin = range_begin
	mmi.visibility_range_end = range_end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


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
	if _bark_material is ShaderMaterial:
		var s_mat := _bark_material as ShaderMaterial
		s_mat.set_shader_parameter("bark_color", current_profile.bark_color)
		s_mat.set_shader_parameter("bark_texture", ProceduralTreeTextures.get_bark_texture(current_profile.id))
		s_mat.set_shader_parameter("use_texture", use_foliage_textures)
	
	# Invocar el generador matematico
	current_generation_result = ProceduralTreeGenerator.generate_tree(current_profile, tree_seed)
	
	# Asignar los MultiMeshes generados a los nodos visuales
	_mi_branches_lod0.multimesh = current_generation_result.mm_branches_lod0
	_mi_leaves_lod0.multimesh = current_generation_result.mm_leaves_lod0
	
	_mi_branches_lod1.multimesh = current_generation_result.mm_branches_lod1
	_mi_leaves_lod1.multimesh = current_generation_result.mm_leaves_lod1
	
	_mi_branches_lod2.multimesh = current_generation_result.mm_branches_lod2
	_mi_leaves_lod2.multimesh = current_generation_result.mm_leaves_lod2
	
	_update_leaf_material_texture()
	_update_forced_lod_visibility()
	return current_generation_result


## Actualiza los materiales de corteza y hojas con sus texturas reales.
func _update_leaf_material_texture() -> void:
	if _leaf_material != null:
		if use_foliage_textures and current_profile != null:
			_leaf_material.albedo_texture = ProceduralTreeTextures.get_foliage_texture(current_profile.id)
			_leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			_leaf_material.alpha_scissor_threshold = 0.42
			_leaf_material.albedo_color = Color.WHITE # Deja que el vertex color y la textura se combinen naturalmente
		else:
			_leaf_material.albedo_texture = null
			_leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			if current_profile != null:
				_leaf_material.albedo_color = current_profile.leaf_color_primary
	
	if _bark_material != null and current_profile != null:
		if _bark_material is ShaderMaterial:
			var s_mat := _bark_material as ShaderMaterial
			s_mat.set_shader_parameter("bark_texture", ProceduralTreeTextures.get_bark_texture(current_profile.id))
			s_mat.set_shader_parameter("bark_color", current_profile.bark_color)
			s_mat.set_shader_parameter("use_texture", use_foliage_textures)
		elif _bark_material is StandardMaterial3D:
			var std_mat := _bark_material as StandardMaterial3D
			std_mat.albedo_color = current_profile.bark_color
