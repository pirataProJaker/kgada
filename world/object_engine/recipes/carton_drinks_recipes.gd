class_name CartonDrinksRecipes
extends RefCounted

## Recetas Oficiales de Productos en Cartón / Bebidas en Cartón 1L (Play Sector X)
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine con Texture2DArray)
## =========================================================================
## 1 Solo Modelo Paramétrico Universal que soporta las 18 bebidas del atlas:
##
##   0. leche_entera      - Lácteos del Valle - Leche Entera 1L
##   1. leche_descremada  - Lácteos del Valle - Leche Descremada 1L
##   2. leche_chocolate   - ChocoVida - Leche Chocolate 1L
##   3. jugo_naranja      - SolVida - Jugo de Naranja 100% Natural 1L
##   4. jugo_manzana      - SolVida - Jugo de Manzana 100% Natural 1L
##   5. jugo_mango        - SolVida - Jugo de Mango 100% Natural 1L
##   6. nectar_fresa      - Valle Frutal - Néctar de Fresa con Vitaminas 1L
##   7. nectar_naranja    - Valle Frutal - Néctar de Naranja con Vitaminas 1L
##   8. te_limon          - Tezá - Té Helado Limón 1L
##   9. agua_coco         - Vida - Agua de Coco 100% Natural 1L
##  10. bebida_platano    - Plátano Fresco - Bebida de Plátano con Vitaminas 1L
##  11. cafe_con_leche    - Café del Valle - Café con Leche 1L
##  12. rayo_energy       - Rayo - Energy Drink 1L
##  13. koka_plus         - Koka Plus - Sabor Original 1L
##  14. spritea           - Spritea - Sabor Lima-Limón 1L
##  15. jumexito_mango    - Jumexito - Néctar de Mango 1L
##  16. narizona_durazno  - NariZona - Té Helado Durazno 1L
##  17. aquapura_agua     - AquaPura - Agua Purificada 1L

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. ENVASE DE BEBIDA EN CARTÓN DE 1 LITRO (TETRA BRIK 1L)
# =========================================================================
class CartonDrinkRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones proporcionales reales de 1 Litro (base rectangular estilizada)
		var w: float = params.get("width", 0.090)
		var d: float = params.get("depth", 0.058)
		var h: float = params.get("height", 0.185)
		var has_cap: bool = params.get("has_cap", true)
		var has_collision: bool = params.get("collision", true)

		# Selección de la bebida (por índice 0..17 o nombre semántico)
		var drink_param: Variant = params.get("drink", params.get("flavor", params.get("product", 0)))
		var drink_data: Dictionary = ObjectAtlasScript.get_carton_drink_data(drink_param)
		var drink_id: String = drink_data["id"]
		var atlas_key: String = "carton_drinks_atlas"

		var t_panel := 0.002
		var half_h := h * 0.5

		# 1. Cuerpo / Núcleo estructural (Bloque central con color de fondo del lateral)
		# Provee el color base del cartón, lados inferiores y colisión consolidada
		var core_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, 0.0))
		builder.add_smart_box(
			core_t,
			Vector3(w - t_panel * 2.0, h, d - t_panel * 2.0),
			atlas_key,
			drink_id + "_left",
			0.50,
			0.02,
			has_collision
		)

		# 2. Cara Frontal (+Z): Logotipo, ilustración frutal/splash y leyenda 1L
		var front_z := d * 0.5 - t_panel * 0.5
		var front_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, front_z))
		builder.add_smart_box(
			front_t,
			Vector3(w, h, t_panel),
			atlas_key,
			drink_id + "_front",
			0.45,
			0.02,
			false
		)

		# 3. Cara Posterior (-Z): Diseño gráfico de marca
		var back_z := -d * 0.5 + t_panel * 0.5
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, back_z))
		builder.add_smart_box(
			back_t,
			Vector3(w, h, t_panel),
			atlas_key,
			drink_id + "_front",
			0.45,
			0.02,
			false
		)

		# 4. Cara Lateral Derecha (+X): Tabla de Información Nutricional y Código de Barras
		var right_x := w * 0.5 - t_panel * 0.5
		var right_t := base_t * Transform3D(Basis.IDENTITY, Vector3(right_x, half_h, 0.0))
		builder.add_smart_box(
			right_t,
			Vector3(t_panel, h, d),
			atlas_key,
			drink_id + "_side",
			0.45,
			0.02,
			false
		)

		# 5. Cara Lateral Izquierda (-X): Franja corporativa lateral
		var left_x := -w * 0.5 + t_panel * 0.5
		var left_t := base_t * Transform3D(Basis.IDENTITY, Vector3(left_x, half_h, 0.0))
		builder.add_smart_box(
			left_t,
			Vector3(t_panel, h, d),
			atlas_key,
			drink_id + "_left",
			0.45,
			0.02,
			false
		)

		# 6. Tapa Superior (+Y): Solapa superior del cartón
		var top_y := h - t_panel * 0.5
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, top_y, 0.0))
		builder.add_smart_box(
			top_t,
			Vector3(w, t_panel, d),
			atlas_key,
			drink_id + "_top",
			0.45,
			0.02,
			false
		)

		# 7. Tapón de Rosca de Plástico (+Y)
		if has_cap:
			var cap_r := 0.013
			var cap_h := 0.010
			# Ligero descentrado característico de los envases Tetra Brik modernos
			var cap_pos := Vector3(-w * 0.20, h + cap_h * 0.5, 0.0)
			var cap_t := base_t * Transform3D(Basis.IDENTITY, cap_pos)
			# Usamos la región top de la bebida para que el tapón adquiera el tono plástico exacto
			builder.add_smart_cylinder(
				cap_t,
				cap_r,
				cap_h,
				atlas_key,
				drink_id + "_top",
				0.35,
				0.05,
				false
			)


# =========================================================================
# 2. FILA DE EXHIBICIÓN DE BEBIDAS (PARA REPISAS Y TIENDAS OXXO)
# =========================================================================
## Permite generar una fila ordenada de varias bebidas sobre una repisa o mostrador
class CartonDrinksRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var drinks_list: Array = params.get("drinks", [0, 1, 2, 3, 4, 5])
		var gap: float = params.get("gap", 0.012)
		var carton_w: float = params.get("width", 0.090)
		var carton_d: float = params.get("depth", 0.058)
		var carton_h: float = params.get("height", 0.185)

		var total_count: int = drinks_list.size()
		var step_x := carton_w + gap
		var total_span := float(total_count - 1) * step_x

		for i in range(total_count):
			var px := -total_span * 0.5 + float(i) * step_x
			var item_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 0.0))
			CartonDrinkRecipe.build(builder, item_t, {
				"drink": drinks_list[i],
				"width": carton_w,
				"depth": carton_d,
				"height": carton_h,
				"has_cap": params.get("has_cap", true),
				"collision": params.get("collision", true)
			})
