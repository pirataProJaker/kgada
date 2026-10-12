class_name Furniture2SeatingRecipes
extends RefCounted

## Recetas Oficiales: Sofás, Sillones y Sillas de Acento (Colección Furniture 2.0)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Acabados PBR calibrados: telas, linos, terciopelos y cueros 100% mate (metálico = 0.0).

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. SOFÁ DAMASCO DORADO 3 PLAZAS (ARMCHAIR_08)
# =========================================================================
class SofaDamaskGoldRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 2.10)
		var d: float = params.get("depth", 0.86)
		var h: float = params.get("height", 0.88)
		var texture_key: String = params.get("texture_key", "armchair_08")

		var leg_h := 0.12
		var apron_h := 0.16
		var arm_w := 0.18
		var arm_h := 0.68
		var usable_w := w - arm_w * 2.0
		var cushion_w := usable_w / 3.0
		var cushion_d := d - 0.22

		# 1. Cuatro patas talladas doradas mate
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.10), leg_h * 0.5, sz * (d * 0.5 - 0.10))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.035, leg_h, texture_key, leg_rect, 0.70, 0.0, false)

		# 2. Zócalo base / faldón con moldura dorada en el frente
		var apron_y := leg_h + apron_h * 0.5
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0))
		builder.add_panel_box(apron_t, Vector3(w - 0.04, apron_h, d - 0.06), texture_key, "trim_gold", "satin_base", 0.65, 0.0)

		# 3. Tres cojines de asiento damasco mate
		for i in range(3):
			var cx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var c_pos := Vector3(cx, leg_h + apron_h + 0.06, 0.04)
			var c_t := base_t * Transform3D(Basis.IDENTITY, c_pos)
			builder.add_top_panel_box(c_t, Vector3(cushion_w - 0.02, 0.12, cushion_d), texture_key, "damask", "damask", 0.88, 0.0)

		# 4. Respaldo alto acolchado en damasco brocado mate (3 paneles continuos)
		var back_h := h - (leg_h + apron_h)
		var back_z := -d * 0.5 + 0.10
		var back_y := leg_h + apron_h + back_h * 0.5
		for i in range(3):
			var bx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(bx, back_y, back_z))
			builder.add_panel_box(back_t, Vector3(cushion_w - 0.01, back_h, 0.18), texture_key, "damask", "satin_base", 0.88, 0.0)

		# Moldura superior dorada del respaldo
		var crest_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.02, back_z + 0.04))
		builder.add_smart_box(crest_t, Vector3(usable_w, 0.04, 0.10), texture_key, "trim_gold", 0.65, 0.0, false)

		# 5. Brazos acolchados con satén mate y frente tallado
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := arm_h - leg_h - roll_radius
			var arm_body_y := leg_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "satin_base", 0.85, 0.0)

			var roll_y := leg_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, ObjectAtlasScript.get_region(texture_key, "satin_base"), 0.85, 0.0, false)

			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 - 0.01))
			builder.add_panel_box(face_t, Vector3(arm_w, arm_h - leg_h, 0.03), texture_key, "trim_gold", "satin_base", 0.65, 0.0, false)


# =========================================================================
# 2. SOFÁ FLORAL COTTAGE 2 PLAZAS (ARMCHAIR_06)
# =========================================================================
class SofaFloralCottageRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.62)
		var d: float = params.get("depth", 0.84)
		var h: float = params.get("height", 0.85)
		var texture_key: String = params.get("texture_key", "armchair_06")

		var leg_h := 0.10
		var apron_h := 0.16
		var arm_w := 0.18
		var arm_h := 0.64
		var usable_w := w - arm_w * 2.0
		var cushion_w := usable_w / 2.0
		var cushion_d := d - 0.22

		# 1. Patas y faldón de madera tallada mate
		var wood_rect := ObjectAtlasScript.get_region(texture_key, "wood_base")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.09), leg_h * 0.5, sz * (d * 0.5 - 0.09))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.032, leg_h, texture_key, wood_rect, 0.70, 0.0, false)

		var apron_y := leg_h + apron_h * 0.5
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0))
		builder.add_panel_box(apron_t, Vector3(w - 0.04, apron_h, d - 0.06), texture_key, "wood_base", "wood_base", 0.70, 0.0)

		# 2. Dos cojines de asiento estampados florales mate
		for i in range(2):
			var cx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var c_pos := Vector3(cx, leg_h + apron_h + 0.06, 0.04)
			var c_t := base_t * Transform3D(Basis.IDENTITY, c_pos)
			builder.add_top_panel_box(c_t, Vector3(cushion_w - 0.02, 0.13, cushion_d), texture_key, "cushion", "floral", 0.88, 0.0)

		# 3. Respaldo acolchado floral en 2 secciones
		var back_h := h - (leg_h + apron_h)
		var back_z := -d * 0.5 + 0.10
		var back_y := leg_h + apron_h + back_h * 0.5
		for i in range(2):
			var bx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(bx, back_y, back_z))
			builder.add_panel_box(back_t, Vector3(cushion_w - 0.02, back_h, 0.18), texture_key, "cushion", "floral", 0.88, 0.0)

		# 4. Brazos redondeados con tela floral mate
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		var arm_roll_rect := ObjectAtlasScript.get_region(texture_key, "arm_roll")
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := arm_h - leg_h - roll_radius
			var arm_body_y := leg_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "floral", 0.88, 0.0)

			var roll_y := leg_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, arm_roll_rect, 0.88, 0.0, false)

			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 - 0.01))
			builder.add_panel_box(face_t, Vector3(arm_w, arm_h - leg_h, 0.03), texture_key, "floral", "floral", 0.88, 0.0, false)


# =========================================================================
# 3. SOFÁ DE MADERA MINIMALISTA CON COJINES DE LINO (ARMCHAIR_07)
# =========================================================================
class SofaWoodMinimalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.90)
		var d: float = params.get("depth", 0.80)
		var h: float = params.get("height", 0.78)
		var texture_key: String = params.get("texture_key", "armchair_07")

		var leg_h := 0.20
		var frame_thick := 0.045
		var arm_h := 0.60
		var usable_w := w - frame_thick * 2.0
		var cushion_w := usable_w / 3.0
		var cushion_d := d - 0.18

		# 1. Estructura lateral de madera de roble visto (Brazos abiertos en marco)
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - frame_thick * 0.5)
			var f_leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, arm_h * 0.5, d * 0.5 - frame_thick * 0.5 - 0.02))
			builder.add_smart_box(f_leg_t, Vector3(frame_thick, arm_h, frame_thick), texture_key, "wood_frame", 0.70, 0.0)
			var b_leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, arm_h * 0.5, -d * 0.5 + frame_thick * 0.5 + 0.02))
			builder.add_smart_box(b_leg_t, Vector3(frame_thick, arm_h, frame_thick), texture_key, "wood_frame", 0.70, 0.0)
			var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, arm_h - frame_thick * 0.5, 0.0))
			builder.add_smart_box(arm_t, Vector3(frame_thick * 1.4, frame_thick, d - 0.04), texture_key, "wood_frame", 0.70, 0.0)

		# 2. Somier / marco inferior de soporte
		var seat_base_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h, 0.0))
		builder.add_smart_box(seat_base_t, Vector3(usable_w, frame_thick, d - 0.06), texture_key, "wood_frame", 0.70, 0.0)

		# 3. Respaldo trasero de roble (tablero soporte)
		var back_frame_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + (h - leg_h) * 0.5, -d * 0.5 + 0.06))
		builder.add_smart_box(back_frame_t, Vector3(usable_w, h - leg_h, frame_thick), texture_key, "wood_back", 0.70, 0.0)

		# 4. Tres cojines de asiento en lino marfil mate
		var c_thick := 0.12
		for i in range(3):
			var cx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(cx, leg_h + frame_thick + c_thick * 0.5, 0.04))
			builder.add_smart_box(c_t, Vector3(cushion_w - 0.02, c_thick, cushion_d), texture_key, "cushion", 0.90, 0.0)

		# 5. Tres cojines de respaldo en lino mate
		var back_c_h := h - (leg_h + frame_thick + c_thick) - 0.04
		for i in range(3):
			var cx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var b_t := base_t * Transform3D(Basis.IDENTITY, Vector3(cx, leg_h + frame_thick + c_thick + back_c_h * 0.5, -d * 0.5 + 0.14))
			builder.add_smart_box(b_t, Vector3(cushion_w - 0.02, back_c_h, 0.12), texture_key, "cushion", 0.90, 0.0)


# =========================================================================
# 4. SOFÁ CHESTERFIELD 3 PLAZAS CUERO GRANATE (ARMCHAIR_03)
# =========================================================================
class SofaChesterfieldRedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 2.15)
		var d: float = params.get("depth", 0.88)
		var h: float = params.get("height", 0.80)
		var texture_key: String = params.get("texture_key", "armchair_03")

		var foot_h := 0.08
		var apron_h := 0.16
		var arm_w := 0.22
		var usable_w := w - arm_w * 2.0
		var cushion_w := usable_w / 3.0
		var cushion_d := d - 0.24

		# 1. Cuatro patas torneadas de madera oscura mate
		var foot_rect := ObjectAtlasScript.get_region(texture_key, "bun_foot")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.12), foot_h * 0.5, sz * (d * 0.5 - 0.12)))
				builder.add_cylinder(foot_t, 0.045, foot_h, texture_key, foot_rect, 0.70, 0.0, false)

		# 2. Zócalo inferior frontal capitoné dividido en 3 secciones
		var apron_y := foot_h + apron_h * 0.5
		var base_box_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, -0.02))
		builder.add_smart_box(base_box_t, Vector3(w - 0.06, apron_h, d - 0.08), texture_key, "smooth_leather", 0.78, 0.0)

		for i in range(3):
			var bx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var ap_t := base_t * Transform3D(Basis.IDENTITY, Vector3(bx, apron_y, d * 0.5 - 0.04))
			builder.add_panel_box(ap_t, Vector3(cushion_w - 0.02, apron_h, 0.04), texture_key, "tufted_back", "smooth_leather", 0.78, 0.0, false)

		# 3. Tres cojines profundos de cuero suave
		for i in range(3):
			var cx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var c_pos := Vector3(cx, foot_h + apron_h + 0.06, 0.06)
			var c_t := base_t * Transform3D(Basis.IDENTITY, c_pos)
			builder.add_top_panel_box(c_t, Vector3(cushion_w - 0.02, 0.13, cushion_d), texture_key, "cushion", "smooth_leather", 0.78, 0.0)

		# 4. Respaldo continuo capitoné en 3 secciones
		var back_h := h - (foot_h + apron_h)
		var back_z := -d * 0.5 + 0.14
		var back_y := foot_h + apron_h + back_h * 0.5
		for i in range(3):
			var bx := -usable_w * 0.5 + float(i) * cushion_w + cushion_w * 0.5
			var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(bx, back_y, back_z))
			builder.add_panel_box(back_t, Vector3(cushion_w - 0.02, back_h, 0.22), texture_key, "tufted_back", "smooth_leather", 0.78, 0.0)

		# Rollo superior del respaldo
		var crest_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.04, back_z + 0.04))
		builder.add_smart_box(crest_t, Vector3(usable_w, 0.08, 0.12), texture_key, "smooth_leather", 0.78, 0.0, false)

		# 5. Brazos enrollados Chesterfield
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		var leather_rect := ObjectAtlasScript.get_region(texture_key, "smooth_leather")
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := h - foot_h - roll_radius
			var arm_body_y := foot_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "smooth_leather", 0.78, 0.0)

			var roll_y := foot_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, leather_rect, 0.78, 0.0, false)

			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, foot_h + (h - foot_h) * 0.5, d * 0.5 - 0.01))
			builder.add_smart_box(face_t, Vector3(arm_w, h - foot_h, 0.03), texture_key, "smooth_leather", 0.78, 0.0, false)


# =========================================================================
# 5. SILLÓN INDIVIDUAL CHESTERFIELD 1 PLAZA (ARMCHAIR_04)
# =========================================================================
class ArmchairChesterfieldRedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.06)
		var d: float = params.get("depth", 0.88)
		var h: float = params.get("height", 0.80)
		var texture_key: String = params.get("texture_key", "armchair_04")

		var foot_h := 0.08
		var apron_h := 0.16
		var arm_w := 0.22
		var cushion_w := w - arm_w * 2.0
		var cushion_d := d - 0.24

		# 1. Cuatro patas torneadas
		var foot_rect := ObjectAtlasScript.get_region(texture_key, "bun_foot")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.10), foot_h * 0.5, sz * (d * 0.5 - 0.10)))
				builder.add_cylinder(foot_t, 0.045, foot_h, texture_key, foot_rect, 0.70, 0.0, false)

		# 2. Zócalo frontal capitoné
		var apron_y := foot_h + apron_h * 0.5
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0))
		builder.add_panel_box(apron_t, Vector3(w - 0.06, apron_h, d - 0.08), texture_key, "tufted_back", "smooth_leather", 0.78, 0.0)

		# 3. Cojín único de asiento
		var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, foot_h + apron_h + 0.06, 0.06))
		builder.add_top_panel_box(c_t, Vector3(cushion_w, 0.13, cushion_d), texture_key, "cushion", "smooth_leather", 0.78, 0.0)

		# 4. Respaldo capitoné
		var back_h := h - (foot_h + apron_h)
		var back_z := -d * 0.5 + 0.14
		var back_y := foot_h + apron_h + back_h * 0.5
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z))
		builder.add_panel_box(back_t, Vector3(cushion_w, back_h, 0.22), texture_key, "tufted_back", "smooth_leather", 0.78, 0.0)

		# Rollo superior
		var crest_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.04, back_z + 0.04))
		builder.add_smart_box(crest_t, Vector3(cushion_w, 0.08, 0.12), texture_key, "smooth_leather", 0.78, 0.0, false)

		# 5. Brazos enrollados en voluta
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		var leather_rect := ObjectAtlasScript.get_region(texture_key, "smooth_leather")
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := h - foot_h - roll_radius
			var arm_body_y := foot_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "smooth_leather", 0.78, 0.0)

			var roll_y := foot_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, leather_rect, 0.78, 0.0, false)

			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, foot_h + (h - foot_h) * 0.5, d * 0.5 - 0.01))
			builder.add_smart_box(face_t, Vector3(arm_w, h - foot_h, 0.03), texture_key, "smooth_leather", 0.78, 0.0, false)


# =========================================================================
# 6. SILLÓN OREJERO MARRÓN VINTAGE (ARMCHAIR)
# =========================================================================
class ArmchairWingbackLeatherRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.88)
		var d: float = params.get("depth", 0.84)
		var h: float = params.get("height", 1.02)
		var texture_key: String = params.get("texture_key", "armchair")

		var leg_h := 0.14
		var apron_h := 0.14
		var arm_w := 0.15
		var arm_h := 0.62
		var cushion_w := w - arm_w * 2.0
		var cushion_d := d - 0.22

		# 1. Cuatro patas cónicas de madera oscura
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.032, leg_h, texture_key, leg_rect, 0.70, 0.0, false)

		# 2. Base y faldón de cuero envejecido
		var apron_y := leg_h + apron_h * 0.5
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0))
		builder.add_smart_box(apron_t, Vector3(w - 0.06, apron_h, d - 0.06), texture_key, "smooth_leather", 0.78, 0.0)

		# 3. Cojín de cuero grueso desgastado
		var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + apron_h + 0.06, 0.05))
		builder.add_top_panel_box(c_t, Vector3(cushion_w, 0.12, cushion_d), texture_key, "cushion", "smooth_leather", 0.78, 0.0)

		# 4. Respaldo alto capitoné
		var back_h := h - (leg_h + apron_h)
		var back_z := -d * 0.5 + 0.10
		var back_y := leg_h + apron_h + back_h * 0.5
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z))
		builder.add_panel_box(back_t, Vector3(cushion_w, back_h, 0.16), texture_key, "tufted_back", "smooth_leather", 0.78, 0.0)

		# 5. Orejeras laterales curvadas superiores ("Wings")
		var wing_h := 0.38
		var wing_w := 0.06
		var wing_d := 0.22
		var wing_y := h - wing_h * 0.5 - 0.02
		for side: float in [-1.0, 1.0]:
			var wing_x := side * (cushion_w * 0.5 + wing_w * 0.5 - 0.01)
			var wing_rot := deg_to_rad(-side * 14.0)
			var wing_basis := Basis(Vector3.UP, wing_rot)
			var wing_t := base_t * Transform3D(wing_basis, Vector3(wing_x, wing_y, back_z + wing_d * 0.5 + 0.04))
			builder.add_panel_box(wing_t, Vector3(wing_w, wing_h, wing_d), texture_key, "tufted_back", "smooth_leather", 0.78, 0.0)

		# 6. Brazos redondeados con frente de cuero sólido
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		var leather_rect := ObjectAtlasScript.get_region(texture_key, "smooth_leather")
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := arm_h - leg_h - roll_radius
			var arm_body_y := leg_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "smooth_leather", 0.78, 0.0)

			var roll_y := leg_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, leather_rect, 0.78, 0.0, false)

			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 - 0.01))
			builder.add_smart_box(face_t, Vector3(arm_w, arm_h - leg_h, 0.03), texture_key, "smooth_leather", 0.78, 0.0, false)


# =========================================================================
# 7. SILLÓN CAPITONÉ GRIS MARENGO (ARMCHAIR_01)
# =========================================================================
class ArmchairTuftedCharcoalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.86)
		var d: float = params.get("depth", 0.82)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "armchair_01")

		var leg_h := 0.14
		var apron_h := 0.14
		var arm_w := 0.15
		var arm_h := 0.62
		var cushion_w := w - arm_w * 2.0
		var cushion_d := d - 0.22

		# 1. Cuatro patas cónicas oscuras
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.03, leg_h, texture_key, leg_rect, 0.70, 0.0, false)

		# 2. Base inferior tapizada
		var apron_y := leg_h + apron_h * 0.5
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0))
		builder.add_smart_box(apron_t, Vector3(w - 0.06, apron_h, d - 0.06), texture_key, "smooth_fabric", 0.88, 0.0)

		# 3. Cojín suave gris marengo
		var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + apron_h + 0.06, 0.05))
		builder.add_top_panel_box(c_t, Vector3(cushion_w, 0.12, cushion_d), texture_key, "cushion", "smooth_fabric", 0.88, 0.0)

		# 4. Respaldo capitoné marengo
		var back_h := h - (leg_h + apron_h)
		var back_z := -d * 0.5 + 0.10
		var back_y := leg_h + apron_h + back_h * 0.5
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z))
		builder.add_panel_box(back_t, Vector3(cushion_w, back_h, 0.16), texture_key, "tufted_back", "smooth_fabric", 0.88, 0.0)

		# 5. Brazos redondeados con tachuelas plateadas
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		var fabric_rect := ObjectAtlasScript.get_region(texture_key, "smooth_fabric")
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := arm_h - leg_h - roll_radius
			var arm_body_y := leg_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "smooth_fabric", 0.88, 0.0)

			var roll_y := leg_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, fabric_rect, 0.88, 0.0, false)

			# Frontal acolchado de tela base
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 - 0.01))
			builder.add_smart_box(face_t, Vector3(arm_w, arm_h - leg_h, 0.03), texture_key, "smooth_fabric", 0.88, 0.0, false)

			# Línea vertical frontal de tachuelas plateadas centrada
			var strip_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 + 0.006))
			builder.add_smart_box(strip_t, Vector3(arm_w * 0.55, arm_h - leg_h - 0.02, 0.005), texture_key, "studded_arm", 0.55, 0.15, false)


# =========================================================================
# 8. SILLÓN CAPITONÉ AZUL CIELO (ARMCHAIR_02)
# =========================================================================
class ArmchairTuftedSkyBlueRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.86)
		var d: float = params.get("depth", 0.82)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "armchair_02")

		var leg_h := 0.14
		var apron_h := 0.14
		var arm_w := 0.15
		var arm_h := 0.62
		var cushion_w := w - arm_w * 2.0
		var cushion_d := d - 0.22

		# 1. Cuatro patas cónicas
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.03, leg_h, texture_key, leg_rect, 0.70, 0.0, false)

		# 2. Base inferior tapizada en azul
		var apron_y := leg_h + apron_h * 0.5
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0))
		builder.add_smart_box(apron_t, Vector3(w - 0.06, apron_h, d - 0.06), texture_key, "smooth_fabric", 0.88, 0.0)

		# 3. Cojín azul cielo pastel
		var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + apron_h + 0.06, 0.05))
		builder.add_top_panel_box(c_t, Vector3(cushion_w, 0.12, cushion_d), texture_key, "cushion", "smooth_fabric", 0.88, 0.0)

		# 4. Respaldo alto capitoné azul
		var back_h := h - (leg_h + apron_h)
		var back_z := -d * 0.5 + 0.10
		var back_y := leg_h + apron_h + back_h * 0.5
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z))
		builder.add_panel_box(back_t, Vector3(cushion_w, back_h, 0.16), texture_key, "tufted_back", "smooth_fabric", 0.88, 0.0)

		# 5. Brazos con tachuelas plateadas en el frontal
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		var fabric_rect := ObjectAtlasScript.get_region(texture_key, "smooth_fabric")
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := arm_h - leg_h - roll_radius
			var arm_body_y := leg_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "smooth_fabric", 0.88, 0.0)

			var roll_y := leg_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, fabric_rect, 0.88, 0.0, false)

			# Frontal acolchado de tela base
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 - 0.01))
			builder.add_smart_box(face_t, Vector3(arm_w, arm_h - leg_h, 0.03), texture_key, "smooth_fabric", 0.88, 0.0, false)

			# Línea vertical frontal de tachuelas plateadas centrada
			var strip_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 + 0.006))
			builder.add_smart_box(strip_t, Vector3(arm_w * 0.55, arm_h - leg_h - 0.02, 0.005), texture_key, "studded_arm", 0.55, 0.15, false)


# =========================================================================
# 9. SILLÓN TERCIOPELO AMARILLO MOSTAZA (ARMCHAIR_05)
# =========================================================================
class ArmchairVelvetMustardRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.90)
		var d: float = params.get("depth", 0.84)
		var h: float = params.get("height", 0.84)
		var texture_key: String = params.get("texture_key", "armchair_05")

		var leg_h := 0.12
		var apron_h := 0.14
		var arm_w := 0.16
		var arm_h := 0.60
		var cushion_w := w - arm_w * 2.0
		var cushion_d := d - 0.22

		# 1. Cuatro patas oscuras
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08)))
				builder.add_cylinder(leg_t, 0.03, leg_h, texture_key, leg_rect, 0.70, 0.0, false)

		# 2. Base de terciopelo mostaza mate
		var apron_y := leg_h + apron_h * 0.5
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0))
		builder.add_smart_box(apron_t, Vector3(w - 0.06, apron_h, d - 0.06), texture_key, "smooth_velvet", 0.92, 0.0)

		# 3. Cojín de terciopelo amarillo mostaza mate
		var c_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + apron_h + 0.06, 0.05))
		builder.add_top_panel_box(c_t, Vector3(cushion_w, 0.13, cushion_d), texture_key, "cushion", "smooth_velvet", 0.92, 0.0)

		# 4. Respaldo capitoné envolvente
		var back_h := h - (leg_h + apron_h)
		var back_z := -d * 0.5 + 0.12
		var back_y := leg_h + apron_h + back_h * 0.5
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z))
		builder.add_panel_box(back_t, Vector3(cushion_w, back_h, 0.18), texture_key, "tufted_back", "smooth_velvet", 0.92, 0.0)

		# 5. Brazos redondeados acolchados en terciopelo continuo mate
		var arm_len := d - 0.06
		var roll_radius := arm_w * 0.5
		var velvet_rect := ObjectAtlasScript.get_region(texture_key, "smooth_velvet")
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - arm_w * 0.5)
			var arm_body_h := arm_h - leg_h - roll_radius
			var arm_body_y := leg_h + arm_body_h * 0.5
			var arm_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, arm_body_y, -0.01))
			builder.add_smart_box(arm_body_t, Vector3(arm_w, arm_body_h, arm_len - 0.02), texture_key, "arm_side", 0.92, 0.0)

			var roll_y := leg_h + arm_body_h
			var roll_basis := Basis(Vector3.RIGHT, deg_to_rad(90))
			var roll_t := base_t * Transform3D(roll_basis, Vector3(arm_x, roll_y, -0.01))
			builder.add_cylinder(roll_t, roll_radius, arm_len - 0.02, texture_key, velvet_rect, 0.92, 0.0, false)

			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, leg_h + (arm_h - leg_h) * 0.5, d * 0.5 - 0.01))
			builder.add_panel_box(face_t, Vector3(arm_w, arm_h - leg_h, 0.03), texture_key, "arm_side", "smooth_velvet", 0.92, 0.0, false)


# =========================================================================
# 10. SILLA DE COMEDOR TAPIZADA RECTA (CHAIR_02)
# =========================================================================
class ChairDiningCreamRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.48)
		var d: float = params.get("depth", 0.50)
		var h: float = params.get("height", 0.95)
		var texture_key: String = params.get("texture_key", "chair_02")

		var seat_h := 0.46
		var leg_sz := 0.038
		var back_thick := 0.035

		# 1. Cuatro patas de caoba oscura mate
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var px := sx * (w * 0.5 - leg_sz * 0.5 - 0.01)
				var pz := sz * (d * 0.5 - leg_sz * 0.5 - 0.01)
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, seat_h * 0.5, pz))
				builder.add_smart_box(leg_t, Vector3(leg_sz, seat_h, leg_sz), texture_key, "wood_leg", 0.70, 0.0)

		# 2. Marco / faldón perimetral de caoba bajo el asiento
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h - 0.03, 0.0))
		builder.add_smart_box(apron_t, Vector3(w - 0.02, 0.06, d - 0.02), texture_key, "wood_frame", 0.70, 0.0)

		# 3. Asiento acolchado crema de lunares mate
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.025, 0.01))
		builder.add_top_panel_box(seat_t, Vector3(w, 0.05, d), texture_key, "polka_seat", "wood_frame", 0.88, 0.0)

		# 4. Respaldo alto de caoba con panel tapizado central
		var back_h := h - seat_h - 0.05
		var back_z := -d * 0.5 + back_thick * 0.5 + 0.01
		var back_y := seat_h + 0.05 + back_h * 0.5

		# Montantes laterales de madera del respaldo
		for side: float in [-1.0, 1.0]:
			var post_x := side * (w * 0.5 - leg_sz * 0.5)
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(post_x, back_y, back_z))
			builder.add_smart_box(post_t, Vector3(leg_sz, back_h, back_thick), texture_key, "wood_frame", 0.70, 0.0)

		# Travesaño superior de madera
		var top_rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.025, back_z))
		builder.add_smart_box(top_rail_t, Vector3(w, 0.05, back_thick), texture_key, "wood_frame", 0.70, 0.0)

		# Panel tapizado central crema
		var panel_w := w - leg_sz * 2.0
		var panel_h := back_h - 0.06
		var panel_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y - 0.01, back_z))
		builder.add_panel_box(panel_t, Vector3(panel_w, panel_h, back_thick * 0.9), texture_key, "polka_back", "wood_frame", 0.88, 0.0)


# =========================================================================
# 11. SILLA CLÁSICA BARROCA RESPALDO OVALADO (CHAIR_01)
# =========================================================================
class ChairBaroqueOvalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.52)
		var d: float = params.get("depth", 0.52)
		var h: float = params.get("height", 0.96)
		var texture_key: String = params.get("texture_key", "chair_01")

		var seat_h := 0.46
		var wood_rect := ObjectAtlasScript.get_region(texture_key, "carved_wood")

		# 1. Cuatro patas doradas talladas estilo cabriolé mate
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var px := sx * (w * 0.5 - 0.04)
				var pz := sz * (d * 0.5 - 0.04)
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, seat_h * 0.5, pz))
				builder.add_cylinder(leg_t, 0.024, seat_h, texture_key, wood_rect, 0.65, 0.0, false)

		# 2. Faldón tallado dorado bajo el asiento
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h - 0.03, 0.0))
		builder.add_smart_box(apron_t, Vector3(w - 0.04, 0.06, d - 0.04), texture_key, "carved_wood", 0.65, 0.0)

		# 3. Asiento redondeado con tela adamascada dorada/crema mate
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.03, 0.01))
		builder.add_top_panel_box(seat_t, Vector3(w, 0.06, d), texture_key, "damask_back", "carved_wood", 0.88, 0.0)

		# 4. Soportes del respaldo
		var post_h := 0.12
		for side: float in [-1.0, 1.0]:
			var px := side * 0.14
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, seat_h + 0.06 + post_h * 0.5, -d * 0.5 + 0.04))
			builder.add_cylinder(post_t, 0.018, post_h, texture_key, wood_rect, 0.65, 0.0, false)

		# 5. Respaldo ovalado medallón barroco
		var back_h := 0.44
		var back_w := 0.38
		var back_y := seat_h + 0.06 + post_h + back_h * 0.5 - 0.02

		# Marco de madera tallada dorada mate
		var frame_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, -d * 0.5 + 0.035))
		builder.add_smart_box(frame_t, Vector3(back_w + 0.04, back_h + 0.04, 0.03), texture_key, "carved_wood", 0.65, 0.0, false)

		# Centro tapizado de damasco mate
		var panel_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, -d * 0.5 + 0.045))
		builder.add_panel_box(panel_t, Vector3(back_w, back_h, 0.02), texture_key, "damask_back", "carved_wood", 0.88, 0.0)


# =========================================================================
# 12. SILLÓN LUIS XV TOILE DE JOUY AZUL (CHAIR)
# =========================================================================
class ArmchairLouisXVBlueRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.64)
		var d: float = params.get("depth", 0.60)
		var h: float = params.get("height", 0.96)
		var texture_key: String = params.get("texture_key", "chair")

		var seat_h := 0.44
		var wood_rect := ObjectAtlasScript.get_region(texture_key, "carved_wood")

		# 1. Cuatro patas estilo cabriolé talladas mate
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.05), seat_h * 0.5, sz * (d * 0.5 - 0.05)))
				builder.add_cylinder(leg_t, 0.024, seat_h, texture_key, wood_rect, 0.70, 0.0, false)

		# 2. Faldón tallado bajo el asiento
		var apron_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h - 0.03, 0.01))
		builder.add_smart_box(apron_t, Vector3(w - 0.04, 0.06, d - 0.04), texture_key, "carved_wood", 0.70, 0.0)

		# 3. Asiento acolchado Toile de Jouy azul mate
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.03, 0.02))
		builder.add_top_panel_box(seat_t, Vector3(w - 0.04, 0.07, d - 0.04), texture_key, "toile_seat", "carved_wood", 0.88, 0.0)

		# 4. Soportes del respaldo
		var post_h := 0.12
		for side: float in [-1.0, 1.0]:
			var px := side * 0.16
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, seat_h + 0.07 + post_h * 0.5, -d * 0.5 + 0.04))
			builder.add_cylinder(post_t, 0.020, post_h, texture_key, wood_rect, 0.70, 0.0, false)

		# 5. Respaldo ovalado medallón con marco tallado y Toile de Jouy azul mate
		var back_h := 0.44
		var back_w := 0.40
		var back_y := seat_h + 0.07 + post_h + back_h * 0.5 - 0.02

		var frame_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, -d * 0.5 + 0.035))
		builder.add_smart_box(frame_t, Vector3(back_w + 0.04, back_h + 0.04, 0.03), texture_key, "carved_wood", 0.70, 0.0, false)

		var panel_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, -d * 0.5 + 0.045))
		builder.add_panel_box(panel_t, Vector3(back_w, back_h, 0.02), texture_key, "toile_back", "carved_wood", 0.88, 0.0)

		# 6. Brazos curvados franceses con coderas acolchadas mate
		var arm_h := 0.22
		for side: float in [-1.0, 1.0]:
			var arm_x := side * (w * 0.5 - 0.04)
			var arm_post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.07 + arm_h * 0.5, 0.06))
			builder.add_cylinder(arm_post_t, 0.018, arm_h, texture_key, wood_rect, 0.70, 0.0, false)

			var arm_rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.07 + arm_h, -0.04))
			builder.add_smart_box(arm_rail_t, Vector3(0.035, 0.025, 0.26), texture_key, "carved_wood", 0.70, 0.0)

			var pad_t := base_t * Transform3D(Basis.IDENTITY, Vector3(arm_x, seat_h + 0.07 + arm_h + 0.02, -0.04))
			builder.add_smart_box(pad_t, Vector3(0.045, 0.025, 0.16), texture_key, "arm_pad", 0.88, 0.0)
