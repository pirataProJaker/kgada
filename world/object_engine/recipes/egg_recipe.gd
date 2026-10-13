class_name EggRecipe
extends ObjectRecipeBase

## Receta Oficial: Huevo de Gallina (+0 Draw Calls en ObjectEngine)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Utiliza la primitiva unitaria "sphere" escalada elípticamente (non-uniform scaling)
## para crear el perfil ovalado de un huevo real con acabado de cáscara mate.
##
## Parámetros disponibles en 'params':
##   - "color": "white" (huevo blanco) o "brown" / "moreno" (huevo moreno) [defecto: "white"]
##   - "width": diámetro transversal en metros [defecto: 0.044 (~4.4 cm)]
##   - "height": altura polo a polo en metros [defecto: 0.060 (~6.0 cm)]
##   - "tilt_deg": inclinación en grados (0 para en pie, 70-80 para recostado) [defecto: 0.0]
##   - "collision": generar forma de colisión física (BoxShape aproximada) [defecto: true]

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
	var w: float = params.get("width", 0.044)
	var h: float = params.get("height", 0.060)
	var color_type: String = str(params.get("color", "white")).to_lower()
	var tilt_deg: float = float(params.get("tilt_deg", 0.0))
	var col: bool = params.get("collision", true)

	# Textura y material según variedad de huevo (blanco de granja o moreno de rancho)
	var texture_key := "refrigerador"
	var uv_rect := Rect2(0.40, 0.20, 0.30, 0.30)
	var roughness := 0.65
	var metallic := 0.01

	if color_type == "brown" or color_type == "moreno" or color_type == "rojo" or color_type == "beige":
		texture_key = "pared_cremita_ext"
		uv_rect = Rect2(0.10, 0.10, 0.50, 0.50)
		roughness = 0.72

	# Transformación de orientación e inclinación
	var local_t := base_t
	if absf(tilt_deg) > 0.001:
		var rot_basis := Basis(Vector3.FORWARD, deg_to_rad(tilt_deg))
		local_t = base_t * Transform3D(rot_basis, Vector3(0.0, 0.0, 0.0))

	# Elevación sobre el punto de apoyo para que la base descanse sobre Y=0
	var egg_size := Vector3(w, h, w)
	var center_offset := Vector3(0.0, h * 0.5, 0.0)
	var final_t := local_t * Transform3D(Basis.IDENTITY, center_offset)

	# Instanciar huevo en la primitiva "sphere" (+0 Draw Calls)
	builder.add_sphere_scaled(final_t, egg_size, texture_key, uv_rect, roughness, metallic, col)
