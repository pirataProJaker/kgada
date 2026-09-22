class_name ProceduralRoadMaterials
extends RefCounted
## Gestor centralizado de materiales para el sistema de carreteras procedurales.
## Todos los materiales son StandardMaterial3D compartidos en memoria (batching GPU)
## con colores base calibrados y mapeo UV métrico listo para recibir texturas en el futuro.

static var _materials: Dictionary = {}

const KEY_ASPHALT := "asphalt"
const KEY_SIDEWALK := "sidewalk"
const KEY_CURB := "curb"
const KEY_YELLOW_LINE := "yellow_line"
const KEY_WHITE_LINE := "white_line"


static func get_material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match key:
		KEY_ASPHALT:
			# Asfalto oscuro y rugoso
			mat.albedo_color = Color(0.11, 0.11, 0.13, 1.0)
			mat.roughness = 0.90
			mat.metallic = 0.02
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		KEY_SIDEWALK:
			# Concreto de acera / banqueta urbano calibrado, limpio y claro
			mat.albedo_color = Color(0.78, 0.77, 0.75, 1.0)
			mat.roughness = 0.82
			mat.metallic = 0.0
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		KEY_CURB:
			# Guarnición / bordillo de piedra o concreto claro destacado
			mat.albedo_color = Color(0.88, 0.88, 0.86, 1.0)
			mat.roughness = 0.70
			mat.metallic = 0.0
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		KEY_YELLOW_LINE:
			# Pintura vial amarilla reflectante
			mat.albedo_color = Color(0.941, 0.733, 0.082, 1.0) # #f0bb15
			mat.roughness = 0.45
			mat.metallic = 0.0
		KEY_WHITE_LINE:
			# Pintura vial blanca de carril
			mat.albedo_color = Color(0.945, 0.961, 0.976, 1.0) # #f1f5f9
			mat.roughness = 0.45
			mat.metallic = 0.0
		_:
			mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)

	_materials[key] = mat
	return mat


static func get_all_material_keys() -> Array[String]:
	return [KEY_ASPHALT, KEY_SIDEWALK, KEY_CURB, KEY_YELLOW_LINE, KEY_WHITE_LINE]


static func clear_cache() -> void:
	_materials.clear()
