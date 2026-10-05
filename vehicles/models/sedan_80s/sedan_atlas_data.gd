class_name SedanAtlasData
extends RefCounted

## Coordenadas UV exactas y regiones semánticas del Atlas Retro 80s Sedan (256x256)
## Calibrado píxel a píxel sobre la textura oficial PSX.

const ATLAS_SIZE := Vector2(256.0, 256.0)
const TEXTURE_PATH := "res://assets/models/vehicles/sedan_80s/Texture White.png"

# =========================================================================
# RECTÁNGULOS UV SEMÁNTICOS (Píxeles exactos normalizados 0..1)
# =========================================================================

# Frente (Parrilla y ópticas principales: X: 15..55, Y: 18..44)
const RECT_FRONT_GRILL := Rect2(15.0 / 256.0, 18.0 / 256.0, 40.0 / 256.0, 26.0 / 256.0)

# Trasera (Faros traseros combinados y paragolpes: X: 204..245, Y: 14..42)
const RECT_REAR_FACE := Rect2(204.0 / 256.0, 14.0 / 256.0, 41.0 / 256.0, 28.0 / 256.0)

# Perfil Lateral Completo (x: 3..251, y: 38..98)
const RECT_SIDE_BODY := Rect2(3.0 / 256.0, 38.0 / 256.0, 248.0 / 256.0, 60.0 / 256.0)

# Perfil Superior (Capó, Parabrisas, Techo, Luneta, Maletero) (x: 3..251, y: 116..151)
const RECT_TOP_PROFILE := Rect2(3.0 / 256.0, 116.0 / 256.0, 248.0 / 256.0, 35.0 / 256.0)

# Rueda: Cara frontal / Tapacubos circular (x: 210..255, y: 210..255)
const RECT_WHEEL_RIM := Rect2(210.0 / 256.0, 210.0 / 256.0, 45.0 / 256.0, 45.0 / 256.0)

# Neumático: Banda de rodadura exterior con dibujo (x: 149..209, y: 240..255)
const RECT_TIRE_TREAD := Rect2(149.0 / 256.0, 240.0 / 256.0, 60.0 / 256.0, 15.0 / 256.0)

# Fondo oscuro / Vano motor / Interior neutro (x: 76..118, y: 1..12)
const RECT_DARK_NEUTRAL := Rect2(76.0 / 256.0, 1.0 / 256.0, 40.0 / 256.0, 11.0 / 256.0)


# =========================================================================
# HITOS GEOMÉTRICOS DEL AUTO EN METROS (Escala Real 1:1)
# =========================================================================
const CAR_LENGTH := 4.60  # Largo total
const CAR_WIDTH  := 1.65  # Ancho total en la cintura
const CAR_HEIGHT := 1.38  # Alto total

# Ejes
const FRONT_AXLE_Z := -1.6151
const REAR_AXLE_Z  :=  0.9911
const WHEELBASE    :=  2.6062

# Ruedas
const WHEEL_RADIUS := 0.2961 # Diámetro ~0.59m
const WHEEL_WIDTH  := 0.20
const WHEEL_TRACK  := 1.348  # Distancia entre centros (0.674m cada lado)



static var _cached_texture: Texture2D = null
static var _cached_material: StandardMaterial3D = null

## Retorna la textura del atlas de forma resiliente
static func get_atlas_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture
	if ResourceLoader.exists(TEXTURE_PATH):
		_cached_texture = load(TEXTURE_PATH)
		if _cached_texture != null:
			return _cached_texture
	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	if FileAccess.file_exists(gpath):
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			_cached_texture = ImageTexture.create_from_image(img)
			return _cached_texture
	return _cached_texture


## Retorna el material configurado con este atlas y soporte de color por vértice
static func get_vehicle_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = get_atlas_texture()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.roughness = 0.55
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cached_material = mat
	return mat
