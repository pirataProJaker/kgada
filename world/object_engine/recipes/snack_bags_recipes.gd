class_name SnackBagsRecipes
extends RefCounted

## Catálogo de Recetas Paramétricas de Bolsas de Papitas / Sabritas (Play Sector X)
## +0 DRAW CALLS GARANTIZADO:
## Descompone cada bolsa de botana (pillow pouch) en primitivas universales ('cube')
## reutilizando el Atlas Inteligente (snack_bags_atlas.png) en una sola pasada de instancing.
##
## Catálogo de 20 Bolsas de Botanas (Cont. Net. 60g cada una):
## Fila 0:
##  0. tostiks   - Tostik's Original (Totopos de maíz rojo)
##  1. crujitos  - Crujitos Queso (Churritos de queso amarillo)
##  2. rizitas   - Rizitas Crema y Cebolla (Papas onduladas verde)
##  3. chispas   - Chispas Picante (Totopos triangulares naranja picante)
##  4. puffys    - Puffys BBQ (Aros crujientes morado barbecue)
## Fila 1:
##  5. krachitos - Krachitos Sal Marina (Papas onduladas azul)
##  6. fuegorix  - FuegoRix Extra Picante (Rollitos de maíz negro con fuego)
##  7. maizmax   - MaízMax Natural (Totopos de maíz beige crema con elote)
##  8. bolitas   - Bolitas Queso (Esferas crujientes de queso rojo)
##  9. ondulin   - Ondulín Vinagreta (Papas onduladas cian vinagreta)
## Fila 2:
## 10. crokis    - Crokis Barbacoa (Aros crujientes naranja BBQ)
## 11. papasol   - Papasol Limón y Sal (Papas fritas verde lima limón y sal)
## 12. rinrin    - RinRin Jamón (Botanas crujientes morado jamón ahumado)
## 13. crujix    - Crujix Carnitas (Chicharrones crujientes azul carnitas)
## 14. megapik   - MegaPik Queso Intenso (Totopos negro con rayo queso)
## Fila 3:
## 15. saladitas - Saladitas Clásicas (Galletas saladas azul rey)
## 16. paprizas  - Paprizas Jalapeño (Totopos rojo con jalapeño)
## 17. chipan    - Chipán Tocino (Tiras crujientes beige tocino)
## 18. gomitas   - Gomitas Frutas (Panditas / gomitas rosa frutas)
## 19. verdix    - Verdix Vegetales (Palitos verde vegetales)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. BOLSA INDIVIDUAL DE BOTANA 60g (PILLOW POUCH DE PAPITAS / SABRITAS)
# =========================================================================
class SnackBagRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones proporcionales exactas de bolsa de botana de 60g
		var w: float = params.get("width", 0.135)       # 13.5 cm de ancho frontal
		var h: float = params.get("height", 0.190)      # 19.0 cm de altura
		var d: float = params.get("depth", 0.038)       # 3.8 cm de grosor inflado en el ecuador central
		var has_collision: bool = params.get("collision", true)
		var show_crimps: bool = params.get("crimp_tabs", true)

		# Selección de variedad (por índice 0..19, ID o alias de marca)
		var snack_param: Variant = params.get("snack", params.get("bag", params.get("sabrita", params.get("flavor", params.get("skin", 0)))))
		var pack_data: Dictionary = ObjectAtlasScript.get_snack_bag_data(snack_param)
		var pack_id: String = pack_data["id"]
		var atlas_key: String = "snack_bags_atlas"

		# Orientación: de pie vertical, o acostada en mostrador
		var lying_down: bool = params.get("lying_down", params.get("flat", false))
		var yaw_offset: float = float(params.get("rot_y", params.get("yaw", 0.0)))
		var pitch_offset: float = -90.0 if lying_down else float(params.get("pitch", 0.0))
		var roll_offset: float = float(params.get("roll", 0.0))

		var rot_basis := Basis.from_euler(Vector3(deg_to_rad(pitch_offset), deg_to_rad(yaw_offset), deg_to_rad(roll_offset)))
		var bag_t := base_t * Transform3D(rot_basis, Vector3.ZERO)

		var half_h: float = h * 0.5
		var crimp_h: float = 0.012 if show_crimps else 0.0
		var body_h: float = h - (crimp_h * 2.0)

		# 1. CUERPO INFLADO DE LA BOLSA (Pillow Pouch Bipirámide Truncada)
		# Malla paramétrica de almohada: plateau central al 76% y pendientes piramidales que
		# convergen suavemente a los bordes sellados con normales infladas continuas (+0 Draw Calls).
		var core_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, 0.0))
		builder.add_smart_pillow(
			core_t,
			Vector3(w, body_h, d),
			atlas_key,
			pack_id + "_front",
			0.35, # Acabado satinado tipo envoltura plástica/metalizada BOPP
			0.08, # Reflejo especular característico
			has_collision,
			true  # Normales suaves infladas
		)

		# 2. SELLOS TERMOSELLADOS SUPERIOR E INFERIOR (Heat-Sealed Crimp Tabs)
		if show_crimps:
			var crimp_d: float = 0.0025 # Sello plano termosellado
			var crimp_w: float = w * 0.98

			# Sello superior (+Y)
			var top_crimp_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h + (body_h * 0.5) + (crimp_h * 0.5), 0.0))
			builder.add_smart_box(
				top_crimp_t,
				Vector3(crimp_w, crimp_h, crimp_d),
				atlas_key,
				pack_id + "_color",
				0.45,
				0.05,
				false
			)

			# Sello inferior (-Y)
			var btm_crimp_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h - (body_h * 0.5) - (crimp_h * 0.5), 0.0))
			builder.add_smart_box(
				btm_crimp_t,
				Vector3(crimp_w, crimp_h, crimp_d),
				atlas_key,
				pack_id + "_color",
				0.45,
				0.05,
				false
			)


# =========================================================================
# 2. FILA DE BOLSAS DE PAPITAS (PARA ESTANTE O MOSTRADOR)
# =========================================================================
class SnackBagsRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var bags_list: Array = params.get("snacks", params.get("bags", [0, 1, 2, 3, 4]))
		var spacing: float = params.get("spacing", 0.155)
		var lying_down: bool = params.get("lying_down", false)
		var has_collision: bool = params.get("collision", true)

		var count: int = bags_list.size()
		var total_len: float = float(count - 1) * spacing
		var start_x: float = -total_len * 0.5

		for i in range(count):
			var px: float = start_x + float(i) * spacing
			var offset_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 0.0))
			SnackBagRecipe.build(builder, offset_t, {
				"snack": bags_list[i],
				"lying_down": lying_down,
				"collision": has_collision
			})


# =========================================================================
# 3. EXHIBIDOR MULTINIVEL DE BOTANAS (RACK GÓNDOLA DE TIENDA CONVENIENCIA)
# =========================================================================
class SnackBagsDisplayRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var spacing_x: float = params.get("spacing_x", 0.152)
		var tier_height: float = params.get("tier_height", 0.220)
		var tier_depth: float = params.get("tier_depth", 0.075)
		var tilt_degrees: float = params.get("tilt_degrees", -8.0)
		var atlas_key: String = "commercial_shelf"

		# 4 Niveles correspondientes a las 4 filas del catálogo (5 bolsas por nivel = 20 total)
		var row0 := ["tostiks", "crujitos", "rizitas", "chispas", "puffys"]
		var row1 := ["krachitos", "fuegorix", "maizmax", "bolitas", "ondulin"]
		var row2 := ["crokis", "papasol", "rinrin", "crujix", "megapik"]
		var row3 := ["saladitas", "paprizas", "chipan", "gomitas", "verdix"]

		var tiers := [row3, row2, row1, row0] # De abajo hacia arriba
		var total_w: float = float(5) * spacing_x + 0.05

		# Estructura del estante góndola
		for t_idx in range(tiers.size()):
			var ty: float = float(t_idx) * tier_height
			var tz: float = -float(t_idx) * tier_depth

			# Repisa de apoyo
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, ty - 0.005, tz))
			builder.add_smart_box(
				shelf_t,
				Vector3(total_w, 0.012, 0.090),
				atlas_key,
				"shelf_surface",
				0.35,
				0.20,
				true
			)

			# Barra frontal anti-caída
			var lip_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, ty + 0.018, tz + 0.042))
			builder.add_smart_box(
				lip_t,
				Vector3(total_w, 0.035, 0.006),
				atlas_key,
				"upright_post",
				0.25,
				0.30,
				false
			)

			# Disponer las 5 bolsas del nivel
			var list: Array = tiers[t_idx]
			var start_x: float = -float(list.size() - 1) * spacing_x * 0.5
			for p_i in range(list.size()):
				var px: float = start_x + float(p_i) * spacing_x
				var p_pos := Vector3(px, ty + 0.008, tz)
				var rot_b := Basis.from_euler(Vector3(deg_to_rad(tilt_degrees), 0.0, 0.0))
				var p_t := base_t * Transform3D(rot_b, p_pos)

				SnackBagRecipe.build(builder, p_t, {
					"snack": list[p_i],
					"collision": false
				})

		# Laterales de la estructura del exhibidor
		var side_h: float = float(tiers.size()) * tier_height + 0.08
		var side_t: float = 0.018
		var half_w: float = (total_w * 0.5) + (side_t * 0.5)

		for side_dir in [-1.0, 1.0]:
			var side_x: float = side_dir * half_w
			var side_pos := Vector3(side_x, side_h * 0.5 - 0.01, -tier_depth * 1.5)
			var side_trans := base_t * Transform3D(Basis.IDENTITY, side_pos)
			builder.add_smart_box(
				side_trans,
				Vector3(side_t, side_h, 0.32),
				atlas_key,
				"upright_post",
				0.35,
				0.20,
				true
			)
