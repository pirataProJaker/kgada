class_name SandbagsRecipes
extends RefCounted

## Catálogo de Recetas Paramétricas de Sacos / Costales de Arena (Play Sector X)
## Arquitectura: +0 Draw Calls (Vinculado 100% al Atlas Inteligente y al primitivo 'pillow')
##
## Diseñado para:
## 1. Costales individuales con 20 variaciones de arpillera y lona militar
##    (desgastes, rasgaduras, remiendos, orificios y tela limpia).
## 2. Parapetos, barricadas de trinchera y retenes militares de costales apilados.
## 3. Emplazamientos tácticos en 'L' o 'U' para casetas y puestos de control.

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. COSTAL / SACO DE ARENA INDIVIDUAL
# =========================================================================
class SandbagRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones estándar de costal de arena militar de 25-30 kg (lleno y asentado por gravedad):
		var length: float = params.get("length", params.get("width", 0.58))    # 58 cm de largo (X)
		var height: float = params.get("height", 0.14)                         # 14 cm de espesor aplastado (Y)
		var depth: float = params.get("depth", 0.34)                           # 34 cm de ancho transversal (Z)
		var has_collision: bool = params.get("collision", true)
		var smooth: bool = params.get("smooth", true)                          # Normales suaves infladas

		# Variación de textura (0..19 o -1 para selección pseudo-aleatoria):
		var variation: int = int(params.get("variation", params.get("tile", params.get("skin", -1))))
		if variation < 0:
			# Determinista por posición para consistencia de guardado
			var seed_val := int(absf(base_t.origin.x * 37.0 + base_t.origin.y * 59.0 + base_t.origin.z * 73.0))
			variation = seed_val % 20
		else:
			variation = clampi(variation, 0, 19)

		var rot_y_deg: float = float(params.get("rot_y", params.get("yaw", 0.0)))
		var rot_basis := Basis(Vector3.UP, deg_to_rad(rot_y_deg))
		var sack_t := base_t * Transform3D(rot_basis, Vector3.ZERO)

		# CUERPO INFLADO Y ASENTADO DEL COSTAL (Primitiva 'pillow' pura rotada en plano horizontal)
		# En 'pillow', el ecuador está en Z=0 con meseta en +Z y -Z.
		# Al rotar 90° sobre X, la meseta queda arriba (+Y) y abajo (-Y),
		# con los 4 bordes adelgazándose en cuña hacia el perímetro.
		var body_half_y := height * 0.5
		var center_pos := Vector3(0.0, body_half_y, 0.0)
		var orient_basis := Basis(Vector3.RIGHT, deg_to_rad(-90.0))
		var pillow_t := sack_t * Transform3D(orient_basis, center_pos)

		var atlas_key := "sandbags_atlas"
		var region_key := "sandbag_%d" % variation

		# Escalado del pillow: X = largo, Y = profundidad, Z = espesor vertical
		builder.add_smart_pillow(
			pillow_t,
			Vector3(length, depth, height),
			atlas_key,
			region_key,
			0.88, # Rugosidad áspera de tejido de yute / arpillera militar
			0.02, # Acabado textil sin reflejo metálico
			has_collision,
			smooth
		)


# =========================================================================
# 2. BARRICADA MILITAR DE COSTALES APILADOS (PARAPETO / TRINCHERA)
# =========================================================================
class SandbagBarricadeRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var length_bags: int = int(params.get("length_bags", 4))      # Número de costales a lo largo (~2.3m para 4)
		var height_tiers: int = int(params.get("height_tiers", 3))    # Niveles de altura (3 niveles = ~0.42m, 4 = ~0.56m)
		var double_row: bool = params.get("double_row", true)         # Hilera doble para parapeto grueso militar
		var has_collision: bool = params.get("collision", true)

		var bag_l: float = 0.58
		var bag_h: float = 0.135 # Ligeramente compactados por peso
		var bag_d: float = 0.32

		var step_x := bag_l * 0.94 # Ligero solapamiento entre costales
		var row_spacing := bag_d * 0.88

		var start_x := -float(length_bags - 1) * step_x * 0.5
		var tier_offset_x := 0.0

		for tier in range(height_tiers):
			var ty := float(tier) * bag_h
			# Entrelazado tipo ladrillo (desplazamiento de medio costal en niveles impares)
			tier_offset_x = (bag_l * 0.45) if (tier % 2 == 1) else 0.0

			var rows := [-row_spacing * 0.5, row_spacing * 0.5] if double_row else [0.0]

			for r_z in rows:
				for i in range(length_bags):
					var px := start_x + float(i) * step_x + tier_offset_x
					var pos := Vector3(px, ty, r_z)

					# Variación de textura pseudo-aleatoria consistente
					var var_idx := (i * 7 + tier * 11 + int(absf(r_z) * 13)) % 20

					# Ligera rotación sutil orgánica (±2 grados) para romper la rigidez perfecta
					var jitter_yaw := sin(float(i * 3 + tier * 5)) * 2.5

					var bag_pos_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(jitter_yaw)), pos)

					SandbagRecipe.build(builder, bag_pos_t, {
						"length": bag_l,
						"height": bag_h,
						"depth": bag_d,
						"variation": var_idx,
						"collision": has_collision
					})


# =========================================================================
# 3. EMPLAZAMIENTO EN 'L' O 'U' PARA RETÉN / CASETA MILITAR
# =========================================================================
class SandbagBunkerRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var front_length: int = int(params.get("front_length", 4)) # Costales en pared frontal
		var side_length: int = int(params.get("side_length", 3))   # Costales en muros laterales
		var height_tiers: int = int(params.get("height_tiers", 4))  # Altura de costales
		var has_collision: bool = params.get("collision", true)

		var bag_l: float = 0.58
		var step_x := bag_l * 0.94
		var half_front := float(front_length) * step_x * 0.5

		# 1. Pared Frontal
		SandbagBarricadeRecipe.build(builder, base_t, {
			"length_bags": front_length,
			"height_tiers": height_tiers,
			"double_row": true,
			"collision": has_collision
		})

		# 2. Muro Lateral Izquierdo (Rotado 90°)
		var left_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-half_front, 0.0, -float(side_length) * step_x * 0.45))
		SandbagBarricadeRecipe.build(builder, left_t, {
			"length_bags": side_length,
			"height_tiers": height_tiers,
			"double_row": true,
			"collision": has_collision
		})

		# 3. Muro Lateral Derecho (Rotado 90°)
		var right_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(half_front, 0.0, -float(side_length) * step_x * 0.45))
		SandbagBarricadeRecipe.build(builder, right_t, {
			"length_bags": side_length,
			"height_tiers": height_tiers,
			"double_row": true,
			"collision": has_collision
		})
