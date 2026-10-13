class_name SodaCansRecipes
extends RefCounted

## Recetas Oficiales de Latas de Refresco / Bebidas en Lata 355ml (Play Sector X)
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine con Texture2DArray)
## =========================================================================
## 1 Solo Modelo Paramétrico Universal que soporta las 19 latas del atlas:
##
##   0. kola_plus        - Kola Plus 355ml (Refresco Sabor Cola)
##   1. pepzi_maxx       - Pepzi Maxx 355ml (Máximo Sabor Sin Azúcar)
##   2. spritz_up        - Spritz Up 355ml (Sabor Lima-Limón)
##   3. fantatx          - Fantatx Naranja 355ml (Sabor Naranja)
##   4. seven_spark      - Seven Spark 355ml (Sabor Lima)
##   5. dr_pepperon      - Dr Pepperón 355ml (Sabor Mora / Especial)
##   6. mont_dew         - Mont Dew 355ml (Citrus Energético)
##   7. crushy           - Crushy Naranja 355ml (Sabor Naranja)
##   8. squirtle_citrus  - Squirtle Citrus 355ml (Toronja-Limón)
##   9. mirindaz         - Mirindaz Naranja 355ml (Sabor Naranja)
##  10. jarriton         - Jarriton Tutti Frutti 355ml (Sabor Frutas Mexicano)
##  11. manzanita_solis  - Manzanita Solís 355ml (Sabor Manzana)
##  12. freskita         - Freskita Agua Mineral 355ml
##  13. inka_schweppz    - Inka Cola-Real / Schweppz Tonic 355ml
##  14. canada_dry       - Canada Dry Ginger Ale 355ml
##  15. red_buller       - Red Buller Energy Drink 355ml
##  16. mounstro_energy  - Mounstro Energy 355ml
##  17. aw_root_beer     - A&W Root Beer 355ml
##  18. muggy_float      - Muggy Float Chocolate 355ml

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. LATA INDIVIDUAL DE REFRESCO DE ALUMINIO (355ML)
# =========================================================================
class SodaCanRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones proporcionales reales de una lata estándar de 355ml (12 oz)
		var r: float = params.get("radius", 0.033)       # 6.6 cm de diámetro
		var h: float = params.get("height", 0.122)      # 12.2 cm de altura
		var has_lid: bool = params.get("has_lid", true)
		var has_collision: bool = params.get("collision", true)

		# Selección de la bebida (por índice 0..18 o clave semántica)
		var can_param: Variant = params.get("soda", params.get("drink", params.get("can", 0)))
		var can_data: Dictionary = ObjectAtlasScript.get_soda_can_data(can_param)
		var can_id: String = can_data["id"]
		var atlas_key: String = "soda_cans_atlas"

		# Rotación de +90 grados en Y para que el logotipo y diseño frontal miren hacia +Z (frente)
		# y el código de barras con la tabla nutricional queden en el dorso (-Z)
		var yaw_offset: float = float(params.get("rot_y", params.get("yaw", 0.0)))
		var front_align := Basis(Vector3.UP, deg_to_rad(90.0 + yaw_offset))

		# 1. Cuerpo cilíndrico principal (envoltorio 360° con logotipo, rebordes de aluminio y tabla)
		var body_t := base_t * Transform3D(front_align, Vector3(0.0, h * 0.5, 0.0))
		builder.add_smart_cylinder(
			body_t,
			r,
			h,
			atlas_key,
			can_id,
			0.30,
			0.65,
			has_collision
		)

		# 2. Tapa superior de aluminio con anilla abre-fácil (Pull-Tab)
		if has_lid:
			var lid_h := 0.002
			var lid_r := r * 0.95
			# Tapa ligeramente orientada para exhibición natural
			var lid_basis := Basis(Vector3.UP, deg_to_rad(0.0))
			var lid_t := base_t * Transform3D(lid_basis, Vector3(0.0, h + lid_h * 0.5 - 0.0005, 0.0))
			builder.add_smart_cylinder(
				lid_t,
				lid_r,
				lid_h,
				atlas_key,
				"lid",
				0.22,
				0.88,
				false
			)


# =========================================================================
# 2. FILA DE LATAS ORDENADA (PARA ANAQUELES, MOSTRADORES Y TIENDAS OXXO)
# =========================================================================
class SodaCansRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var cans_list: Array = params.get("cans", [0, 1, 2, 3, 4])
		var gap: float = params.get("gap", 0.012)
		var r: float = params.get("radius", 0.033)
		var h: float = params.get("height", 0.122)

		var total_count: int = cans_list.size()
		var step_x := (r * 2.0) + gap
		var total_span := float(total_count - 1) * step_x

		for i in range(total_count):
			var px := -total_span * 0.5 + float(i) * step_x
			var item_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 0.0))
			SodaCanRecipe.build(builder, item_t, {
				"can": cans_list[i],
				"radius": r,
				"height": h,
				"has_lid": params.get("has_lid", true),
				"collision": params.get("collision", true)
			})


# =========================================================================
# 3. SIX-PACK DE LATAS (CUADRÍCULA 2x3 DE REFRESCOS O CERVEZAS)
# =========================================================================
class SodaCansSixPackRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var soda_type: Variant = params.get("soda", 0)
		var r: float = params.get("radius", 0.033)
		var h: float = params.get("height", 0.122)
		var gap: float = params.get("gap", 0.003)

		var step_x := (r * 2.0) + gap
		var step_z := (r * 2.0) + gap

		for row_idx in range(2):
			for col_idx in range(3):
				var px := -step_x + float(col_idx) * step_x
				var pz := -step_z * 0.5 + float(row_idx) * step_z
				var item_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, pz))
				SodaCanRecipe.build(builder, item_t, {
					"can": soda_type,
					"radius": r,
					"height": h,
					"has_lid": true,
					"collision": true
				})
