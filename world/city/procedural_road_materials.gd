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
const KEY_YELLOW_LINE := "yellow_line"
const KEY_WHITE_LINE := "white_line"

const PATH_ASPHALT_TEX := "res://assets/textures/roads/asphalt_pixel_noise.png"
const PATH_SIDEWALK_TEX := "res://assets/textures/roads/sidewalk_pixel_noise.png"
const PATH_CURB_TEX := "res://assets/textures/roads/curb_pixel_noise.png"


const PATH_ROAD_SHADER := "res://world/city/road_triplanar.gdshader"

static var _shader_cache: Shader = null

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
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = Color(0.24, 0.48, 0.18, 1.0)
			mat.roughness = 0.90
			_materials[key] = mat
			return mat

		KEY_WHITE_LINE:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = Color(0.96, 0.96, 0.96, 1.0)
			mat.roughness = 0.55
			_materials[key] = mat
			return mat

		KEY_YELLOW_LINE:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = Color(0.94, 0.73, 0.08, 1.0)
			mat.roughness = 0.55
			_materials[key] = mat
			return mat

		_:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)
			_materials[key] = mat
			return mat



static func get_all_material_keys() -> Array[String]:
	return [KEY_ASPHALT, KEY_SIDEWALK, KEY_CURB, KEY_MEDIAN, KEY_YELLOW_LINE, KEY_WHITE_LINE]


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

