class_name CandyBagsRecipes
extends RefCounted

## Catálogo de Recetas Paramétricas de Dulces, Chocolates y Golosinas (Play Sector X)
## +0 DRAW CALLS GARANTIZADO:
## Descompone cada bolsa/empaque en primitivas universales ('cube') reutilizando
## el Atlas Inteligente (candy_bags_atlas.png) en una sola pasada de instancing.
##
## Catálogo de 20 Golosinas:
##  0. chocorix   - Chocolate con Leche (Wafer / Barra rellena)
##  1. krix       - Oblea con Chocolate (Crujiente rojo)
##  2. mellos     - Chocolate con Relleno (Confites multicolor)
##  3. dulcitos   - Cacahuate Cubierto (Cacahuate feliz en confite amarillo)
##  4. nuxi       - Chocolate con Avellana (Barra premium dorada)
##  5. vitagom    - VitaGom Sabor Menta (Chicle verde mentolado)
##  6. cacaoz     - Chocolate Puro (Tableta de cacao amargo)
##  7. rebotes    - Caramelos de Fruta (Gomitas ácidas naranja)
##  8. freskito   - Chicle sin Azúcar Menta (Azul glacial refrescante)
##  9. brrrt      - Caramelo Menta (Pastilla glacial plateada)
## 10. chispy     - Caramelos Surtidos (Confitados frutales fucsia)
## 11. frutix     - Gomitas de Fruta (Panditas de colores amarillo)
## 12. zelta      - Caramelo Ácido (Tiras ácidas arcoíris negro)
## 13. lunetas    - Chocolate Confitado (Lentejas moradas)
## 14. tornado    - Chicle Sabor Frutas (Bloques de chicle rojo)
## 15. pipocas    - Pipocas Caramelo Crujiente (Palomitas dulces azul)
## 16. nubez      - Malvavisco con Chocolate (Bombón suave rosa/blanco)
## 17. aqualis    - Gomitas de Cola (Botellitas de refresco cian)
## 18. trufino    - Trufino Chocolate Extra Fino (Trufas y bombones marrón)
## 19. rollox     - Rollox Caramelo Tutti Frutti (Rollos arcoíris)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. PAQUETE INDIVIDUAL DE DULCE / CHOCOLATE (FLOW-WRAP / PILLOW PACK)
# =========================================================================
class CandyBagRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones proporcionales estándar de paquete de golosina / chocolate
		var w: float = params.get("width", 0.138)     # 13.8 cm de ancho total (incluyendo sellados)
		var h: float = params.get("height", 0.092)    # 9.2 cm de alto
		var d: float = params.get("depth", 0.022)     # 2.2 cm de grosor inflado central
		var has_collision: bool = params.get("collision", true)

		# Selección de la golosina (por índice 0..19, ID o alias de sabor)
		var candy_param: Variant = params.get("candy", params.get("sweet", params.get("brand", params.get("flavor", 0))))
		var bag_data: Dictionary = ObjectAtlasScript.get_candy_bag_data(candy_param)
		var bag_id: String = bag_data["id"]
		var atlas_key: String = "candy_bags_atlas"

		# Orientación: de pie vertical, o acostado en mostrador/mesa
		var lying_down: bool = params.get("lying_down", params.get("flat", false))
		var yaw_offset: float = float(params.get("rot_y", params.get("yaw", 0.0)))
		var pitch_offset: float = -90.0 if lying_down else float(params.get("pitch", 0.0))
		var roll_offset: float = float(params.get("roll", 0.0))

		var rot_basis := Basis.from_euler(Vector3(deg_to_rad(pitch_offset), deg_to_rad(yaw_offset), deg_to_rad(roll_offset)))
		var bag_t := base_t * Transform3D(rot_basis, Vector3.ZERO)

		# Cálculo de sellado dentado lateral (crimp seals)
		var crimp_ratio: float = 0.095 # ~9.5% de ancho en cada extremo
		var crimp_w: float = w * crimp_ratio
		var body_w: float = w - (crimp_w * 2.0)
		var t_panel: float = 0.002
		var crimp_thickness: float = 0.003 # 3mm de sellado plano prensado
		var half_h: float = h * 0.5

		# 1. CUERPO CENTRAL HINCHADO (Núcleo con color base en bordes superior/inferior)
		var core_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, 0.0))
		builder.add_smart_box(
			core_t,
			Vector3(body_w - t_panel * 2.0, h, d - t_panel * 2.0),
			atlas_key,
			bag_id + "_color",
			0.45,
			0.02,
			has_collision
		)

		# 2. PANEL FRONTAL (+Z): Logotipo, ilustración de dulces y marca
		var front_z: float = (d * 0.5) - (t_panel * 0.5)
		var front_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, front_z))
		builder.add_smart_box(
			front_t,
			Vector3(body_w, h, t_panel),
			atlas_key,
			bag_id + "_body",
			0.40,
			0.04,
			false
		)

		# 3. PANEL TRASERO (-Z): Envoltura posterior
		var back_z: float = (-d * 0.5) + (t_panel * 0.5)
		var back_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, back_z))
		builder.add_smart_box(
			back_t,
			Vector3(body_w, h, t_panel),
			atlas_key,
			bag_id + "_body",
			0.40,
			0.04,
			false
		)

		# 4. SELLADO DENTADO IZQUIERDO (-X): Pestaña prensada termosellada
		var crimp_l_x: float = (-w * 0.5) + (crimp_w * 0.5)
		var crimp_l_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(crimp_l_x, half_h, 0.0))
		builder.add_smart_box(
			crimp_l_t,
			Vector3(crimp_w, h * 0.96, crimp_thickness),
			atlas_key,
			bag_id + "_crimp_left",
			0.35,
			0.08,
			false
		)

		# 5. SELLADO DENTADO DERECHO (+X): Pestaña prensada termosellada
		var crimp_r_x: float = (w * 0.5) - (crimp_w * 0.5)
		var crimp_r_t := bag_t * Transform3D(Basis.IDENTITY, Vector3(crimp_r_x, half_h, 0.0))
		builder.add_smart_box(
			crimp_r_t,
			Vector3(crimp_w, h * 0.96, crimp_thickness),
			atlas_key,
			bag_id + "_crimp_right",
			0.35,
			0.08,
			false
		)


# =========================================================================
# 2. FILA DE DULCES (PARA CAJA DE COBRO / MOSTRADOR / ESTANTE)
# =========================================================================
class CandyBagsRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var candies_list: Array = params.get("candies", [0, 1, 2, 3, 4])
		var spacing: float = params.get("spacing", 0.155)
		var lying_down: bool = params.get("lying_down", false)
		var has_collision: bool = params.get("collision", true)

		var count: int = candies_list.size()
		var total_len: float = float(count - 1) * spacing
		var start_x: float = -total_len * 0.5

		for i in range(count):
			var px: float = start_x + float(i) * spacing
			var offset_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 0.0))
			CandyBagRecipe.build(builder, offset_t, {
				"candy": candies_list[i],
				"lying_down": lying_down,
				"collision": has_collision
			})


# =========================================================================
# 3. EXHIBIDOR MULTINIVEL DE TIENDITA / SUPERMERCADO CON LOS 20 DULCES
# =========================================================================
class CandyBagsDisplayRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var col_spacing: float = params.get("spacing_x", 0.165)
		var tier_h: float = params.get("tier_height", 0.120)
		var tier_d: float = params.get("tier_depth", 0.140)
		var tilt_deg: float = params.get("tilt_degrees", -14.0)
		var has_collision: bool = params.get("collision", true)

		var total_w: float = 5.0 * col_spacing + 0.06

		# 4 escalones blancos estilo exhibidor de mostrador
		# Tier 0: frente y bajo (y=0.00, z=0.00)
		# Tier 1: (y=tier_h, z=-tier_d)
		# Tier 2: (y=tier_h*2, z=-tier_d*2)
		# Tier 3: (y=tier_h*3, z=-tier_d*3)
		for t_idx in range(4):
			var step_top_y: float = float(t_idx) * tier_h
			var step_z: float = -float(t_idx) * tier_d
			var step_height: float = maxf(step_top_y, 0.02)
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

		# 4 filas x 5 columnas de golosinas:
		# Fila 0 (arriba/atrás, Tier 3): 0..4 (Chocorix, Krix, Mellos, Dulcitos, Nuxi)
		# Fila 1 (Tier 2): 5..9 (VitaGom, Cacaoz, Rebotes, Freskito, Brrrt)
		# Fila 2 (Tier 1): 10..14 (Chispy, Frutix, Zelta, Lunetas, Tornado)
		# Fila 3 (abajo/frente, Tier 0): 15..19 (Pipocas, Nubez, Aqualis, Trufino, Rollox)
		for row in range(4):
			var tier_level: int = 3 - row
			var py: float = float(tier_level) * tier_h
			var pz: float = -float(tier_level) * tier_d

			var basis_tilt := Basis(Vector3.RIGHT, deg_to_rad(tilt_deg))

			for col in range(5):
				var candy_idx: int = row * 5 + col
				var px: float = -2.0 * col_spacing + float(col) * col_spacing

				var bag_local_t := Transform3D(basis_tilt, Vector3(px, py, pz))
				var final_t := base_t * bag_local_t

				CandyBagRecipe.build(builder, final_t, {
					"candy": candy_idx,
					"collision": has_collision
				})
