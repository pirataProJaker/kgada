class_name Furniture2SeatingRecipes
extends RefCounted

## Recetas Oficiales: Sofás, Sillones y Sillas de Acento (Furniture 2.0 - Imagen 5)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Mapeo preciso de sub-regiones UV del Atlas Inteligente

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. SOFÁ DAMASCO DORADO 3 PLAZAS (ARMCHAIR_08)
# =========================================================================
class SofaDamaskGoldRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.95)
		var d: float = params.get("depth", 0.85)
		var h: float = params.get("height", 0.88)
		var texture_key: String = params.get("texture_key", "armchair_08")

		var leg_h := 0.12
		var seat_h := 0.42
		var arm_w := 0.16
		var cushion_w := (w - arm_w * 2.0) / 3.0
		var cushion_d := d - 0.22

		# 1. Base inferior con faldón y moldura
		var base_box_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + 0.12, 0.0))
		builder.add_smart_box(base_box_t, Vector3(w - 0.06, 0.24, d - 0.08), texture_key, "satin_base", 0.55, 0.15)

		# 2. 3 Cojines de asiento damasco
		for i in range(3):
			var cx := -w * 0.5 + arm_w + float(i) * cushion_w + cushion_w * 0.5
			var c_pos := Vector3(cx, seat_h, 0.06)
			var c_t := base_t * Transform3D(Basis.IDENTITY, c_pos)
			builder.add_smart_box(c_t, Vector3(cushion_w - 0.02, 0.14, cushion_d), texture_key, "damask", 0.50, 0.15)

		# 3. Respaldo acolchado alto
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.12))
		builder.add_smart_box(back_t, Vector3(w - arm_w * 2.0, back_h, 0.20), texture_key, "damask", 0.50, 0.15)

		# 4. Brazos laterales con curvas en voluta
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, (seat_h + 0.20) * 0.5 + 0.08, 0.02))
			builder.add_smart_box(arm_t, Vector3(arm_w, seat_h + 0.24, d - 0.10), texture_key, "damask", 0.45, 0.20)
			# Frontal tallado del reposabrazos con moldura barroca dorada
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.10, d * 0.5 - 0.04))
			builder.add_smart_box(face_t, Vector3(arm_w - 0.02, 0.38, 0.05), texture_key, "trim_gold", 0.40, 0.30, false)

		# 5. 4 Patas talladas doradas
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.10), leg_h * 0.5, sz * (d * 0.5 - 0.10))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.035, leg_h, texture_key, leg_rect, 0.40, 0.30, false)


# =========================================================================
# 2. SOFÁ FLORAL COTTAGE 2 PLAZAS (ARMCHAIR_06)
# =========================================================================
class SofaFloralCottageRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.50)
		var d: float = params.get("depth", 0.82)
		var h: float = params.get("height", 0.84)
		var texture_key: String = params.get("texture_key", "armchair_06")

		var seat_h := 0.40
		var arm_w := 0.16
		var cushion_w := (w - arm_w * 2.0) / 2.0

		# 1. Zócalo base inferior de madera tallada
		var skirt_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h * 0.5, 0.0))
		builder.add_smart_box(skirt_t, Vector3(w - 0.04, seat_h, d - 0.06), texture_key, "wood_base", 0.60, 0.02)

		# 2. 2 Cojines de asiento esponjosos florales
		for i in range(2):
			var cx := -w * 0.5 + arm_w + float(i) * cushion_w + cushion_w * 0.5
			var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(cx, seat_h + 0.06, 0.05))
			builder.add_smart_box(c_t, Vector3(cushion_w - 0.02, 0.14, d - 0.24), texture_key, "cushion", 0.65, 0.01)

		# 3. Respaldo con flores pastel
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.12))
		builder.add_smart_box(back_t, Vector3(w - arm_w * 2.0, back_h, 0.20), texture_key, "floral", 0.65, 0.01)

		# 4. Brazos acampanados con tela floral
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.12, 0.02))
			builder.add_smart_box(arm_t, Vector3(arm_w, 0.32, d - 0.10), texture_key, "floral", 0.65, 0.01)


# =========================================================================
# 3. SOFÁ DE MADERA MINIMALISTA CON COJINES LISOS (ARMCHAIR_07)
# =========================================================================
class SofaWoodMinimalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.85)
		var d: float = params.get("depth", 0.78)
		var h: float = params.get("height", 0.76)
		var texture_key: String = params.get("texture_key", "armchair_07")

		var leg_h := 0.18
		var frame_thick := 0.05
		var arm_h := h - 0.10

		# 1. Marco perimetral de madera en los laterales (Brazos abiertos)
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - frame_thick * 0.5)
			# Pata delantera
			var f_leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, arm_h * 0.5, d * 0.5 - frame_thick * 0.5))
			builder.add_smart_box(f_leg_t, Vector3(frame_thick, arm_h, frame_thick), texture_key, "wood_frame")
			# Pata trasera
			var b_leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, arm_h * 0.5, -d * 0.5 + frame_thick * 0.5))
			builder.add_smart_box(b_leg_t, Vector3(frame_thick, arm_h, frame_thick), texture_key, "wood_frame")
			# Reposabrazos superior
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, arm_h - frame_thick * 0.5, 0.0))
			builder.add_smart_box(arm_t, Vector3(frame_thick, frame_thick, d), texture_key, "wood_frame")

		# 2. Somier / Base de asiento de madera
		var seat_base_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h, 0.0))
		builder.add_smart_box(seat_base_t, Vector3(w - frame_thick * 2.0, frame_thick, d - 0.08), texture_key, "wood_frame")

		# 3. 3 Cojines de asiento de lino beige
		var cushion_w := (w - frame_thick * 2.0 - 0.04) / 3.0
		var c_thick := 0.12
		var c_d := d - 0.18
		for i in range(3):
			var cx := -(w * 0.5 - frame_thick) + 0.02 + float(i) * cushion_w + cushion_w * 0.5
			var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(cx, leg_h + frame_thick + c_thick * 0.5, 0.05))
			builder.add_smart_box(c_t, Vector3(cushion_w - 0.015, c_thick, c_d), texture_key, "cushion", 0.70, 0.01)

		# 4. 3 Cojines de respaldo inclinados
		var back_c_h := h - leg_h - frame_thick - c_thick - 0.05
		for i in range(3):
			var cx := -(w * 0.5 - frame_thick) + 0.02 + float(i) * cushion_w + cushion_w * 0.5
			var b_t := base_t * Transform3D(Basis.IDENTITY, Vector3(cx, leg_h + frame_thick + c_thick + back_c_h * 0.5, -d * 0.5 + 0.12))
			builder.add_smart_box(b_t, Vector3(cushion_w - 0.02, back_c_h, 0.14), texture_key, "cushion", 0.70, 0.01)


# =========================================================================
# 4. SOFÁ CHESTERFIELD 3 PLAZAS CUERO GRANATE (ARMCHAIR_03)
# =========================================================================
class SofaChesterfieldRedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 2.10)
		var d: float = params.get("depth", 0.88)
		var h: float = params.get("height", 0.78)
		var texture_key: String = params.get("texture_key", "armchair_03")

		var bun_h := 0.08
		var seat_h := 0.40
		var arm_w := 0.22
		var usable_w := w - arm_w * 2.0
		var cushion_w := usable_w / 3.0

		# 1. Base inferior con cuero capitoné
		var base_t_pos := Vector3(0.0, bun_h + 0.10, 0.0)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, base_t_pos), Vector3(w - 0.08, 0.20, d - 0.08), texture_key, "tufted_back", 0.45, 0.10)

		# 2. 3 Cojines profundos de cuero suave
		for i in range(3):
			var cx := -w * 0.5 + arm_w + float(i) * cushion_w + cushion_w * 0.5
			var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(cx, seat_h, 0.08))
			builder.add_smart_box(c_t, Vector3(cushion_w - 0.02, 0.15, d - 0.26), texture_key, "cushion", 0.40, 0.10)

		# 3. Respaldo capitoné continuo
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.16))
		builder.add_smart_box(back_t, Vector3(usable_w + 0.04, back_h, 0.24), texture_key, "tufted_back", 0.45, 0.10)

		# 4. Brazos enrollados en voluta
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, bun_h + (h - bun_h) * 0.5, 0.02))
			builder.add_smart_box(arm_t, Vector3(arm_w, h - bun_h, d - 0.06), texture_key, "arm_scroll", 0.40, 0.10)

		# 5. 4 Patas esféricas torneadas
		var foot_rect := ObjectAtlasScript.get_region(texture_key, "bun_foot")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.12), bun_h * 0.5, sz * (d * 0.5 - 0.12)))
				builder.add_cylinder(foot_t, 0.045, bun_h, texture_key, foot_rect, 0.50, 0.05, false)


# =========================================================================
# 5. SILLÓN INDIVIDUAL CHESTERFIELD 1 PLAZA (ARMCHAIR_04)
# =========================================================================
class ArmchairChesterfieldRedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.05)
		var d: float = params.get("depth", 0.88)
		var h: float = params.get("height", 0.78)
		var texture_key: String = params.get("texture_key", "armchair_04")

		var bun_h := 0.08
		var seat_h := 0.40
		var arm_w := 0.22
		var cushion_w := w - arm_w * 2.0

		# 1. Base inferior capitoné
		var base_t_pos := Vector3(0.0, bun_h + 0.10, 0.0)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, base_t_pos), Vector3(w - 0.08, 0.20, d - 0.08), texture_key, "tufted_back", 0.45, 0.10)

		# 2. Cojín único de asiento
		var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.08))
		builder.add_smart_box(c_t, Vector3(cushion_w, 0.15, d - 0.26), texture_key, "cushion", 0.40, 0.10)

		# 3. Respaldo capitoné
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.16))
		builder.add_smart_box(back_t, Vector3(cushion_w + 0.04, back_h, 0.24), texture_key, "tufted_back", 0.45, 0.10)

		# 4. Brazos en voluta
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, bun_h + (h - bun_h) * 0.5, 0.02))
			builder.add_smart_box(arm_t, Vector3(arm_w, h - bun_h, d - 0.06), texture_key, "arm_scroll", 0.40, 0.10)

		# 5. Patas
		var foot_rect := ObjectAtlasScript.get_region(texture_key, "bun_foot")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.10), bun_h * 0.5, sz * (d * 0.5 - 0.10)))
				builder.add_cylinder(foot_t, 0.045, bun_h, texture_key, foot_rect, 0.50, 0.05, false)


# =========================================================================
# 6. SILLÓN OREJERO MARRÓN VINTAGE (ARMCHAIR)
# =========================================================================
class ArmchairWingbackLeatherRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.86)
		var d: float = params.get("depth", 0.82)
		var h: float = params.get("height", 0.98)
		var texture_key: String = params.get("texture_key", "armchair")

		var leg_h := 0.14
		var seat_h := 0.42
		var arm_w := 0.14

		# 1. Base del asiento
		var seat_base_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + 0.08, 0.0))
		builder.add_smart_box(seat_base_t, Vector3(w - 0.06, 0.16, d - 0.08), texture_key, "tufted_back", 0.45, 0.10)

		# 2. Cojín de cuero desgastado
		var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.04, 0.06))
		builder.add_smart_box(c_t, Vector3(w - arm_w * 2.0 - 0.02, 0.12, d - 0.24), texture_key, "cushion", 0.40, 0.10)

		# 3. Respaldo alto capitoné
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.10))
		builder.add_smart_box(back_t, Vector3(w - arm_w * 2.0, back_h, 0.16), texture_key, "tufted_back", 0.45, 0.10)

		# 4. Orejeras laterales (*wings*)
		for side: float in [-1.0, 1.0]:
			var wing_x := side * (w * 0.5 - arm_w * 0.5)
			var wing_t := base_t * Transform3D(Basis.IDENTITY, Vector3(wing_x, h - 0.20, -d * 0.5 + 0.22))
			builder.add_smart_box(wing_t, Vector3(0.08, 0.36, 0.24), texture_key, "arm_roll", 0.45, 0.10)

		# 5. Brazos acolchados
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.10, 0.02))
			builder.add_smart_box(arm_t, Vector3(arm_w, 0.28, d - 0.14), texture_key, "arm_roll", 0.45, 0.10)

		# 6. 4 Patas de madera
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.03, leg_h, texture_key, leg_rect, 0.55, 0.02, false)


# =========================================================================
# 7. SILLÓN CAPITONÉ GRIS MARENGO (ARMCHAIR_01)
# =========================================================================
class ArmchairTuftedCharcoalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.84)
		var d: float = params.get("depth", 0.80)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "armchair_01")

		var leg_h := 0.12
		var seat_h := 0.42
		var arm_w := 0.14

		# 1. Base y asiento
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.04))
		builder.add_smart_box(seat_t, Vector3(w - arm_w * 2.0, 0.16, d - 0.22), texture_key, "cushion", 0.50, 0.05)

		# 2. Respaldo capitoné
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.12))
		builder.add_smart_box(back_t, Vector3(w - arm_w * 2.0, back_h, 0.18), texture_key, "tufted_back", 0.55, 0.05)

		# 3. Brazos cuadrados
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.10, 0.0))
			builder.add_smart_box(arm_t, Vector3(arm_w, 0.32, d - 0.12), texture_key, "arm", 0.50, 0.05)

		# 4. 4 Patas
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "arm")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.028, leg_h, texture_key, leg_rect, 0.50, 0.10, false)


# =========================================================================
# 8. SILLÓN CAPITONÉ AZUL CIELO (ARMCHAIR_02)
# =========================================================================
class ArmchairTuftedSkyBlueRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.84)
		var d: float = params.get("depth", 0.80)
		var h: float = params.get("height", 0.92)
		var texture_key: String = params.get("texture_key", "armchair_02")

		var leg_h := 0.12
		var seat_h := 0.42
		var arm_w := 0.14

		# 1. Base y asiento azul
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.04))
		builder.add_smart_box(seat_t, Vector3(w - arm_w * 2.0, 0.16, d - 0.22), texture_key, "cushion", 0.45, 0.08)

		# 2. Respaldo alto capitoné azul
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.12))
		builder.add_smart_box(back_t, Vector3(w - arm_w * 2.0, back_h, 0.18), texture_key, "tufted_back", 0.50, 0.08)

		# 3. Brazos con tachuelas plateadas
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.10, 0.0))
			builder.add_smart_box(arm_t, Vector3(arm_w, 0.32, d - 0.12), texture_key, "studded_arm", 0.40, 0.20)

		# 4. Patas oscuras
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "studded_arm")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.028, leg_h, texture_key, leg_rect, 0.40, 0.10, false)


# =========================================================================
# 9. SILLÓN TERCIOPELO AMARILLO MOSTAZA (ARMCHAIR_05)
# =========================================================================
class ArmchairVelvetMustardRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.88)
		var d: float = params.get("depth", 0.84)
		var h: float = params.get("height", 0.82)
		var texture_key: String = params.get("texture_key", "armchair_05")

		var leg_h := 0.10
		var seat_h := 0.38
		var arm_w := 0.16

		# 1. Base y asiento mostaza
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.04))
		builder.add_smart_box(seat_t, Vector3(w - arm_w * 2.0, 0.18, d - 0.22), texture_key, "cushion", 0.70, 0.02)

		# 2. Respaldo capitoné envolvente
		var back_h := h - seat_h
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, -d * 0.5 + 0.14))
		builder.add_smart_box(back_t, Vector3(w - arm_w * 2.0, back_h, 0.22), texture_key, "tufted_back", 0.70, 0.02)

		# 3. Brazos anchos
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.08, 0.0))
			builder.add_smart_box(arm_t, Vector3(arm_w, 0.30, d - 0.10), texture_key, "arm", 0.70, 0.02)

		# 4. Patas
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "arm")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.03, leg_h, texture_key, leg_rect, 0.40, 0.10, false)


# =========================================================================
# 10. SILLA DE COMEDOR TAPIZADA RECTA (CHAIR_02)
# =========================================================================
class ChairDiningCreamRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.46)
		var d: float = params.get("depth", 0.48)
		var h: float = params.get("height", 0.92)
		var texture_key: String = params.get("texture_key", "chair_02")

		var seat_h := 0.46
		var leg_sz := 0.035

		# 1. 4 Patas de madera
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var px := sx * (w * 0.5 - leg_sz * 0.5 - 0.01)
				var pz := sz * (d * 0.5 - leg_sz * 0.5 - 0.01)
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, seat_h * 0.5, pz))
				builder.add_smart_box(leg_t, Vector3(leg_sz, seat_h, leg_sz), texture_key, "wood_frame")

		# 2. Asiento acolchado crema de lunares
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.025, 0.0))
		builder.add_smart_box(seat_t, Vector3(w, 0.05, d), texture_key, "polka_seat", 0.60, 0.02)

		# 3. Respaldo vertical con marco y centro tapizado
		var back_h := h - seat_h - 0.05
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.05 + back_h * 0.5, -d * 0.5 + 0.02))
		builder.add_smart_box(back_t, Vector3(w - 0.04, back_h, 0.03), texture_key, "polka_back", 0.60, 0.02)


# =========================================================================
# 11. SILLA CLÁSICA BARROCA RESPALDO OVALADO (CHAIR_01)
# =========================================================================
class ChairBaroqueOvalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.50)
		var d: float = params.get("depth", 0.50)
		var h: float = params.get("height", 0.96)
		var texture_key: String = params.get("texture_key", "chair_01")

		var seat_h := 0.46
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "carved_wood")

		# 1. 4 Patas doradas/talladas
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var px := sx * (w * 0.5 - 0.04)
				var pz := sz * (d * 0.5 - 0.04)
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, seat_h * 0.5, pz))
				builder.add_cylinder(leg_t, 0.024, seat_h, texture_key, leg_rect, 0.50, 0.05, false)

		# 2. Asiento redondeado con tela adamascada
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.03, 0.0))
		builder.add_smart_box(seat_t, Vector3(w, 0.06, d), texture_key, "damask_seat", 0.55, 0.05)

		# 3. Respaldo ovalado medallón
		var back_h := 0.45
		var back_w := 0.40
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.06 + back_h * 0.5 + 0.04, -d * 0.5 + 0.04))
		builder.add_smart_box(back_t, Vector3(back_w, back_h, 0.035), texture_key, "damask_back", 0.55, 0.05)


# =========================================================================
# 12. SILLÓN LUIS XV TOILE DE JOUY AZUL (CHAIR)
# =========================================================================
class ArmchairLouisXVBlueRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.62)
		var d: float = params.get("depth", 0.58)
		var h: float = params.get("height", 0.94)
		var texture_key: String = params.get("texture_key", "chair")

		var seat_h := 0.44
		var wood_rect := ObjectAtlasScript.get_region(texture_key, "carved_wood")

		# 1. 4 Patas estilo cabriolé
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.05), seat_h * 0.5, sz * (d * 0.5 - 0.05)))
				builder.add_cylinder(leg_t, 0.025, seat_h, texture_key, wood_rect, 0.50, 0.05, false)

		# 2. Asiento azul Toile de Jouy
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.03, 0.02))
		builder.add_smart_box(seat_t, Vector3(w - 0.06, 0.07, d - 0.06), texture_key, "toile_seat", 0.60, 0.02)

		# 3. Respaldo ovalado con marco y tapizado azul
		var back_h := 0.44
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.07 + back_h * 0.5, -d * 0.5 + 0.05))
		builder.add_smart_box(back_t, Vector3(w - 0.12, back_h, 0.035), texture_key, "toile_back", 0.60, 0.02)

		# 4. Brazos curvados con coderas acolchadas
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - 0.04)
			# Soporte vertical curvo
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.14, 0.08))
			builder.add_cylinder(post_t, 0.018, 0.24, texture_key, wood_rect, 0.50, 0.05, false)
			# Codera acolchada azul
			var pad_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.26, -0.02))
			builder.add_smart_box(pad_t, Vector3(0.04, 0.03, 0.18), texture_key, "toile_seat", 0.60, 0.02)
