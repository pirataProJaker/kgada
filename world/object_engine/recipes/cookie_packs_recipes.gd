class_name CookiePacksRecipes
extends RefCounted

## Catálogo de Recetas Paramétricas de Paquetes de Galletas Rizko (Play Sector X)
## +0 DRAW CALLS GARANTIZADO:
## Descompone cada paquete de galletas (flow-pack) en primitivas universales ('cube')
## reutilizando el Atlas Inteligente (cookie_packs_atlas.png) en una sola pasada de instancing.
##
## Catálogo de 18 Paquetes de Galletas (Cont. Net. 120g cada uno):
## Fila 0:
##  0. clasicas       - Rizko Clásicas (Azul real con galletas doradas tradicionales)
##  1. chocolate      - Rizko Chocolate (Marrón cálido con galletas de chocolate)
##  2. vainilla       - Rizko Vainilla (Beige crema con galletas doradas de vainilla)
##  3. fresa          - Rizko Fresa (Rojo carmesí con galletas y fresas frescas)
##  4. crema          - Rizko Crema (Negro con galletas sándwich rellenas de crema blanca)
##  5. limon          - Rizko Limón (Verde limón cítrico con rodajas de lima)
##  6. arandano       - Rizko Arándano (Morado púrpura con arándanos silvestres)
##  7. naranja        - Rizko Naranja (Naranja vibrante con rodajas de naranja)
##  8. frutos_rojos   - Rizko Frutos Rojos (Rosa frambuesa con frutos del bosque)
## Fila 1:
##  9. platano        - Rizko Plátano (Amarillo brillante con plátanos maduros)
## 10. chispas        - Rizko Chispas (Cian turquesa con galletas con chispas de chocolate)
## 11. integrales     - Rizko Integrales (Azul marino con espigas de trigo integral)
## 12. doble_choco    - Rizko Doble Chocolate (Envoltura blanca y marrón chocolate)
## 13. menta          - Rizko Menta (Verde menta pastel con hojas de menta)
## 14. canela         - Rizko Canela (Rojo canela con rajas de canela)
## 15. avena          - Rizko Avena (Lavanda lila suave con hojuelas de avena)
## 16. festival       - Rizko Festival (Negro festivo con chispas de confeti multicolor)
## 17. cookies_cream  - Rizko Cookies & Cream (Azul cielo con galletas de chocolate y crema)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. PAQUETE INDIVIDUAL DE GALLETAS RIZKO 120g (FLOW-PACK TUBULAR)
# =========================================================================
class CookiePackRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones proporcionales de paquete flow-pack de 120g
		var w: float = params.get("width", 0.052)      # 5.2 cm de ancho frontal
		var h: float = params.get("height", 0.185)     # 18.5 cm de longitud
		var d: float = params.get("depth", 0.022)      # 2.2 cm de grosor lateral (más delgado y estilizado)
		var has_collision: bool = params.get("collision", true)
		var show_crimps: bool = params.get("crimp_tabs", true)

		# Selección de variedad (por índice 0..17, ID o alias de sabor)
		var cookie_param: Variant = params.get("cookie", params.get("pack", params.get("flavor", params.get("skin", 0))))
		var pack_data: Dictionary = ObjectAtlasScript.get_cookie_pack_data(cookie_param)
		var pack_id: String = pack_data["id"]
		var atlas_key: String = "cookie_packs_atlas"

		# Orientación: de pie vertical, o acostado en estante
		var lying_down: bool = params.get("lying_down", params.get("flat", false))
		var yaw_offset: float = float(params.get("rot_y", params.get("yaw", 0.0)))
		var pitch_offset: float = -90.0 if lying_down else float(params.get("pitch", 0.0))
		var roll_offset: float = float(params.get("roll", 0.0))

		var rot_basis := Basis.from_euler(Vector3(deg_to_rad(pitch_offset), deg_to_rad(yaw_offset), deg_to_rad(roll_offset)))
		var pack_t := base_t * Transform3D(rot_basis, Vector3.ZERO)

		var t_panel: float = 0.0012
		var half_h: float = h * 0.5

		# 1. NÚCLEO BASE / CUERPO INTERNO (+Y y -Y muestran color de marca)
		var core_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, 0.0))
		builder.add_smart_box(
			core_t,
			Vector3(w - t_panel * 2.0, h, d - t_panel * 2.0),
			atlas_key,
			pack_id + "_color",
			0.48,
			0.02,
			has_collision
		)

		# 2. CARA FRONTAL (+Z): Logotipo Rizko, nombre de variedad, galletas y 120g
		var front_z: float = (d * 0.5) - (t_panel * 0.5)
		var front_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, front_z))
		builder.add_smart_box(
			front_t,
			Vector3(w, h, t_panel),
			atlas_key,
			pack_id + "_front",
			0.45,
			0.05,
			false
		)

		# 3. CARA POSTERIOR (-Z): Información nutrimental oficial, tabla y código de barras
		var back_z: float = (-d * 0.5) + (t_panel * 0.5)
		var back_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, back_z))
		builder.add_smart_box(
			back_t,
			Vector3(w, h, t_panel),
			atlas_key,
			pack_id + "_back",
			0.45,
			0.05,
			false
		)

		# 4. CARA LATERAL DERECHA (+X): Tira vertical con logotipo oficial
		var side_r_x: float = (w * 0.5) - (t_panel * 0.5)
		var side_r_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(side_r_x, half_h, 0.0))
		builder.add_smart_box(
			side_r_t,
			Vector3(t_panel, h, d),
			atlas_key,
			pack_id + "_side",
			0.45,
			0.05,
			false
		)

		# 5. CARA LATERAL IZQUIERDA (-X): Tira lateral congruente
		var side_l_x: float = (-w * 0.5) + (t_panel * 0.5)
		var side_l_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(side_l_x, half_h, 0.0))
		builder.add_smart_box(
			side_l_t,
			Vector3(t_panel, h, d),
			atlas_key,
			pack_id + "_side",
			0.45,
			0.05,
			false
		)

		# 6. PESTAÑAS DE SELLADO FLOW-PACK (Crimped Seam Ends)
		if show_crimps:
			var crimp_h: float = 0.008
			var crimp_d: float = 0.003
			var crimp_w: float = w * 0.94

			# Pestaña de sellado superior (+Y)
			var top_crimp_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + crimp_h * 0.5, 0.0))
			builder.add_smart_box(
				top_crimp_t,
				Vector3(crimp_w, crimp_h, crimp_d),
				atlas_key,
				pack_id + "_color",
				0.50,
				0.02,
				false
			)

			# Pestaña de sellado inferior (-Y)
			var btm_crimp_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(0.0, -crimp_h * 0.5, 0.0))
			builder.add_smart_box(
				btm_crimp_t,
				Vector3(crimp_w, crimp_h, crimp_d),
				atlas_key,
				pack_id + "_color",
				0.50,
				0.02,
				false
			)


# =========================================================================
# 2. FILA DE PAQUETES DE GALLETAS (PARA ESTANTE O MOSTRADOR)
# =========================================================================
class CookiePacksRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var packs_list: Array = params.get("cookies", params.get("packs", [0, 1, 2, 3, 4]))
		var spacing: float = params.get("spacing", 0.065)
		var lying_down: bool = params.get("lying_down", false)
		var has_collision: bool = params.get("collision", true)

		var count: int = packs_list.size()
		var total_len: float = float(count - 1) * spacing
		var start_x: float = -total_len * 0.5

		for i in range(count):
			var px: float = start_x + float(i) * spacing
			var offset_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 0.0))
			CookiePackRecipe.build(builder, offset_t, {
				"cookie": packs_list[i],
				"lying_down": lying_down,
				"collision": has_collision
			})


# =========================================================================
# 3. EXHIBIDOR MULTINIVEL DE GALLETAS RIZKO (SUPERMERCADO / CONVENIENCIA)
# =========================================================================
class CookiePacksDisplayRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var spacing_x: float = params.get("spacing_x", 0.068)
		var tier_height: float = params.get("tier_height", 0.210)
		var tier_depth: float = params.get("tier_depth", 0.060)
		var tilt_degrees: float = params.get("tilt_degrees", -6.0)
		var atlas_key: String = "commercial_shelf"

		# Nivel 0: Primeros 9 sabores (Row 0 de la colección)
		var row0_flavors := [
			"clasicas", "chocolate", "vainilla", "fresa", "crema",
			"limon", "arandano", "naranja", "frutos_rojos"
		]

		# Nivel 1: Siguientes 9 sabores (Row 1 de la colección)
		var row1_flavors := [
			"platano", "chispas", "integrales", "doble_choco", "menta",
			"canela", "avena", "festival", "cookies_cream"
		]

		var tiers := [row0_flavors, row1_flavors]
		var total_w: float = float(9) * spacing_x + 0.04

		# Estructura del mueble exhibidor (bandejas y respaldo)
		for t_idx in range(tiers.size()):
			var ty: float = float(t_idx) * tier_height
			var tz: float = -float(t_idx) * tier_depth

			# Repisa de apoyo
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, ty - 0.005, tz))
			builder.add_smart_box(
				shelf_t,
				Vector3(total_w, 0.012, 0.075),
				atlas_key,
				"shelf_surface",
				0.35,
				0.20,
				true
			)

			# Tope frontal transparente / metálico para evitar caídas
			var lip_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, ty + 0.015, tz + 0.035))
			builder.add_smart_box(
				lip_t,
				Vector3(total_w, 0.030, 0.006),
				atlas_key,
				"upright_post",
				0.25,
				0.30,
				false
			)

			# Disponer los 9 paquetes del nivel
			var list: Array = tiers[t_idx]
			var start_x: float = -float(list.size() - 1) * spacing_x * 0.5
			for p_i in range(list.size()):
				var px: float = start_x + float(p_i) * spacing_x
				var p_pos := Vector3(px, ty + 0.008, tz)
				var rot_b := Basis.from_euler(Vector3(deg_to_rad(tilt_degrees), 0.0, 0.0))
				var p_t := base_t * Transform3D(rot_b, p_pos)

				CookiePackRecipe.build(builder, p_t, {
					"cookie": list[p_i],
					"collision": false
				})

		# Laterales de la estructura del exhibidor
		var side_h: float = float(tiers.size()) * tier_height + 0.06
		var side_t: float = 0.015
		var half_w: float = (total_w * 0.5) + (side_t * 0.5)

		for side_dir in [-1.0, 1.0]:
			var side_x: float = side_dir * half_w
			var side_pos := Vector3(side_x, side_h * 0.5 - 0.01, -tier_depth * 0.5)
			var side_trans := base_t * Transform3D(Basis.IDENTITY, side_pos)
			builder.add_smart_box(
				side_trans,
				Vector3(side_t, side_h, 0.16),
				atlas_key,
				"upright_post",
				0.35,
				0.20,
				true
			)
