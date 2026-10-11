class_name FurnitureTextureManager
extends RefCounted

## Gestor Centralizado e Inteligente de Texturas y GPU Instancing para Mobiliario (Play Sector X)
## Administra de forma unificada:
## 1. Texture2DArray de acabados de madera refinada (Roble, Nogal, Caoba, Pino)
## 2. Texturas de electrodomésticos y muebles (Refrigerador, Estufa, Microondas, Gabinetes, Tostadora, Lavadora, Secadora, Sillón, etc.)
## 3. Material Shader compartido con GPU Instancing para miles de muebles en 1 solo draw call por tipo.
## 4. Registro resiliente por clave semántica con fallback automático sin crasheos.

const FURNITURE_SHADER_PATH: String = "res://assets/building/furniture_multimesh.gdshader"
const TEXTURE_RESOLUTION: int = 1024
const PlanarPropsManagerScript = preload("res://world/furniture/planar_props_manager.gd")

const DEFAULT_WOOD_TEXTURES: Dictionary = {
	"roble_claro": "res://assets/textures/house/pared_madera.png",
	"nogal_oscuro": "res://assets/textures/house/pared_madera2.png"
}

const DEFAULT_APPLIANCE_TEXTURES: Dictionary = {
	"refrigerador": "res://assets/textures/furniture/refrigerador.png",
	"estufa": "res://assets/textures/furniture/estufa.png",
	"microondas": "res://assets/textures/furniture/microondas.png",
	"cabinets": "res://assets/textures/furniture/cabinets.png",
	"toaster": "res://assets/textures/furniture/toaster.png",
	"coffee_table": "res://assets/textures/furniture/coffee_table.png",
	"washer": "res://assets/textures/furniture/washer.png",
	"dryer": "res://assets/textures/furniture/dryer.png",
	"sofa_leather": "res://assets/textures/furniture/sofa_leather.png",
	"props_atlas": "res://assets/textures/furniture/furniture_props_atlas.png",
	"bed_linens_atlas": "res://assets/textures/furniture/bed_linens_master_atlas.png",
	"commercial_shelf": "res://assets/textures/furniture/commercial_shelf.png",
	"commercial_cooler": "res://assets/textures/furniture/commercial_cooler.png",
	"medidor_cfe": "res://assets/textures/house/medidor_cfe.png"
}

const DEFAULT_OFFICE_TEXTURES: Dictionary = {
	"chair01": "res://assets/textures/office pack/chair01_ALBEDO_256x256.png",
	"chair02": "res://assets/textures/office pack/chair02_ALBEDO_256x256.png",
	"cupboard01": "res://assets/textures/office pack/cupboard01_ALBEDO256x256.png",
	"cupboard02": "res://assets/textures/office pack/cupboard02_ALBEDO256x256.png",
	"desk01": "res://assets/textures/office pack/desk01_ALBEDO_256x256.png",
	"desk02": "res://assets/textures/office pack/desk02_ALBEDO_256x256.png",
	"desk03": "res://assets/textures/office pack/desk03_ALBEDO_256x256.png",
	"desk04": "res://assets/textures/office pack/desk04_ALBEDO_256x256.png",
	"file_cabinet": "res://assets/textures/office pack/file_cabinet_ALBEDO_256x256.png"
}

# Catálogo semántico oficial de Sábanas (16 patrones en filas 0 y 1 del atlas)
const SHEET_NAMES: Array[String] = [
	"Sábana Blanco Puro",
	"Sábana Crema Lino",
	"Sábana Azul Cielo",
	"Sábana Gris Grafito",
	"Sábana Verde Salvia",
	"Sábana Rosa Palo",
	"Sábana Azul Marino",
	"Sábana Carbón Oscuro",
	"Sábana Rayas Finas Azul",
	"Sábana Algodón Natural",
	"Sábana Denim Lavado",
	"Sábana Trigo Tostado",
	"Sábana Lavanda Suave",
	"Sábana Cuadrícula Gris",
	"Sábana Rayas Menta",
	"Sábana Rayas Beige"
]

# Catálogo semántico oficial de Cobijas y Cobertores (24 patrones en filas 2, 3 y 4 del atlas)
const BLANKET_NAMES: Array[String] = [
	"Cobija Granate Floral",
	"Cobija Tartán Otoño",
	"Cobija Franjas Bosque",
	"Cobija Copos Invernales",
	"Cobija Cuadros Madera",
	"Cobija Tartán Carbón",
	"Cobija Hojas Otoñales",
	"Cobija Noche Estrellada",
	"Cobija Rosas Vintage",
	"Cobija Tartán Escocés Verde",
	"Cobija Olas Añil",
	"Cobija Franjas Étnicas",
	"Cobertor Lobo San Marcos",
	"Cobija Greca Escandinava",
	"Cobertor Leopardo Salvaje",
	"Cobija Tradicional Flor Roja",
	"Cobija Gris Franjas Blancas",
	"Cobija Flores Púrpura",
	"Cobija Rústica Hojas",
	"Cobija Cuadros Vichy Azul",
	"Cobija Rombo Azteca Terracota",
	"Cobija Franjas Verde Pino",
	"Cobija Azul Flor Silvestre",
	"Cobija Navideña Nochebuena"
]

# Acabados predefinidos enum-like para fácil uso en GDScript
enum WoodFinish {
	ROBLE_CLARO = 0,
	NOGAL_OSCURO = 1,
	CAOBA_ROJIZA = 2,
	PINO_NATURAL = 3
}

static var _entries: Dictionary = {} # key -> path_or_image
static var _keys: Array[String] = []
static var _layer_map: Dictionary = {} # key -> layer_index
static var _texture_array: Texture2DArray = null
static var _shared_material: ShaderMaterial = null
static var _rugs_material: ShaderMaterial = null

static var _is_initialized: bool = false


## Inicializa el gestor y compila el Texture2DArray universal
static func ensure_initialized() -> void:
	if _is_initialized and _texture_array != null and _shared_material != null:
		return

	_entries.clear()

	# 1. Registrar maderas por defecto
	for k in DEFAULT_WOOD_TEXTURES:
		_entries[k] = DEFAULT_WOOD_TEXTURES[k]

	# 2. Generar acabados de madera derivados (Caoba y Pino)
	_add_derived_wood_finishes()

	# 3. Registrar electrodomésticos y mobiliario por defecto
	for k in DEFAULT_APPLIANCE_TEXTURES:
		_entries[k] = DEFAULT_APPLIANCE_TEXTURES[k]

	# 4. Registrar mobiliario de oficina (Office Pack)
	for k in DEFAULT_OFFICE_TEXTURES:
		_entries[k] = DEFAULT_OFFICE_TEXTURES[k]

	# 5. Auto-descubrimiento dinámico inteligente en carpetas de assets
	# Detecta automáticamente cualquier nuevo .png, .jpg, .webp agregado a las carpetas
	_scan_folder_for_textures("res://assets/textures/furniture/")
	_scan_folder_for_textures("res://assets/textures/house/")
	_scan_folder_for_textures("res://assets/textures/office pack/")
	_scan_folder_for_textures("res://assets/textures/furniture 2.0/")

	_rebuild_array()
	_is_initialized = true


## Agrega acabados de caoba y pino natural derivados con gradación tonal
static func _add_derived_wood_finishes() -> void:
	# Caoba rojiza derivada de nogal oscuro con tinte cálido
	var base_dark := _load_and_normalize_image(DEFAULT_WOOD_TEXTURES["nogal_oscuro"])
	if base_dark:
		var caoba_img: Image = base_dark.duplicate()
		for y in range(caoba_img.get_height()):
			for x in range(caoba_img.get_width()):
				var px: Color = caoba_img.get_pixel(x, y)
				var r := clampf(px.r * 1.15 + 0.05, 0.0, 1.0)
				var g := clampf(px.g * 0.88, 0.0, 1.0)
				var b := clampf(px.b * 0.75, 0.0, 1.0)
				caoba_img.set_pixel(x, y, Color(r, g, b, 1.0))
		_entries["caoba_rojiza"] = caoba_img

	# Pino natural derivado de roble claro con tinte miel dorado
	var base_light := _load_and_normalize_image(DEFAULT_WOOD_TEXTURES["roble_claro"])
	if base_light:
		var pino_img: Image = base_light.duplicate()
		for y in range(pino_img.get_height()):
			for x in range(pino_img.get_width()):
				var px: Color = pino_img.get_pixel(x, y)
				var r := clampf(px.r * 1.08 + 0.06, 0.0, 1.0)
				var g := clampf(px.g * 1.02 + 0.03, 0.0, 1.0)
				var b := clampf(px.b * 0.78, 0.0, 1.0)
				pino_img.set_pixel(x, y, Color(r, g, b, 1.0))
		_entries["pino_natural"] = pino_img


## Registra o actualiza una textura semántica en el atlas inteligente
static func register_texture(key: String, path_or_image: Variant, auto_rebuild: bool = true) -> void:
	_entries[key] = path_or_image
	if auto_rebuild:
		_rebuild_array()


## Retorna la lista de todas las claves de texturas disponibles
static func get_all_keys() -> Array[String]:
	ensure_initialized()
	return _keys


## Obtiene el índice de capa para una clave semántica (e.g. "refrigerador", "roble_claro")
static func get_texture_layer(key: String) -> int:
	ensure_initialized()
	if _layer_map.has(key):
		return _layer_map[key]
	if key.begins_with("office_"):
		var sub := key.trim_prefix("office_")
		if _layer_map.has(sub):
			return _layer_map[sub]
	return 0


## Retrocompatibilidad: alias para maderas
static func get_wood_layer(key: String) -> int:
	return get_texture_layer(key)


## Obtiene el índice de capa para un enum de WoodFinish
static func get_wood_layer_by_finish(finish_id: int) -> int:
	ensure_initialized()
	match finish_id:
		WoodFinish.ROBLE_CLARO:
			return get_texture_layer("roble_claro")
		WoodFinish.NOGAL_OSCURO:
			return get_texture_layer("nogal_oscuro")
		WoodFinish.CAOBA_ROJIZA:
			return get_texture_layer("caoba_rojiza")
		WoodFinish.PINO_NATURAL:
			return get_texture_layer("pino_natural")
		_:
			if not _keys.is_empty():
				return finish_id % _keys.size()
			return 0


## Retorna el nombre semántico de un patrón de sábana (0 a 15)
static func get_sheet_name(pattern_id: int) -> String:
	if pattern_id >= 0 and pattern_id < SHEET_NAMES.size():
		return SHEET_NAMES[pattern_id]
	return "Sábana Desconocida"


## Retorna el nombre semántico de un patrón de cobija (0 a 23)
static func get_blanket_name(pattern_id: int) -> String:
	if pattern_id >= 0 and pattern_id < BLANKET_NAMES.size():
		return BLANKET_NAMES[pattern_id]
	return "Cobija Desconocida"


## Total de patrones de sábanas registrados
static func get_sheet_count() -> int:
	return SHEET_NAMES.size()


## Total de patrones de cobijas registrados
static func get_blanket_count() -> int:
	return BLANKET_NAMES.size()


## Retorna el Material Compartido para MultiMesh de mobiliario (1 solo material para todo el juego)
static func get_shared_material() -> ShaderMaterial:
	ensure_initialized()
	return _shared_material


## Retorna el Texture2DArray universal compilado del Atlas Inteligente
static func get_texture_array() -> Texture2DArray:
	ensure_initialized()
	return _texture_array


## Alias público para asegurar inicialización del atlas
static func init_manager() -> void:
	ensure_initialized()


## Retorna el Material Shader Compartido para el MultiMesh de Alfombras Rectangulares (Delegado al Atlas Inteligente)
static func get_rugs_material() -> ShaderMaterial:
	PlanarPropsManagerScript.ensure_initialized()
	return PlanarPropsManagerScript.get_material()


## Retorna el nombre semántico de la alfombra (0 a 19)
static func get_rug_name(id: int) -> String:
	PlanarPropsManagerScript.ensure_initialized()
	var prop_id := "rug_%02d" % id
	var prop := PlanarPropsManagerScript.get_prop(prop_id)
	return prop.get("name", "Alfombra Rectangular")


## Total de estampados de alfombras disponibles
static func get_rug_count() -> int:
	PlanarPropsManagerScript.ensure_initialized()
	return PlanarPropsManagerScript.get_props_by_filter("floor", ["rug"]).size()


## Escanea una carpeta del proyecto y auto-registra cualquier archivo nuevo (.png, .jpg, .webp)
static func _scan_folder_for_textures(folder_path: String) -> void:
	var gpath := ProjectSettings.globalize_path(folder_path)
	if not DirAccess.dir_exists_absolute(gpath):
		return
	var dir := DirAccess.open(gpath)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			if (lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".webp")) and not lower.ends_with(".import"):
				if not lower.contains("raw"):
					var id := file_name.get_basename().to_lower()
					if not _entries.has(id):
						_entries[id] = folder_path.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Reconstruye el Texture2DArray y refresca el material compartido
static func _rebuild_array() -> void:
	_keys.clear()
	_layer_map.clear()

	# Ordenación determinista y reproducible:
	# Maderas base primero (capas 0..3: roble_claro, nogal_oscuro, caoba_rojiza, pino_natural)
	# Luego el resto ordenado alfabéticamente
	var sorted_keys: Array[String] = []
	var base_order := ["roble_claro", "nogal_oscuro", "caoba_rojiza", "pino_natural"]
	for bk in base_order:
		if _entries.has(bk):
			sorted_keys.append(bk)
	var other_keys: Array[String] = []
	for k in _entries:
		if not sorted_keys.has(k):
			other_keys.append(k)
	other_keys.sort()
	sorted_keys.append_array(other_keys)

	var images: Array[Image] = []
	for key in sorted_keys:
		var path_val = _entries[key]
		var img := _load_and_normalize_image(path_val)
		if img != null:
			var layer_idx := images.size()
			images.append(img)
			_keys.append(key)
			_layer_map[key] = layer_idx
		else:
			print("[FurnitureTextureManager] Advertencia: Textura '%s' (%s) no encontrada o eliminada. Omitiendo del Texture2DArray." % [key, str(path_val)])

	if images.is_empty():
		var dummy := Image.create(TEXTURE_RESOLUTION, TEXTURE_RESOLUTION, true, Image.FORMAT_RGBA8)
		dummy.fill(Color(0.68, 0.48, 0.32, 1.0))
		dummy.generate_mipmaps()
		images.append(dummy)
		_keys.append("default")
		_layer_map["default"] = 0

	var tex_arr := Texture2DArray.new()
	var err := tex_arr.create_from_images(images)
	if err != OK:
		printerr("[FurnitureTextureManager] ERROR al crear Texture2DArray universal: ", err)
		return

	_texture_array = tex_arr

	var shader := load(FURNITURE_SHADER_PATH) as Shader
	if shader:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = shader
		_shared_material.set_shader_parameter("furniture_textures", _texture_array)
		_shared_material.set_shader_parameter("wood_textures", _texture_array)
		_shared_material.set_shader_parameter("uv_scale", 1.0)
		_shared_material.set_shader_parameter("default_roughness", 0.55)
		_shared_material.set_shader_parameter("default_metallic", 0.05)

	print("[FurnitureTextureManager] ✓ Atlas Inteligente compilado: %d capas (%s)." % [
		_keys.size(),
		", ".join(_keys)
	])


## Carga y normaliza una imagen a tamaño estándar preservando pixel art
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
			# Para texturas pixel art (<= 256px), interpolación NEAREST para máxima nitidez PSX
			var interp := Image.INTERPOLATE_NEAREST if img.get_width() <= 256 else Image.INTERPOLATE_LANCZOS
			img.resize(TEXTURE_RESOLUTION, TEXTURE_RESOLUTION, interp)
		img.generate_mipmaps()
		return img

	return null
