class_name WallDecalSystem
extends RefCounted

## Sistema Centralizado y Extensible de Calcomanías de Pared con GPU Instancing
## Agrupa todos los desgastes, grafitis, humedades, grietas y letreros en un
## único MultiMeshInstance3D usando Texture2DArray (1 solo Draw Call por casa o escena).

const SHADER_PATH: String = "res://assets/building/wall_decal_multimesh.gdshader"

## Resolución estándar para cada capa del Texture2DArray (potencia de 2 para mipmapping óptimo)
const LAYER_RESOLUTION: int = 512

## Registros de texturas por defecto en el proyecto
const DEFAULT_DECALS: Dictionary = {
	"desgaste": [
		"res://assets/textures/house/pared_desgastada2.png",
		"res://assets/textures/house/pared_desgastada3.png",
		"res://assets/textures/house/pared_desgastada4.png",
		"res://assets/textures/house/pared_desgastada5.png",
		"res://assets/textures/house/pared_desgastada6.png",
		"res://assets/textures/house/pared_desgastada7.png",
		"res://assets/textures/house/pintura_desgastada.png"
	],
	"graffiti_large": [
		"res://assets/textures/house/grafiti.png",
		"res://assets/textures/house/grafiti2.png",
		"res://assets/textures/house/grafiti3.png",
		"res://assets/textures/house/grafiti4.png",
		"res://assets/textures/house/grafiti5.png"
	],
	"graffiti_small": [
		"res://assets/textures/house/grafiti_peque.png",
		"res://assets/textures/house/grafiti_peque2.png",
		"res://assets/textures/house/grafiti_peque3.png"
	],
	"humedad": [
		"res://assets/textures/house/pared_humeda.png",
		"res://assets/textures/house/pared_humeda2.png",
		"res://assets/textures/house/pared_humeda3.png",
		"res://assets/textures/house/pared_humeda4.png",
		"res://assets/textures/house/pared_humeda5.png"
	],
	"grietas": [
		"res://assets/textures/house/pared_rajada.png",
		"res://assets/textures/house/pared_rajada2.png",
		"res://assets/textures/house/pared_rajada3.png",
		"res://assets/textures/house/pared_rajada4.png"
	]
}

## Estructura de almacenamiento en memoria
static var _registered_paths: Array[String] = []
static var _category_layers: Dictionary = {} # String (categoría) -> Array[int] (índices de capa)
static var _texture_array: Texture2DArray = null
static var _shared_material: ShaderMaterial = null
static var _shared_quad: QuadMesh = null
static var _is_initialized: bool = false


## Inicializa el sistema y construye el Texture2DArray si no está listo
static func ensure_initialized() -> void:
	if _is_initialized and _texture_array != null:
		return
	
	_registered_paths.clear()
	_category_layers.clear()

	# Cargar todas las categorías por defecto
	for cat in DEFAULT_DECALS:
		var paths: Array = DEFAULT_DECALS[cat]
		for p in paths:
			register_decal(cat, p, false)

	_build_texture_array_and_material()
	_is_initialized = true


## Registra una nueva imagen de calcomanía en el sistema para cualquier categoría futura
static func register_decal(category: String, path_or_image: Variant, auto_rebuild: bool = true) -> int:
	var path_str: String = ""
	if path_or_image is String:
		path_str = path_or_image
	else:
		path_str = "runtime_image_%d" % _registered_paths.size()

	var layer_idx: int = _registered_paths.find(path_str)
	if layer_idx == -1:
		layer_idx = _registered_paths.size()
		_registered_paths.append(path_str)

	if not _category_layers.has(category):
		_category_layers[category] = []
	
	var layers: Array = _category_layers[category]
	if not layers.has(layer_idx):
		layers.append(layer_idx)

	if auto_rebuild and _is_initialized:
		_build_texture_array_and_material()

	return layer_idx


## Escanea una carpeta y registra automáticamente todas las imágenes .png que contenga
static func register_folder(category: String, folder_path: String) -> int:
	var count: int = 0
	var dir := DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				var full_path = folder_path.path_join(file_name)
				register_decal(category, full_path, false)
				count += 1
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if count > 0:
		_build_texture_array_and_material()
	return count


## Obtiene el índice de capa (layer) en Texture2DArray para una categoría y estilo
static func get_layer_index(category: String, style_id: int, is_small: bool = false) -> int:
	ensure_initialized()

	var cat_key := category
	if category == "graffiti":
		cat_key = "graffiti_small" if is_small else "graffiti_large"

	if _category_layers.has(cat_key):
		var layers: Array = _category_layers[cat_key]
		if not layers.is_empty():
			return layers[style_id % layers.size()]

	# Fallback a la primera capa si no se encuentra
	return 0


## Retorna el Material compartido configurado con el Texture2DArray
static func get_material() -> ShaderMaterial:
	ensure_initialized()
	return _shared_material


## Retorna la malla unitaria compartida (QuadMesh 1x1)
static func get_mesh() -> QuadMesh:
	if _shared_quad == null:
		_shared_quad = QuadMesh.new()
		_shared_quad.size = Vector2(1.0, 1.0)
	return _shared_quad


## Construye un MultiMeshInstance3D optimizado con todos los detalles de una casa
static func create_house_decals_multimesh(wall_details: Array) -> MultiMeshInstance3D:
	if wall_details.is_empty():
		return null

	ensure_initialized()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = get_mesh()
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

		var layer_id := get_layer_index(category, style_id, is_small)

		# Construir la orientación espacial del plano hacia d_norm
		var rot_y: float = atan2(d_norm.x, d_norm.z)
		var basis := Basis(Vector3.UP, rot_y)

		# Aplicar inclinación tilt si aplica (alrededor del eje normal local)
		if absf(tilt) > 0.001:
			basis = basis.rotated(basis.z.normalized(), tilt)

		# Escalar el plano unitario (1x1) a las dimensiones reales (d_size.x, d_size.y)
		basis = basis.scaled(Vector3(d_size.x, d_size.y, 1.0))

		var xform := Transform3D(basis, d_pos)
		mm.set_instance_transform(i, xform)

		# Pasar los atributos de renderizado a través de COLOR:
		# COLOR.r: layer_id / 255.0
		# COLOR.g: flip_h (1.0 o 0.0)
		# COLOR.b: flip_v (1.0 o 0.0)
		# COLOR.a: 1.0 (opacidad total)
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
	inst.material_override = get_material()
	return inst


## Compila internamente el Texture2DArray a partir de todas las texturas registradas
static func _build_texture_array_and_material() -> void:
	if _registered_paths.is_empty():
		return

	var images: Array[Image] = []
	for path in _registered_paths:
		var img: Image = null
		var gpath = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(gpath):
			img = Image.load_from_file(gpath)
		elif ResourceLoader.exists(path):
			var res = load(path)
			if res is Texture2D:
				img = res.get_image()

		if img and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			img.resize(LAYER_RESOLUTION, LAYER_RESOLUTION, Image.INTERPOLATE_LANCZOS)
			img.generate_mipmaps()
		else:
			# Placeholder transparente si no se pudo cargar la imagen
			img = Image.create(LAYER_RESOLUTION, LAYER_RESOLUTION, true, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))

		images.append(img)

	var tex_arr := Texture2DArray.new()
	var err := tex_arr.create_from_images(images)
	if err != OK:
		printerr("[WallDecalSystem] ERROR al crear Texture2DArray: ", err)
		return

	_texture_array = tex_arr

	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		printerr("[WallDecalSystem] ERROR: No se encontró el shader en: ", SHADER_PATH)
		return

	_shared_material = ShaderMaterial.new()
	_shared_material.shader = shader
	_shared_material.set_shader_parameter("decal_array", _texture_array)
	_shared_material.set_shader_parameter("alpha_threshold", 0.05)
	_shared_material.set_shader_parameter("roughness_val", 0.95)

	print("[WallDecalSystem] ✓ Texture2DArray inicializado con éxito: %d capas (%dx%d)." % [
		_texture_array.get_layers(),
		_texture_array.get_width(),
		_texture_array.get_height()
	])
