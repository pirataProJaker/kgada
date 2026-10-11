class_name ProceduralRoadMaterials
extends RefCounted
## Gestor centralizado de materiales para el sistema de carreteras procedurales.
## Aplica texturas de ruido de píxel auténtico estilo PSX / retro:
## - Asfalto: ruido de píxeles grises / negros con grano mineral.
## - Banqueta: ruido de píxeles grises / blancos con juntas de dilatación.
## - Bordillos: textura de concreto pétreo.
## Utiliza mapeo Triplanar en Coordenadas de Mundo (uv1_world_triplanar = true) con filtrado NEAREST
## para que todos los píxeles sean perfectamente cuadrados y uniformes a lo largo de cualquier
## longitud de vía, evitando cualquier estiramiento o distorsión.

static var _materials: Dictionary = {}

const KEY_ASPHALT := "asphalt"
const KEY_SIDEWALK := "sidewalk"
const KEY_CURB := "curb"
const KEY_MEDIAN := "median"
const KEY_GRASS := "grass"
const KEY_YELLOW_LINE := "yellow_line"
const KEY_WHITE_LINE := "white_line"

# Claves de materiales para postes de luz (Luminarias)
const KEY_POLE_METAL_CLEAN := "pole_metal_clean"
const KEY_POLE_METAL_RUSTY := "pole_metal_rusty"
const KEY_POLE_YELLOW_CLEAN := "pole_yellow_clean"
const KEY_POLE_YELLOW_RUSTY := "pole_yellow_rusty"
const KEY_LAMP_LED := "lamp_led"

const PATH_ASPHALT_TEX := "res://assets/textures/roads/asphalt_pixel_noise.png"
const PATH_SIDEWALK_TEX := "res://assets/textures/roads/sidewalk_pixel_noise.png"
const PATH_CURB_TEX := "res://assets/textures/roads/curb_pixel_noise.png"

const PATH_POLE_METAL_CLEAN := "res://assets/textures/props/streetlights/pole_metal_clean.png"
const PATH_POLE_METAL_RUSTY := "res://assets/textures/props/streetlights/pole_metal_rusty.png"
const PATH_POLE_YELLOW_CLEAN := "res://assets/textures/props/streetlights/pole_yellow_clean.png"
const PATH_POLE_YELLOW_RUSTY := "res://assets/textures/props/streetlights/pole_yellow_rusty.png"

const PATH_ROAD_SHADER := "res://world/city/road_triplanar.gdshader"
const PATH_TERRAIN_SHADER := "res://shaders/psx_vertex_snap.gdshader"

static var _shader_cache: Shader = null
static var _terrain_shader_cache: Shader = null

static func _get_road_shader() -> Shader:
	if _shader_cache != null:
		return _shader_cache
	if ResourceLoader.exists(PATH_ROAD_SHADER):
		var res = load(PATH_ROAD_SHADER)
		if res is Shader:
			_shader_cache = res
			return _shader_cache
	var abs_path := ProjectSettings.globalize_path(PATH_ROAD_SHADER)
	if FileAccess.file_exists(abs_path):
		var file := FileAccess.open(abs_path, FileAccess.READ)
		var code := file.get_as_text()
		var s := Shader.new()
		s.code = code
		_shader_cache = s
		return _shader_cache
	return null


static func _get_terrain_shader() -> Shader:
	if _terrain_shader_cache != null:
		return _terrain_shader_cache
	if ResourceLoader.exists(PATH_TERRAIN_SHADER):
		var res = load(PATH_TERRAIN_SHADER)
		if res is Shader:
			_terrain_shader_cache = res
			return _terrain_shader_cache
	var abs_path := ProjectSettings.globalize_path(PATH_TERRAIN_SHADER)
	if FileAccess.file_exists(abs_path):
		var file := FileAccess.open(abs_path, FileAccess.READ)
		var code := file.get_as_text()
		var s := Shader.new()
		s.code = code
		_terrain_shader_cache = s
		return _terrain_shader_cache
	return null


static func get_material(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]

	var shader := _get_road_shader()

	match key:
		KEY_ASPHALT:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			var tex := _load_texture_direct(PATH_ASPHALT_TEX)
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
				print("[ProceduralRoadMaterials] Textura de asfalto asignada correctamente.")
			mat.set_shader_parameter("albedo_tint", Color(1.0, 1.0, 1.0, 1.0))
			mat.set_shader_parameter("uv_scale", 0.25)
			mat.set_shader_parameter("roughness", 0.90)
			mat.set_shader_parameter("triplanar_sharpness", 16.0)
			_materials[key] = mat
			return mat

		KEY_SIDEWALK:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			var tex := _load_texture_direct(PATH_SIDEWALK_TEX)
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
				print("[ProceduralRoadMaterials] Textura de banqueta asignada correctamente.")
			mat.set_shader_parameter("albedo_tint", Color(1.0, 1.0, 1.0, 1.0))
			mat.set_shader_parameter("uv_scale", 0.35) # 1 cuadro grande cada ~2.85 metros (abarca la banqueta completa sin parecer azulejos)
			mat.set_shader_parameter("roughness", 0.85)
			mat.set_shader_parameter("triplanar_sharpness", 16.0)
			mat.set_shader_parameter("is_directional_along_road", true)
			_materials[key] = mat
			return mat

		KEY_CURB:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			var tex := _load_texture_direct(PATH_CURB_TEX)
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
				print("[ProceduralRoadMaterials] Textura de bordillo asignada correctamente.")
			mat.set_shader_parameter("albedo_tint", Color(1.0, 1.0, 1.0, 1.0))
			mat.set_shader_parameter("uv_scale", 0.25)
			mat.set_shader_parameter("roughness", 0.80)
			mat.set_shader_parameter("triplanar_sharpness", 16.0)
			_materials[key] = mat
			return mat

		KEY_MEDIAN:
			# Shader oficial de terreno del mundo en modo Tierra (force_dirt)
			var mat := ShaderMaterial.new()
			var t_shader := _get_terrain_shader()
			mat.shader = t_shader
			mat.set_shader_parameter("grid_precision", 260)
			mat.set_shader_parameter("use_pixel_terrain", true)
			mat.set_shader_parameter("pixel_size", 0.08)
			mat.set_shader_parameter("force_dirt", true)
			mat.set_shader_parameter("use_psx_color_depth", true)
			mat.set_shader_parameter("dirt_d1", Color(0.15, 0.10, 0.06, 1.0))
			mat.set_shader_parameter("dirt_d2", Color(0.22, 0.15, 0.09, 1.0))
			mat.set_shader_parameter("dirt_d3", Color(0.30, 0.21, 0.13, 1.0))
			mat.set_shader_parameter("dirt_d4", Color(0.38, 0.28, 0.17, 1.0))
			mat.set_shader_parameter("dirt_d5", Color(0.47, 0.35, 0.22, 1.0))
			_materials[key] = mat
			print("[ProceduralRoadMaterials] Shader de terreno del mundo asignado a KEY_MEDIAN (tierra).")
			return mat

		KEY_GRASS:
			# Shader oficial de terreno del mundo en modo Pasto (force_grass)
			var mat := ShaderMaterial.new()
			var t_shader := _get_terrain_shader()
			mat.shader = t_shader
			mat.set_shader_parameter("grid_precision", 260)
			mat.set_shader_parameter("use_pixel_terrain", true)
			mat.set_shader_parameter("pixel_size", 0.08)
			mat.set_shader_parameter("force_grass", true)
			mat.set_shader_parameter("use_psx_color_depth", true)
			mat.set_shader_parameter("grass_g1", Color(0.10, 0.24, 0.08, 1.0))
			mat.set_shader_parameter("grass_g2", Color(0.14, 0.32, 0.11, 1.0))
			mat.set_shader_parameter("grass_g3", Color(0.19, 0.42, 0.14, 1.0))
			mat.set_shader_parameter("grass_g4", Color(0.25, 0.52, 0.18, 1.0))
			mat.set_shader_parameter("grass_g5", Color(0.32, 0.62, 0.22, 1.0))
			_materials[key] = mat
			print("[ProceduralRoadMaterials] Shader de terreno del mundo asignado a KEY_GRASS (pasto).")
			return mat

		KEY_WHITE_LINE:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = Color(0.96, 0.96, 0.96, 1.0)
			mat.roughness = 0.45
			mat.render_priority = 2
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials[key] = mat
			return mat

		KEY_YELLOW_LINE:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = Color(0.96, 0.75, 0.08, 1.0)
			mat.roughness = 0.45
			mat.render_priority = 2
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials[key] = mat
			return mat

		KEY_POLE_METAL_CLEAN:
			var mat := StandardMaterial3D.new()
			var tex := _load_texture_direct(PATH_POLE_METAL_CLEAN)
			if tex:
				mat.albedo_texture = tex
			else:
				mat.albedo_color = Color(0.65, 0.68, 0.72)
			mat.metallic = 0.85
			mat.roughness = 0.35
			mat.uv1_scale = Vector3(1.0, 3.5, 1.0)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			_materials[key] = mat
			return mat

		KEY_POLE_METAL_RUSTY:
			var mat := StandardMaterial3D.new()
			var tex := _load_texture_direct(PATH_POLE_METAL_RUSTY)
			if tex:
				mat.albedo_texture = tex
			else:
				mat.albedo_color = Color(0.48, 0.42, 0.38)
			mat.metallic = 0.50
			mat.roughness = 0.70
			mat.uv1_scale = Vector3(1.0, 3.5, 1.0)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			_materials[key] = mat
			return mat

		KEY_POLE_YELLOW_CLEAN:
			var mat := StandardMaterial3D.new()
			var tex := _load_texture_direct(PATH_POLE_YELLOW_CLEAN)
			if tex:
				mat.albedo_texture = tex
			else:
				mat.albedo_color = Color(0.95, 0.75, 0.05)
			mat.metallic = 0.05
			mat.roughness = 0.45
			mat.uv1_scale = Vector3(1.0, 3.5, 1.0)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			_materials[key] = mat
			return mat

		KEY_POLE_YELLOW_RUSTY:
			var mat := StandardMaterial3D.new()
			var tex := _load_texture_direct(PATH_POLE_YELLOW_RUSTY)
			if tex:
				mat.albedo_texture = tex
			else:
				mat.albedo_color = Color(0.80, 0.58, 0.15)
			mat.metallic = 0.15
			mat.roughness = 0.65
			mat.uv1_scale = Vector3(1.0, 3.5, 1.0)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			_materials[key] = mat
			return mat

		KEY_LAMP_LED:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.95, 0.75)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.95, 0.75)
			mat.emission_energy_multiplier = 2.5
			_materials[key] = mat
			return mat

		_:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)
			_materials[key] = mat
			return mat



static func get_all_material_keys() -> Array[String]:
	return [
		KEY_ASPHALT, KEY_SIDEWALK, KEY_CURB, KEY_MEDIAN, KEY_GRASS, KEY_YELLOW_LINE, KEY_WHITE_LINE,
		KEY_POLE_METAL_CLEAN, KEY_POLE_METAL_RUSTY, KEY_POLE_YELLOW_CLEAN, KEY_POLE_YELLOW_RUSTY, KEY_LAMP_LED
	]


static func clear_cache() -> void:
	_materials.clear()


static func _load_texture_direct(path: String) -> Texture2D:
	# 1. Intentar por ResourceLoader si ya está importada por el editor
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res

	# 2. Carga directa de la imagen cruda desde el disco (independiente del pipeline de importación)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		var err := img.load(abs_path)
		if err == OK:
			return ImageTexture.create_from_image(img)

	return null

