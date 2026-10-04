class_name CityTextureManager
extends RefCounted

## Gestor Centralizado e Inteligente de Texturas, Atlas y GPU Instancing
## Administra de forma unificada:
## 1. Fachadas y paredes exteriores (Texture2DArray con repeat_enable y triplanar)
## 2. Props y Calcomanías (Texture2DArray con alfa: medidores CFE, grafitis, desgastes, humedad)
##
## Resiliencia total:
## - Registro por Clave Semántica (nombres clave en lugar de IDs fijos numéricos).
## - Si un archivo se elimina del disco, el sistema re-indexa automáticamente sin descuadrar
##   las demás texturas y asigna un fallback seguro sin crashear.
## - Si se agrega una nueva imagen, se normaliza automáticamente a potencia de 2 y se integra al vuelo.

const WALL_SHADER_PATH: String = "res://assets/building/wall_exterior_triplanar.gdshader"
const DECAL_SHADER_PATH: String = "res://assets/building/wall_decal_multimesh.gdshader"
const METER_TEXTURE_PATH: String = "res://assets/textures/house/medidor_cfe.png"

const TEXTURE_RESOLUTION: int = 512

# =========================================================================
# 1. CATÁLOGO POR DEFECTO DE FACHADAS Y PAREDES EXTERIORES
# =========================================================================
const DEFAULT_WALL_TEXTURES: Dictionary = {
	"amarilla": "res://assets/textures/house/pared_amarilla_ext_seamless.png",
	"azul": "res://assets/textures/house/pared_azul_ext_seamless.png",
	"blanca": "res://assets/textures/house/pared_blanca_ext_seamless.png",
	"cremita": "res://assets/textures/house/pared_cremita_ext_seamless.png",
	"gris": "res://assets/textures/house/pared_gris_ext_seamless.png"
}

# =========================================================================
# 2. CATÁLOGO POR DEFECTO DE PROPS Y CALCOMANÍAS
# =========================================================================
const DEFAULT_DECAL_TEXTURES: Dictionary = {
	"props": {
		"medidor_cfe": "res://assets/textures/house/medidor_cfe.png"
	},
	"desgaste": {
		"desgaste_02": "res://assets/textures/house/pared_desgastada2.png",
		"desgaste_03": "res://assets/textures/house/pared_desgastada3.png",
		"desgaste_04": "res://assets/textures/house/pared_desgastada4.png",
		"desgaste_05": "res://assets/textures/house/pared_desgastada5.png",
		"desgaste_06": "res://assets/textures/house/pared_desgastada6.png",
		"desgaste_07": "res://assets/textures/house/pared_desgastada7.png",
		"desgaste_pintura": "res://assets/textures/house/pintura_desgastada.png"
	},
	"graffiti_large": {
		"grafiti_01": "res://assets/textures/house/grafiti.png",
		"grafiti_02": "res://assets/textures/house/grafiti2.png",
		"grafiti_03": "res://assets/textures/house/grafiti3.png",
		"grafiti_04": "res://assets/textures/house/grafiti4.png",
		"grafiti_05": "res://assets/textures/house/grafiti5.png"
	},
	"graffiti_small": {
		"grafiti_p01": "res://assets/textures/house/grafiti_peque.png",
		"grafiti_p02": "res://assets/textures/house/grafiti_peque2.png",
		"grafiti_p03": "res://assets/textures/house/grafiti_peque3.png"
	},
	"humedad": {
		"humedad_01": "res://assets/textures/house/pared_humeda.png",
		"humedad_02": "res://assets/textures/house/pared_humeda2.png",
		"humedad_03": "res://assets/textures/house/pared_humeda3.png",
		"humedad_04": "res://assets/textures/house/pared_humeda4.png",
		"humedad_05": "res://assets/textures/house/pared_humeda5.png"
	},
	"grietas": {
		"grieta_01": "res://assets/textures/house/pared_rajada.png",
		"grieta_02": "res://assets/textures/house/pared_rajada2.png",
		"grieta_03": "res://assets/textures/house/pared_rajada3.png",
		"grieta_04": "res://assets/textures/house/pared_rajada4.png"
	}
}

# =========================================================================
# ESTADO INTERNO Y CACHÉ
# =========================================================================
static var _wall_entries: Dictionary = {} # key -> path_or_image
static var _wall_keys: Array[String] = []
static var _wall_layer_map: Dictionary = {} # key -> layer_index
static var _wall_texture_array: Texture2DArray = null
static var _wall_shared_material: ShaderMaterial = null

static var _decal_entries: Dictionary = {} # category -> { key -> path_or_image }
static var _decal_flat_keys: Array[String] = [] # list of all keys in layer order
static var _decal_layer_map: Dictionary = {} # key -> layer_index
static var _decal_category_layers: Dictionary = {} # category -> Array[int]
static var _decal_texture_array: Texture2DArray = null
static var _decal_shared_material: ShaderMaterial = null
static var _meter_shared_material: StandardMaterial3D = null

static var _is_initialized: bool = false


## Inicialización global y construcción de los Texture2DArray optimizados
static func ensure_initialized() -> void:
	if _is_initialized and _wall_texture_array != null and _decal_texture_array != null:
		return

	_init_walls()
	_init_decals()
	_init_meter_material()
	_is_initialized = true


# =========================================================================
# GESTIÓN INTELIGENTE DE PAREDES Y FACHADAS EXTERIORES
# =========================================================================
static func _init_walls() -> void:
	_wall_entries.clear()
	for k in DEFAULT_WALL_TEXTURES:
		_wall_entries[k] = DEFAULT_WALL_TEXTURES[k]
	_rebuild_walls_array()


## Registra o actualiza una textura de pared exterior con clave semántica
static func register_wall_texture(key: String, path_or_image: Variant, auto_rebuild: bool = true) -> void:
	_wall_entries[key] = path_or_image
	if auto_rebuild:
		_rebuild_walls_array()


## Obtiene la lista ordenada de todas las claves de pared válidas
static func get_all_wall_keys() -> Array[String]:
	ensure_initialized()
	return _wall_keys


## Obtiene el índice de capa en Texture2DArray para una clave de pared.
## Si la clave fue eliminada o no existe, retorna 0 (fallback seguro) sin crashear.
static func get_wall_layer(key: String) -> int:
	ensure_initialized()
	if _wall_layer_map.has(key):
		return _wall_layer_map[key]
	
	if not _wall_keys.is_empty():
		return 0 # Fallback seguro a la primera pared válida
	return 0


## Retorna el Material Compartido para paredes (1 solo material para toda la ciudad)
static func get_walls_shared_material() -> ShaderMaterial:
	ensure_initialized()
	return _wall_shared_material


static func _rebuild_walls_array() -> void:
	_wall_keys.clear()
	_wall_layer_map.clear()

	var images: Array[Image] = []
	for key in _wall_entries:
		var path_val = _wall_entries[key]
		var img := _load_and_normalize_image(path_val)
		if img != null:
			var layer_idx := images.size()
			images.append(img)
			_wall_keys.append(key)
			_wall_layer_map[key] = layer_idx
		else:
			print("[CityTextureManager] Advertencia: Textura de pared '%s' (%s) no encontrada. Omitiendo." % [key, str(path_val)])

	if images.is_empty():
		var dummy := Image.create(TEXTURE_RESOLUTION, TEXTURE_RESOLUTION, true, Image.FORMAT_RGBA8)
		dummy.fill(Color(0.8, 0.8, 0.8, 1.0))
		images.append(dummy)
		_wall_keys.append("default")
		_wall_layer_map["default"] = 0

	var tex_arr := Texture2DArray.new()
	var err := tex_arr.create_from_images(images)
	if err != OK:
		printerr("[CityTextureManager] ERROR al crear Texture2DArray de paredes: ", err)
		return

	_wall_texture_array = tex_arr

	var shader := load(WALL_SHADER_PATH) as Shader
	if shader:
		_wall_shared_material = ShaderMaterial.new()
		_wall_shared_material.shader = shader
		_wall_shared_material.set_shader_parameter("wall_textures", _wall_texture_array)
		_wall_shared_material.set_shader_parameter("uv_scale", 0.35)
		_wall_shared_material.set_shader_parameter("sharpness", 3.0)
		_wall_shared_material.set_shader_parameter("roughness", 0.90)

	print("[CityTextureManager] ✓ Array de paredes compilado: %d capas (%s)." % [
		_wall_keys.size(),
		", ".join(_wall_keys)
	])


# =========================================================================
# GESTIÓN INTELIGENTE DE CALCOMANÍAS, PROPS Y MEDIDOR CFE
# =========================================================================
static func _init_decals() -> void:
	_decal_entries.clear()
	for cat in DEFAULT_DECAL_TEXTURES:
		_decal_entries[cat] = {}
		var cat_dict: Dictionary = DEFAULT_DECAL_TEXTURES[cat]
		for k in cat_dict:
			_decal_entries[cat][k] = cat_dict[k]
	_rebuild_decals_array()


## Registra una calcomanía o prop con clave semántica en una categoría
static func register_decal(category: String, key: String, path_or_image: Variant, auto_rebuild: bool = true) -> void:
	if not _decal_entries.has(category):
		_decal_entries[category] = {}
	_decal_entries[category][key] = path_or_image
	if auto_rebuild:
		_rebuild_decals_array()


## Registra automáticamente todos los archivos PNG de una carpeta en una categoría
static func register_decal_folder(category: String, folder_path: String) -> int:
	var count := 0
	var dir := DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				var key := file_name.get_basename()
				var full_path := folder_path.path_join(file_name)
				register_decal(category, key, full_path, false)
				count += 1
			file_name = dir.get_next()
		dir.list_dir_end()

	if count > 0:
		_rebuild_decals_array()
	return count


## Obtiene la capa en Texture2DArray a partir de una clave única
static func get_decal_layer_by_key(key: String) -> int:
	ensure_initialized()
	if _decal_layer_map.has(key):
		return _decal_layer_map[key]
	return 0


## Obtiene la capa en Texture2DArray para una categoría y estilo
static func get_decal_layer(category: String, style_id: int, is_small: bool = false) -> int:
	ensure_initialized()
	var cat_key := category
	if category == "graffiti":
		cat_key = "graffiti_small" if is_small else "graffiti_large"

	if _decal_category_layers.has(cat_key):
		var layers: Array = _decal_category_layers[cat_key]
		if not layers.is_empty():
			return layers[style_id % layers.size()]
	return 0


## Retorna el Material Compartido para MultiMesh de calcomanías
static func get_decals_shared_material() -> ShaderMaterial:
	ensure_initialized()
	return _decal_shared_material


## Retorna el Material Compartido para la carátula de los medidores de luz CFE
static func get_meter_material() -> StandardMaterial3D:
	ensure_initialized()
	return _meter_shared_material


static func _init_meter_material() -> void:
	if _meter_shared_material != null:
		return

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.18
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(METER_TEXTURE_PATH)
	var img: Image = null
	if FileAccess.file_exists(gpath):
		img = Image.load_from_file(gpath)
	elif ResourceLoader.exists(METER_TEXTURE_PATH):
		var res = load(METER_TEXTURE_PATH)
		if res is Texture2D:
			img = res.get_image()

	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)

	_meter_shared_material = mat


static func _rebuild_decals_array() -> void:
	_decal_flat_keys.clear()
	_decal_layer_map.clear()
	_decal_category_layers.clear()

	var images: Array[Image] = []

	for cat in _decal_entries:
		_decal_category_layers[cat] = []
		var cat_dict: Dictionary = _decal_entries[cat]

		for key in cat_dict:
			var path_val = cat_dict[key]
			var img := _load_and_normalize_image(path_val)
			if img != null:
				var layer_idx := images.size()
				images.append(img)
				_decal_flat_keys.append(key)
				_decal_layer_map[key] = layer_idx
				_decal_category_layers[cat].append(layer_idx)
			else:
				print("[CityTextureManager] Advertencia: Calcomanía '%s/%s' (%s) no encontrada. Omitiendo." % [cat, key, str(path_val)])

	if images.is_empty():
		var dummy := Image.create(TEXTURE_RESOLUTION, TEXTURE_RESOLUTION, true, Image.FORMAT_RGBA8)
		dummy.fill(Color(0, 0, 0, 0))
		images.append(dummy)
		_decal_flat_keys.append("default")
		_decal_layer_map["default"] = 0

	var tex_arr := Texture2DArray.new()
	var err := tex_arr.create_from_images(images)
	if err != OK:
		printerr("[CityTextureManager] ERROR al crear Texture2DArray de calcomanías: ", err)
		return

	_decal_texture_array = tex_arr

	var shader := load(DECAL_SHADER_PATH) as Shader
	if shader:
		_decal_shared_material = ShaderMaterial.new()
		_decal_shared_material.shader = shader
		_decal_shared_material.set_shader_parameter("decal_array", _decal_texture_array)
		_decal_shared_material.set_shader_parameter("alpha_threshold", 0.05)
		_decal_shared_material.set_shader_parameter("roughness_val", 0.95)

	print("[CityTextureManager] ✓ Array de calcomanías compilado: %d capas en %d categorías." % [
		images.size(),
		_decal_category_layers.size()
	])


## Construye un MultiMeshInstance3D optimizado con todos los detalles de una casa
static func create_house_decals_multimesh(wall_details: Array) -> MultiMeshInstance3D:
	if wall_details.is_empty():
		return null

	ensure_initialized()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = wall_details.size()

	for i in range(wall_details.size()):
		var d_dict: Dictionary = wall_details[i]
		var category: String = d_dict.get("category", "")
		var d_pos: Vector3 = d_dict.get("position", Vector3.ZERO)
		var d_norm: Vector3 = d_dict.get("normal", Vector3.FORWARD)
		var d_size: Vector2 = d_dict.get("size", Vector2(1.2, 1.2))
		var style_id: int = d_dict.get("style_id", 0)
		var tilt: float = d_dict.get("tilt", 0.0)
		var flip_h: bool = d_dict.get("flip_h", false)
		var flip_v: bool = d_dict.get("flip_v", false)
		var is_small: bool = d_dict.get("is_small", false)

		var layer_id := get_decal_layer(category, style_id, is_small)

		# Orientar hacia d_norm
		var rot_y: float = atan2(d_norm.x, d_norm.z)
		var basis := Basis(Vector3.UP, rot_y)

		# Tilt local
		if absf(tilt) > 0.001:
			basis = basis.rotated(basis.z.normalized(), tilt)

		# Escala física del plano unitario
		basis = basis.scaled(Vector3(d_size.x, d_size.y, 1.0))

		mm.set_instance_transform(i, Transform3D(basis, d_pos))

		var color := Color(
			float(layer_id) / 255.0,
			1.0 if flip_h else 0.0,
			1.0 if flip_v else 0.0,
			1.0
		)
		mm.set_instance_color(i, color)

	var inst := MultiMeshInstance3D.new()
	inst.name = "WallDecalsMultiMesh"
	inst.multimesh = mm
	inst.material_override = get_decals_shared_material()
	return inst


## Utilidad interna para cargar, normalizar y generar mipmaps de cualquier imagen
static func _load_and_normalize_image(path_or_image: Variant) -> Image:
	var img: Image = null

	if path_or_image is Image:
		img = path_or_image.duplicate()
	elif path_or_image is String:
		var path_str: String = path_or_image
		var gpath := ProjectSettings.globalize_path(path_str)
		if FileAccess.file_exists(gpath):
			img = Image.load_from_file(gpath)
		elif ResourceLoader.exists(path_str):
			var res = load(path_str)
			if res is Texture2D:
				img = res.get_image()

	if img and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != TEXTURE_RESOLUTION or img.get_height() != TEXTURE_RESOLUTION:
			img.resize(TEXTURE_RESOLUTION, TEXTURE_RESOLUTION, Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		return img

	return null
