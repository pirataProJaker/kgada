class_name PlanarPropsManager
extends RefCounted

## Gestor Universal y Extensible de Planos 2D con Atlas Inteligente y GPU Instancing (Play Sector X)
## Administra cualquier objeto plano 2D (alfombras en suelo, pósters en pared, cuadros, felpudos, letreros):
## 1. Carga configuraciones desde JSON (content/props/planar_props.json).
## 2. Auto-discovery de imágenes en res://assets/textures/planar_props y user://custom_planar_props (Mods de usuarios).
## 3. Compila dinámicamente un Texture2DArray optimizado (Atlas Inteligente sin distorsión).
## 4. Provee consultas semánticas por tags ("bedroom", "living_room", etc.) y selección procedural determinista.

const CONFIG_PATH: String = "res://content/props/planar_props.json"
const SHADER_PATH: String = "res://assets/building/planar_props_multimesh.gdshader"
const TEXTURE_RESOLUTION: int = 512

const ASSETS_FOLDERS: Array[String] = [
	"res://assets/textures/furniture/rugs",
	"res://assets/textures/planar_props"
]
const USER_MODS_FOLDER: String = "user://custom_planar_props"

# Diccionario maestro de props: id -> Dictionary
static var _props: Dictionary = {}
# Lista de IDs ordenadas
static var _keys: Array[String] = []
# Mapeo id -> layer_index en Texture2DArray
static var _layer_map: Dictionary = {}

static var _texture_array: Texture2DArray = null
static var _shared_material: ShaderMaterial = null
static var _is_initialized: bool = false


## Inicializa el gestor cargando el JSON, escaneando carpetas y compilando el Texture2DArray
static func ensure_initialized() -> void:
	if _is_initialized and _texture_array != null and _shared_material != null:
		return

	_props.clear()
	_keys.clear()
	_layer_map.clear()

	# 1. Cargar catálogo formal desde JSON
	_load_config_json()

	# 2. Escanear carpetas de assets para auto-discovery de imágenes nuevas sin declarar
	for folder in ASSETS_FOLDERS:
		_scan_folder_for_props(folder, "floor")

	# 3. Escanear carpeta de usuario para soporte de mods / imágenes personalizadas
	_scan_folder_for_props(USER_MODS_FOLDER, "floor")

	# 4. Compilar Texture2DArray dinámico y material compartido
	_rebuild_texture_array()
	_is_initialized = true


## Carga y parsea el archivo JSON central
static func _load_config_json() -> void:
	var gpath := ProjectSettings.globalize_path(CONFIG_PATH)
	var json_str := ""
	if FileAccess.file_exists(gpath):
		var file := FileAccess.open(gpath, FileAccess.READ)
		if file:
			json_str = file.get_as_text()
	elif ResourceLoader.exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			json_str = file.get_as_text()

	if json_str.is_empty():
		print("[PlanarPropsManager] Nota: No se encontró %s. Se usarán imágenes descubiertas." % CONFIG_PATH)
		return

	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		printerr("[PlanarPropsManager] ERROR: El formato de %s es inválido." % CONFIG_PATH)
		return

	var props_dict: Dictionary = parsed.get("props", {})
	for id in props_dict:
		var item: Dictionary = props_dict[id]
		_props[id] = _sanitize_prop_entry(id, item)

	print("[PlanarPropsManager] ✓ Cargadas %d definiciones desde %s." % [_props.size(), CONFIG_PATH])


## Escanea una carpeta y registra cualquier imagen PNG, JPG o WEBP no registrada
static func _scan_folder_for_props(folder_path: String, default_type: String = "floor") -> void:
	var gpath := ProjectSettings.globalize_path(folder_path)
	if not DirAccess.dir_exists_absolute(gpath):
		return

	var dir := DirAccess.open(gpath)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".webp"):
				var id := file_name.get_basename()
				if not _props.has(id):
					var tex_path := folder_path.path_join(file_name)
					# Auto-calcular aspecto para no deformar
					var def_size := Vector2(1.75, 1.20)
					_props[id] = {
						"name": id.capitalize().replace("_", " "),
						"type": default_type,
						"texture": tex_path,
						"size": def_size,
						"roughness": 0.90,
						"metallic": 0.0,
						"surface_offset": 0.005,
						"tags": [default_type, "auto_discovered"]
					}
		file_name = dir.get_next()
	dir.list_dir_end()


## Normaliza y valida una entrada de prop
static func _sanitize_prop_entry(id: String, raw: Dictionary) -> Dictionary:
	var p_size: Vector2 = Vector2(1.75, 1.20)
	var raw_size = raw.get("size", [1.75, 1.20])
	if raw_size is Array and raw_size.size() >= 2:
		p_size = Vector2(float(raw_size[0]), float(raw_size[1]))
	elif raw_size is Vector2:
		p_size = raw_size

	var tags_arr: Array = []
	for t in raw.get("tags", []):
		tags_arr.append(str(t).to_lower())

	return {
		"id": id,
		"name": str(raw.get("name", id.capitalize())),
		"type": str(raw.get("type", "floor")).to_lower(),
		"texture": str(raw.get("texture", "")),
		"size": p_size,
		"roughness": float(raw.get("roughness", 0.90)),
		"metallic": float(raw.get("metallic", 0.0)),
		"surface_offset": float(raw.get("surface_offset", 0.005)),
		"tags": tags_arr
	}


## Compila el Texture2DArray universal a partir de todas las texturas registradas
static func _rebuild_texture_array() -> void:
	_keys.clear()
	_layer_map.clear()

	var images: Array[Image] = []

	for id in _props:
		var prop: Dictionary = _props[id]
		var tex_path: String = prop["texture"]
		var img := _load_image(tex_path)

		if img != null:
			var layer_idx := images.size()
			images.append(img)
			_keys.append(id)
			_layer_map[id] = layer_idx
		else:
			print("[PlanarPropsManager] Advertencia: No se pudo cargar textura para prop '%s' (%s)." % [id, tex_path])

	# Capa dummy de respaldo si no hay ninguna
	if images.is_empty():
		var dummy := Image.create(TEXTURE_RESOLUTION, TEXTURE_RESOLUTION, true, Image.FORMAT_RGBA8)
		dummy.fill(Color(0.8, 0.75, 0.7, 1.0))
		dummy.generate_mipmaps()
		images.append(dummy)
		_keys.append("default")
		_layer_map["default"] = 0

	var tex_arr := Texture2DArray.new()
	var err := tex_arr.create_from_images(images)
	if err != OK:
		printerr("[PlanarPropsManager] ERROR al compilar Texture2DArray de Planos 2D: ", err)
		return

	_texture_array = tex_arr

	# Cargar o crear el shader universal
	var shader := load(SHADER_PATH) as Shader
	if shader:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = shader
		_shared_material.set_shader_parameter("planar_textures", _texture_array)
		_shared_material.set_shader_parameter("default_roughness", 0.90)
		_shared_material.set_shader_parameter("default_metallic", 0.0)

	print("[PlanarPropsManager] ✓ Atlas Inteligente de Planos 2D compilado: %d capas (%s)." % [
		_keys.size(),
		", ".join(_keys.slice(0, mini(_keys.size(), 8))) + ("..." if _keys.size() > 8 else "")
	])


## Carga y normaliza una imagen individual para ser capa del array
static func _load_image(path_str: String) -> Image:
	var img: Image = null
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


# =========================================================================
# REGISTRO DINÁMICO Y CONSULTAS SEMÁNTICAS
# =========================================================================

## Registra dinámicamente un prop plano en tiempo de ejecución (ej. importado por usuario o mod)
static func register_prop(id: String, data: Dictionary, auto_rebuild: bool = true) -> void:
	ensure_initialized()
	_props[id] = _sanitize_prop_entry(id, data)
	if auto_rebuild:
		_rebuild_texture_array()

## Retorna los datos completos de un prop por ID
static func get_prop(id: String) -> Dictionary:
	ensure_initialized()
	if _props.has(id):
		return _props[id]
	return {}


## Retorna el índice de capa en Texture2DArray para un prop
static func get_layer_index(id: String) -> int:
	ensure_initialized()
	if _layer_map.has(id):
		return _layer_map[id]
	return 0


## Retorna el Material Shader compartido para MultiMesh de planos 2D
static func get_material() -> ShaderMaterial:
	ensure_initialized()
	return _shared_material


## Retorna la lista de todas las claves registradas
static func get_all_keys() -> Array[String]:
	ensure_initialized()
	return _keys


## Retorna los IDs que coinciden con un tipo de superficie ("floor", "wall", etc.) y etiquetas opcionales
static func get_props_by_filter(surface_type: String = "", required_tags: Array[String] = []) -> Array[String]:
	ensure_initialized()
	var matches: Array[String] = []

	var s_type := surface_type.to_lower()
	var req_lower: Array[String] = []
	for t in required_tags:
		req_lower.append(t.to_lower())

	for id in _keys:
		var prop: Dictionary = _props[id]
		if not s_type.is_empty() and prop.get("type", "") != s_type:
			continue

		if not req_lower.is_empty():
			var p_tags: Array = prop.get("tags", [])
			var all_tags_match := true
			for req_tag in req_lower:
				if not p_tags.has(req_tag):
					all_tags_match = false
					break
			if not all_tags_match:
				continue

		matches.append(id)

	return matches


## Selecciona proceduralmente un ID aleatorio determinista según tipo y tags
static func get_random_prop_id(surface_type: String = "floor", required_tags: Array[String] = [], seed_num: int = 0) -> String:
	var candidates := get_props_by_filter(surface_type, required_tags)
	if candidates.is_empty():
		# Fallback a cualquier prop del mismo surface_type
		candidates = get_props_by_filter(surface_type, [])
	if candidates.is_empty():
		return _keys[0] if not _keys.is_empty() else ""

	var idx := absi(seed_num) % candidates.size()
	return candidates[idx]
