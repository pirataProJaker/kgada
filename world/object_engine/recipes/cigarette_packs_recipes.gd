class_name CigarettePacksRecipes
extends RefCounted

## Catálogo de Recetas Paramétricas de Cajetillas de Cigarros (Play Sector X)
## +0 DRAW CALLS GARANTIZADO:
## Descompone cada cajetilla en primitivas universales ('cube') reutilizando
## el Atlas Inteligente (cigarette_packs_atlas.png) en una sola pasada de instancing.
##
## Catálogo de 20 Cajetillas (20 Cigarros cada una):
##  0. ambar     - Ámbar Classic (Tabaco Rubio 20, hojas de tabaco)
##  1. nordico   - Nórdico Suave (Montañas nevadas en azul marino)
##  2. cielo     - Cielo Lights (Cielo azul y nubes blancas)
##  3. sable     - Sable Negro (Halcón dorado sobre negro carbón)
##  4. rio       - Río Mentol (Olas verdes mentoladas fluidas)
##  5. fenix     - Fénix Fuerte (Ave fénix de fuego sobre negro)
##  6. valor     - Valor Original (Chevron clásico rojo y blanco con dorado)
##  7. tormenta  - Tormenta Mentol (Rayo eléctrico azul cobalto)
##  8. duna      - Duna Suave (Dunas desérticas doradas)
##  9. boreal    - Boreal Mentol (Bosque boreal de pinos verde esmeralda)
## 10. zafiro    - Zafiro Original (Diamante brillante azul zafiro)
## 11. lider     - Líder Fuerte (Corona real roja y blanca)
## 12. solsticio - Solsticio Amarillo (Sol radiante amarillo mostaza)
## 13. eclipse   - Eclipse Negro (Corona de eclipse solar sobre negro)
## 14. trento    - Trento Original (Líneas diagonales deportivas azul y blanco)
## 15. alba      - Alba Suave (Hojas de tabaco beige arena minimalista)
## 16. vertice   - Vértice Mentol (Triángulo geométrico verde menta)
## 17. caleo     - Caleo Classic (Emblema clásico rojo carmesí)
## 18. marfil    - Marfil Original (León majestuoso sobre marfil y blanco)
## 19. lumen     - Lumen Violeta (Estrella de ocho puntas púrpura violeta)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. CAJETILLA INDIVIDUAL DE CIGARROS (FLIP-TOP HARD PACK DE 20 CIGARROS)
# =========================================================================
class CigarettePackRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones proporcionales exactas de cajetilla dura estándar de 20 cigarros
		var w: float = params.get("width", 0.055)     # 5.5 cm de ancho frontal
		var h: float = params.get("height", 0.088)    # 8.8 cm de altura
		var d: float = params.get("depth", 0.024)     # 2.4 cm de profundidad / grosor
		var has_collision: bool = params.get("collision", true)

		# Selección de la cajetilla (por índice 0..19, ID o alias de marca)
		var cigar_param: Variant = params.get("cigar", params.get("pack", params.get("brand", params.get("skin", 0))))
		var pack_data: Dictionary = ObjectAtlasScript.get_cigarette_pack_data(cigar_param)
		var pack_id: String = pack_data["id"]
		var atlas_key: String = "cigarette_packs_atlas"

		# Orientación: de pie vertical, o acostada en mostrador/mesa
		var lying_down: bool = params.get("lying_down", params.get("flat", false))
		var yaw_offset: float = float(params.get("rot_y", params.get("yaw", 0.0)))
		var pitch_offset: float = -90.0 if lying_down else float(params.get("pitch", 0.0))
		var roll_offset: float = float(params.get("roll", 0.0))

		var rot_basis := Basis.from_euler(Vector3(deg_to_rad(pitch_offset), deg_to_rad(yaw_offset), deg_to_rad(roll_offset)))
		var pack_t := base_t * Transform3D(rot_basis, Vector3.ZERO)

		var t_panel: float = 0.0015
		var half_h: float = h * 0.5

		# 1. NÚCLEO BASE / TAPA SUPERIOR Y BASE (Color sólido oficial para +Y y -Y)
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

		# 2. CARA FRONTAL (+Z): Logotipo oficial, diseño de marca y texto de tabaco
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

		# 3. CARA POSTERIOR (-Z): Envoltura dorsal
		var back_z: float = (-d * 0.5) + (t_panel * 0.5)
		var back_t := pack_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, back_z))
		builder.add_smart_box(
			back_t,
			Vector3(w, h, t_panel),
			atlas_key,
			pack_id + "_front",
			0.45,
			0.05,
			false
		)

		# 4. CARA LATERAL DERECHA (+X): Franja lateral con nombre de marca y conteo "20"
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

		# 5. CARA LATERAL IZQUIERDA (-X): Franja lateral congruente
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


# =========================================================================
# 2. FILA DE CAJETILLAS (PARA MOSTRADOR O ESTANTE DE TIENDA)
# =========================================================================
class CigarettePacksRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var packs_list: Array = params.get("packs", [0, 1, 2, 3, 4])
		var spacing: float = params.get("spacing", 0.068)
		var lying_down: bool = params.get("lying_down", false)
		var has_collision: bool = params.get("collision", true)

		var count: int = packs_list.size()
		var total_len: float = float(count - 1) * spacing
		var start_x: float = -total_len * 0.5

		for i in range(count):
			var px: float = start_x + float(i) * spacing
			var offset_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 0.0))
			CigarettePackRecipe.build(builder, offset_t, {
				"cigar": packs_list[i],
				"lying_down": lying_down,
				"collision": has_collision
			})


# =========================================================================
# 3. EXHIBIDOR MULTINIVEL DE CAJETILLAS DE CONVENIENCIA / OXXO
# =========================================================================
class CigarettePacksDisplayRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var col_spacing: float = params.get("spacing_x", 0.072)
		var tier_h: float = params.get("tier_height", 0.105)
		var tier_d: float = params.get("tier_depth", 0.048)
		var tilt_deg: float = params.get("tilt_degrees", -6.0)
		var has_collision: bool = params.get("collision", true)

		var total_w: float = 5.0 * col_spacing + 0.04

		# 4 escalones acrílicos / estantes blancos
		for t_idx in range(4):
			var step_top_y: float = float(t_idx) * tier_h
			var step_z: float = -float(t_idx) * tier_d
			var step_height: float = maxf(step_top_y, 0.015)
			var step_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, step_height * 0.5, step_z))
			builder.add_smart_box(
				step_t,
				Vector3(total_w, step_height, tier_d),
				"commercial_cooler",
				"white_enamel",
				0.30,
				0.05,
				has_collision
			)

		# 4 filas x 5 columnas de cajetillas:
		# Fila 0 (arriba/atrás, Tier 3): 0..4 (Ámbar, Nórdico, Cielo, Sable, Río)
		# Fila 1 (Tier 2): 5..9 (Fénix, Valor, Tormenta, Duna, Boreal)
		# Fila 2 (Tier 1): 10..14 (Zafiro, Líder, Solsticio, Eclipse, Trento)
		# Fila 3 (abajo/frente, Tier 0): 15..19 (Alba, Vértice, Caleo, Marfil, Lumen)
		for row in range(4):
			var tier_level: int = 3 - row
			var py: float = float(tier_level) * tier_h
			var pz: float = -float(tier_level) * tier_d

			var basis_tilt := Basis(Vector3.RIGHT, deg_to_rad(tilt_deg))

			for col in range(5):
				var pack_idx: int = row * 5 + col
				var px: float = -2.0 * col_spacing + float(col) * col_spacing

				var pack_local_t := Transform3D(basis_tilt, Vector3(px, py, pz))
				var final_t := base_t * pack_local_t

				CigarettePackRecipe.build(builder, final_t, {
					"cigar": pack_idx,
					"collision": has_collision
				})
