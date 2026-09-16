extends RefCounted
class_name ProceduralTreeMaterials

## Administrador y caché global de materiales compartidos para árboles procedurales.
## Evita la duplicación masiva de ShaderMaterial y StandardMaterial3D en GPU.
## Todos los árboles de la misma especie comparten exactamente el mismo material,
## permitiendo batching de draw calls y minimizando cambios de pipeline en D3D12/Vulkan.

const ProceduralTreeProfiles = preload("res://world/procedural_trees/procedural_tree_profiles.gd")
const ProceduralTreeTextures = preload("res://world/procedural_trees/procedural_tree_textures.gd")
const BARK_SHADER = preload("res://world/procedural_trees/bark_shader.gdshader")

static var _bark_materials: Dictionary = {}
static var _leaf_materials: Dictionary = {}


static func get_bark_material(profile_id: String, use_textures: bool = true) -> Material:
	var key := "%s_tex_%s" % [profile_id, str(use_textures)]
	if _bark_materials.has(key):
		return _bark_materials[key]
	
	var profile := ProceduralTreeProfiles.get_profile(profile_id)
	var mat := ShaderMaterial.new()
	mat.shader = BARK_SHADER
	mat.set_shader_parameter("bark_color", profile.bark_color)
	mat.set_shader_parameter("bark_texture", ProceduralTreeTextures.get_bark_texture(profile.id))
	mat.set_shader_parameter("use_texture", use_textures)
	
	_bark_materials[key] = mat
	return mat


static func get_leaf_material(profile_id: String, use_textures: bool = true) -> StandardMaterial3D:
	var key := "%s_tex_%s" % [profile_id, str(use_textures)]
	if _leaf_materials.has(key):
		return _leaf_materials[key]
	
	var profile := ProceduralTreeProfiles.get_profile(profile_id)
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.metallic_specular = 0.02 # Sin brillo de plástico pulido
	mat.backlight_enabled = true
	mat.backlight = Color(0.20, 0.28, 0.14) # Translucidez solar orgánica
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Visible por ambas caras
	mat.vertex_color_use_as_albedo = true # Gradiente por instancia
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF # Máximo rendimiento en GPU integrada
	
	if use_textures and profile.has_leaves:
		mat.albedo_texture = ProceduralTreeTextures.get_foliage_texture(profile.id)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.42
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_texture = null
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color = profile.leaf_color_primary
		
	_leaf_materials[key] = mat
	return mat


static func preload_all_materials() -> void:
	for pid in ["classic_oak", "pine_boreal", "autumn_birch", "weeping_willow", "dead_tree", "shrub_sapling"]:
		get_bark_material(pid, true)
		get_leaf_material(pid, true)


static func clear_cache() -> void:
	_bark_materials.clear()
	_leaf_materials.clear()
