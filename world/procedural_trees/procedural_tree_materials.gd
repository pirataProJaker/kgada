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


static func _load_texture(path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null


static func get_bark_material(profile_id: String, use_textures: bool = true) -> Material:
	var key := "%s_tex_%s" % [profile_id, str(use_textures)]
	if _bark_materials.has(key):
		return _bark_materials[key]
	
	var profile := ProceduralTreeProfiles.get_profile(profile_id)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Mat_Bark_" + profile_id
	var bark_tex := _load_texture("res://assets/vegetation/alnus/alnus_bark.png")
	if not bark_tex:
		bark_tex = ProceduralTreeTextures.get_bark_texture(profile.id)
	
	if use_textures and bark_tex != null:
		mat.albedo_texture = bark_tex
		var base_tint := Color(0.72, 0.64, 0.54)
		if profile_id.to_lower().begins_with("birch") or profile_id.to_lower() == "autumn_birch":
			mat.albedo_color = Color(0.85, 0.82, 0.78)
		elif profile_id.to_lower() == "dead_tree":
			mat.albedo_color = Color(0.35, 0.30, 0.26)
		else:
			mat.albedo_color = base_tint
	else:
		mat.albedo_color = profile.bark_color
		
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.texture_repeat = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	_bark_materials[key] = mat
	return mat


static func get_leaf_material(profile_id: String, use_textures: bool = true) -> Material:
	var key := "%s_tex_%s" % [profile_id, str(use_textures)]
	if _leaf_materials.has(key):
		return _leaf_materials[key]
	
	var profile := ProceduralTreeProfiles.get_profile(profile_id)
	if not profile.has_leaves:
		var empty_mat := StandardMaterial3D.new()
		empty_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		empty_mat.albedo_color = Color(0, 0, 0, 0)
		_leaf_materials[key] = empty_mat
		return empty_mat
	
	var shader_res = load("res://world/botanical_trees/alnus_bough.gdshader")
	if shader_res is Shader:
		var s_mat := ShaderMaterial.new()
		s_mat.shader = shader_res
		var bough_tex := _load_texture("res://assets/vegetation/alnus/alnus_bough_atlas.png")
		if bough_tex:
			s_mat.set_shader_parameter("texture_albedo", bough_tex)
		s_mat.set_shader_parameter("alpha_scissor_threshold", 0.25)
		s_mat.set_shader_parameter("backlight_energy", 0.45)
		_leaf_materials[key] = s_mat
		return s_mat
	
	# Respaldo StandardMaterial3D si el shader no se encuentra
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.82
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if use_textures:
		mat.albedo_texture = _load_texture("res://assets/vegetation/alnus/alnus_bough_atlas.png")
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.25
	else:
		mat.albedo_color = profile.leaf_color_primary
	_leaf_materials[key] = mat
	return mat


static func preload_all_materials() -> void:
	for pid in ["classic_oak", "pine_boreal", "alnus_acuminata", "autumn_birch", "weeping_willow", "dead_tree", "shrub_sapling"]:
		get_bark_material(pid, true)
		get_leaf_material(pid, true)


static func clear_cache() -> void:
	_bark_materials.clear()
	_leaf_materials.clear()
