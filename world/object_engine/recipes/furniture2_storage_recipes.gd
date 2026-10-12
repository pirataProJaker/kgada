class_name Furniture2StorageRecipes
extends RefCounted

## Recetas Oficiales: Almacenamiento, Cómodas, Vitrinas y Roperos (Furniture 2.0 - Imagen 4)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Mapeo preciso de sub-regiones UV del Atlas Inteligente

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


## Helper estático para construir un cajón deslizante interior completamente hueco y vacío
class DrawerHelper:
	static func build_box(
		builder: Variant, base_t: Transform3D, pos_center: Vector3,
		box_w: float, box_h: float, slide_ext: float,
		tex_key: String, region_name: String = "wood_body",
		roughness: float = 0.55, metallic: float = 0.02
	) -> void:
		if slide_ext <= 0.005:
			return
		var wall_t := 0.012
		var box_depth := slide_ext
		var center_z := pos_center.z + slide_ext * 0.5
		var cy := pos_center.y

		# 1. Pared lateral izquierda (-X)
		var left_pos := Vector3(pos_center.x - box_w * 0.5 + wall_t * 0.5, cy, center_z)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, left_pos), Vector3(wall_t, box_h, box_depth), tex_key, region_name, roughness, metallic, false)

		# 2. Pared lateral derecha (+X)
		var right_pos := Vector3(pos_center.x + box_w * 0.5 - wall_t * 0.5, cy, center_z)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, right_pos), Vector3(wall_t, box_h, box_depth), tex_key, region_name, roughness, metallic, false)

		# 3. Pared trasera (-Z, en la boca del marco)
		var back_pos := Vector3(pos_center.x, cy, pos_center.z + wall_t * 0.5)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, back_pos), Vector3(box_w - wall_t * 2.0, box_h, wall_t), tex_key, region_name, roughness, metallic, false)

		# 4. Fondo inferior (-Y)
		var bot_pos := Vector3(pos_center.x, cy - box_h * 0.5 + wall_t * 0.5, center_z)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, bot_pos), Vector3(box_w - wall_t * 2.0, wall_t, box_depth), tex_key, region_name, roughness, metallic, false)


# =========================================================================
# 1. CÓMODA ALTA DE 5 CAJONES (CHEST_DRAWERS_01)
# =========================================================================
class ChestDrawersTall5Recipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.90)
		var d: float = params.get("depth", 0.46)
		var h: float = params.get("height", 1.25)
		var texture_key: String = params.get("texture_key", "chest_drawers_01")

		var plinth_h := 0.08
		var top_thick := 0.035
		var casing_h := h - plinth_h - top_thick
		var wall_t := 0.025

		# Tapa superior volada
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.04, top_thick, d + 0.04), texture_key, "wood_top")

		# Zócalo base
		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w - 0.02, plinth_h, d - 0.02), texture_key, "wood_body")

		# Laterales y trasera del cuerpo
		for side: float in [-1.0, 1.0]:
			var side_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(side_t, Vector3(wall_t, casing_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "wood_body")

		# 5 Cajones deslizables
		var drawer_slides: Array = params.get("drawer_slides", [])
		if drawer_slides.is_empty():
			var is_open: bool = params.get("is_open", false)
			drawer_slides = [0.0, 0.15, 0.0, 0.22, 0.0] if is_open else [0.0, 0.0, 0.0, 0.0, 0.0]

		var drawer_count := 5
		var drawer_gap := 0.012
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		var drawer_w := w - wall_t * 2.0 - 0.01
		var knob_rect := ObjectAtlasScript.get_region(texture_key, "drawers")

		for i in range(drawer_count):
			var ext: float = 0.0
			if i < drawer_slides.size():
				ext = float(drawer_slides[i])

			var dy := plinth_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext))
			builder.add_smart_box(face_t, Vector3(drawer_w, drawer_h, 0.022), texture_key, "drawers")

			# 2 Pomos / tiradores por cajón
			for p_side: float in [-1.0, 1.0]:
				var knob_t := base_t * Transform3D(Basis.IDENTITY, Vector3(p_side * (drawer_w * 0.28), dy, d * 0.5 + ext + 0.02))
				builder.add_cylinder(knob_t, 0.015, 0.022, texture_key, knob_rect, 0.25, 0.80, false)

			if ext > 0.005:
				DrawerHelper.build_box(builder, base_t, Vector3(0.0, dy, d * 0.5), drawer_w - 0.02, drawer_h - 0.02, ext, texture_key, "wood_body")


# =========================================================================
# 2. CÓMODA MADERA CLARA DE 4 CAJONES (CHEST_DRAWERS_01)
# =========================================================================
class ChestDrawersLight4Recipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.85)
		var d: float = params.get("depth", 0.44)
		var h: float = params.get("height", 1.05)
		var texture_key: String = params.get("texture_key", "chest_drawers_01")

		var plinth_h := 0.08
		var top_thick := 0.032
		var casing_h := h - plinth_h - top_thick
		var wall_t := 0.025

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.03, top_thick, d + 0.03), texture_key, "wood_top")

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w - 0.02, plinth_h, d - 0.02), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var side_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(side_t, Vector3(wall_t, casing_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "wood_body")

		var drawer_slides: Array = params.get("drawer_slides", [])
		if drawer_slides.is_empty():
			var is_open: bool = params.get("is_open", false)
			drawer_slides = [0.0, 0.18, 0.0, 0.10] if is_open else [0.0, 0.0, 0.0, 0.0]

		var drawer_count := 4
		var drawer_gap := 0.012
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		var drawer_w := w - wall_t * 2.0 - 0.01
		var knob_rect := ObjectAtlasScript.get_region(texture_key, "drawers")

		for i in range(drawer_count):
			var ext: float = 0.0
			if i < drawer_slides.size():
				ext = float(drawer_slides[i])

			var dy := plinth_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext))
			builder.add_smart_box(face_t, Vector3(drawer_w, drawer_h, 0.022), texture_key, "drawers")

			for p_side: float in [-1.0, 1.0]:
				var knob_t := base_t * Transform3D(Basis.IDENTITY, Vector3(p_side * (drawer_w * 0.28), dy, d * 0.5 + ext + 0.018))
				builder.add_cylinder(knob_t, 0.014, 0.02, texture_key, knob_rect, 0.30, 0.70, false)

			if ext > 0.005:
				DrawerHelper.build_box(builder, base_t, Vector3(0.0, dy, d * 0.5), drawer_w - 0.02, drawer_h - 0.02, ext, texture_key, "wood_body")


# =========================================================================
# 3. CÓMODA MODERNA BLANCA/GRIS DE 3 CAJONES (CHEST_DRAWERS_02)
# =========================================================================
class ChestDrawersWhite3Recipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.85)
		var d: float = params.get("depth", 0.42)
		var h: float = params.get("height", 0.82)
		var texture_key: String = params.get("texture_key", "chest_drawers_02")

		var leg_h := 0.10
		var top_thick := 0.028
		var casing_h := h - leg_h - top_thick
		var wall_t := 0.022
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "white_body")

		# 4 Patas cilíndricas modernas metálicas
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.06), leg_h * 0.5, sz * (d * 0.5 - 0.06))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.018, leg_h, texture_key, leg_rect, 0.20, 0.85, false)

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w, top_thick, d), texture_key, "white_body")

		for side: float in [-1.0, 1.0]:
			var side_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), leg_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(side_t, Vector3(wall_t, casing_h, d), texture_key, "white_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "white_body")

		var drawer_slides: Array = params.get("drawer_slides", [])
		if drawer_slides.is_empty():
			var is_open: bool = params.get("is_open", false)
			drawer_slides = [0.0, 0.20, 0.0] if is_open else [0.0, 0.0, 0.0]

		var drawer_count := 3
		var drawer_gap := 0.012
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		var drawer_w := w - wall_t * 2.0 - 0.01
		var handle_rect := ObjectAtlasScript.get_region(texture_key, "drawers")

		for i in range(drawer_count):
			var ext: float = 0.0
			if i < drawer_slides.size():
				ext = float(drawer_slides[i])

			var dy := leg_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext))
			builder.add_smart_box(face_t, Vector3(drawer_w, drawer_h, 0.02), texture_key, "drawers")

			# Tirador de barra horizontal
			var handle_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, dy, d * 0.5 + ext + 0.02))
			builder.add_cylinder(handle_t, 0.01, 0.14, texture_key, handle_rect, 0.15, 0.90, false)

			if ext > 0.005:
				DrawerHelper.build_box(builder, base_t, Vector3(0.0, dy, d * 0.5), drawer_w - 0.02, drawer_h - 0.02, ext, texture_key, "white_body")


# =========================================================================
# 4. MESITA DE NOCHE 3 CAJONES CON PATAS CÓNICAS (CHEST_DRAWERS_03)
# =========================================================================
class NightstandTaperedLegs3Recipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.48)
		var d: float = params.get("depth", 0.38)
		var h: float = params.get("height", 0.65)
		var texture_key: String = params.get("texture_key", "chest_drawers_03")

		var leg_h := 0.16
		var top_thick := 0.025
		var casing_h := h - leg_h - top_thick
		var wall_t := 0.02
		var pine_rect := ObjectAtlasScript.get_region(texture_key, "pine_body")

		# 4 Patas cónicas estilizadas nórdicas
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.05), leg_h * 0.5, sz * (d * 0.5 - 0.05))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.015, leg_h, texture_key, pine_rect, 0.50, 0.05, false)

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.02, top_thick, d + 0.02), texture_key, "pine_top")

		for side: float in [-1.0, 1.0]:
			var side_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), leg_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(side_t, Vector3(wall_t, casing_h, d), texture_key, "pine_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "pine_body")

		var drawer_slides: Array = params.get("drawer_slides", [])
		if drawer_slides.is_empty():
			var is_open: bool = params.get("is_open", false)
			drawer_slides = [0.0, 0.12, 0.0] if is_open else [0.0, 0.0, 0.0]

		var drawer_count := 3
		var drawer_gap := 0.008
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		var drawer_w := w - wall_t * 2.0 - 0.008
		var knob_rect := ObjectAtlasScript.get_region(texture_key, "drawers")

		for i in range(drawer_count):
			var ext: float = 0.0
			if i < drawer_slides.size():
				ext = float(drawer_slides[i])

			var dy := leg_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext))
			builder.add_smart_box(face_t, Vector3(drawer_w, drawer_h, 0.018), texture_key, "drawers")

			var knob_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext + 0.015))
			builder.add_cylinder(knob_t, 0.012, 0.018, texture_key, knob_rect, 0.30, 0.50, false)

			if ext > 0.005:
				DrawerHelper.build_box(builder, base_t, Vector3(0.0, dy, d * 0.5), drawer_w - 0.02, drawer_h - 0.02, ext, texture_key, "pine_body")


# =========================================================================
# 5. MESITA DE NOCHE 2 CAJONES CON PATAS CÓNICAS (CHEST_DRAWERS_04)
# =========================================================================
class NightstandTaperedLegs2Recipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.46)
		var d: float = params.get("depth", 0.36)
		var h: float = params.get("height", 0.56)
		var texture_key: String = params.get("texture_key", "chest_drawers_04")

		var leg_h := 0.20
		var top_thick := 0.025
		var casing_h := h - leg_h - top_thick
		var wall_t := 0.02
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")

		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.05), leg_h * 0.5, sz * (d * 0.5 - 0.05))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.015, leg_h, texture_key, leg_rect, 0.50, 0.05, false)

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.02, top_thick, d + 0.02), texture_key, "oak_body")

		for side: float in [-1.0, 1.0]:
			var side_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), leg_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(side_t, Vector3(wall_t, casing_h, d), texture_key, "oak_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "oak_body")

		var drawer_slides: Array = params.get("drawer_slides", [])
		if drawer_slides.is_empty():
			var is_open: bool = params.get("is_open", false)
			drawer_slides = [0.0, 0.14] if is_open else [0.0, 0.0]

		var drawer_count := 2
		var drawer_gap := 0.008
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		var drawer_w := w - wall_t * 2.0 - 0.008
		var knob_rect := ObjectAtlasScript.get_region(texture_key, "nightstand_drawers")

		for i in range(drawer_count):
			var ext: float = 0.0
			if i < drawer_slides.size():
				ext = float(drawer_slides[i])

			var dy := leg_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext))
			builder.add_smart_box(face_t, Vector3(drawer_w, drawer_h, 0.018), texture_key, "nightstand_drawers")

			var knob_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext + 0.015))
			builder.add_cylinder(knob_t, 0.012, 0.018, texture_key, knob_rect, 0.30, 0.50, false)

			if ext > 0.005:
				DrawerHelper.build_box(builder, base_t, Vector3(0.0, dy, d * 0.5), drawer_w - 0.02, drawer_h - 0.02, ext, texture_key, "oak_body")


# =========================================================================
# 6. APARADOR BUFFET ANCHO 2 PUERTAS + 3 CAJONES (CHEST_DRAWERS_05)
# =========================================================================
class SideboardBuffet3DrawersRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.45)
		var d: float = params.get("depth", 0.45)
		var h: float = params.get("height", 0.82)
		var texture_key: String = params.get("texture_key", "chest_drawers_05")

		var leg_h := 0.12
		var top_thick := 0.03
		var casing_h := h - leg_h - top_thick
		var wall_t := 0.025
		var wood_rect := ObjectAtlasScript.get_region(texture_key, "wood_body")

		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.02, leg_h, texture_key, wood_rect, 0.45, 0.10, false)

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.04, top_thick, d + 0.04), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var side_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), leg_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(side_t, Vector3(wall_t, casing_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "wood_body")

		var center_w := 0.55
		var door_w := (w - wall_t * 2.0 - center_w) * 0.5

		# Separadores verticales internos
		for s_side: float in [-1.0, 1.0]:
			var sep_x := s_side * (center_w * 0.5)
			var sep_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sep_x, leg_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(sep_t, Vector3(wall_t, casing_h, d - wall_t), texture_key, "wood_body", 0.50, 0.02, false)

		# Puertas laterales batientes
		var doors_open: bool = params.get("doors_open", params.get("is_open", false))
		var door_thick := 0.02
		var door_y := leg_h + casing_h * 0.5
		var swing_angle := deg_to_rad(85.0) if doors_open else 0.0

		# Puerta Izquierda (-X)
		var left_hinge_x := -w * 0.5 + wall_t
		var left_rot := Basis(Vector3.UP, -swing_angle)
		var left_door_center := Vector3(left_hinge_x, door_y, d * 0.5) + left_rot * Vector3(door_w * 0.5, 0.0, 0.0)
		var left_door_t := base_t * Transform3D(left_rot, left_door_center)
		builder.add_smart_box(left_door_t, Vector3(door_w, casing_h - 0.02, door_thick), texture_key, "drawer_panels")

		# Puerta Derecha (+X)
		var right_hinge_x := w * 0.5 - wall_t
		var right_rot := Basis(Vector3.UP, swing_angle)
		var right_door_center := Vector3(right_hinge_x, door_y, d * 0.5) + right_rot * Vector3(-door_w * 0.5, 0.0, 0.0)
		var right_door_t := base_t * Transform3D(right_rot, right_door_center)
		builder.add_smart_box(right_door_t, Vector3(door_w, casing_h - 0.02, door_thick), texture_key, "drawer_panels")

		# 3 Cajones centrales deslizables
		var drawer_slides: Array = params.get("drawer_slides", [])
		if drawer_slides.is_empty():
			drawer_slides = [0.0, 0.16, 0.0] if doors_open else [0.0, 0.0, 0.0]

		var drawer_count := 3
		var drawer_gap := 0.01
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		var d_box_w := center_w - wall_t - 0.01
		var knob_rect := ObjectAtlasScript.get_region(texture_key, "drawer_panels")

		for i in range(drawer_count):
			var ext: float = 0.0
			if i < drawer_slides.size():
				ext = float(drawer_slides[i])

			var dy := leg_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var face_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext))
			builder.add_smart_box(face_t, Vector3(d_box_w, drawer_h, 0.02), texture_key, "drawer_panels")

			var knob_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, dy, d * 0.5 + ext + 0.016))
			builder.add_cylinder(knob_t, 0.012, 0.018, texture_key, knob_rect, 0.25, 0.60, false)

			if ext > 0.005:
				DrawerHelper.build_box(builder, base_t, Vector3(0.0, dy, d * 0.5), d_box_w - 0.02, drawer_h - 0.02, ext, texture_key, "wood_body")


# =========================================================================
# 7. MUEBLE BAJO 2 PUERTAS CON PATAS CÓNICAS (CHEST_DRAWERS_06)
# =========================================================================
class SideboardLow2DoorsRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.05)
		var d: float = params.get("depth", 0.42)
		var h: float = params.get("height", 0.68)
		var texture_key: String = params.get("texture_key", "chest_drawers_06")

		var leg_h := 0.18
		var top_thick := 0.028
		var casing_h := h - leg_h - top_thick
		var wall_t := 0.022
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_body")

		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.06), leg_h * 0.5, sz * (d * 0.5 - 0.06))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.018, leg_h, texture_key, leg_rect, 0.50, 0.05, false)

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.02, top_thick, d + 0.02), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var side_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), leg_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(side_t, Vector3(wall_t, casing_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "wood_body")

		var is_open: bool = params.get("is_open", false)
		var door_w := (w - wall_t * 2.0) * 0.5
		var door_y := leg_h + casing_h * 0.5
		var swing_angle := deg_to_rad(85.0) if is_open else 0.0

		# Puerta Izquierda (-X)
		var left_hinge_x := -w * 0.5 + wall_t
		var left_rot := Basis(Vector3.UP, -swing_angle)
		var left_door_center := Vector3(left_hinge_x, door_y, d * 0.5) + left_rot * Vector3(door_w * 0.5, 0.0, 0.0)
		var left_door_t := base_t * Transform3D(left_rot, left_door_center)
		builder.add_smart_box(left_door_t, Vector3(door_w - 0.005, casing_h - 0.015, 0.02), texture_key, "doors")

		# Puerta Derecha (+X)
		var right_hinge_x := w * 0.5 - wall_t
		var right_rot := Basis(Vector3.UP, swing_angle)
		var right_door_center := Vector3(right_hinge_x, door_y, d * 0.5) + right_rot * Vector3(-door_w * 0.5, 0.0, 0.0)
		var right_door_t := base_t * Transform3D(right_rot, right_door_center)
		builder.add_smart_box(right_door_t, Vector3(door_w - 0.005, casing_h - 0.015, 0.02), texture_key, "doors")

		# Repisa interior visible al abrir
		var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, 0.0))
		builder.add_smart_box(shelf_t, Vector3(w - wall_t * 2.0 - 0.02, 0.02, d - 0.04), texture_key, "wood_body", 0.50, 0.02, false)


# =========================================================================
# 8. ALACENA RÚSTICA WELSH DRESSER (FITMENT)
# =========================================================================
class CupboardWelshDresserRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.15)
		var d_base: float = params.get("depth", 0.48)
		var d_top: float = params.get("depth_top", 0.28)
		var h: float = params.get("height", 1.95)
		var texture_key: String = params.get("texture_key", "fitment")

		var h_base := 0.85
		var plinth_h := 0.08
		var mid_shelf_thick := 0.035
		var wall_t := 0.025

		# --- CUERPO INFERIOR (Base baja) ---
		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w - 0.02, plinth_h, d_base - 0.02), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + (h_base - plinth_h) * 0.5, 0.0))
			builder.add_smart_box(s_t, Vector3(wall_t, h_base - plinth_h, d_base), texture_key, "wood_body")

		var back_lower_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + (h_base - plinth_h) * 0.5, -d_base * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_lower_t, Vector3(w - wall_t * 2.0, h_base - plinth_h, wall_t), texture_key, "wood_body")

		# Encimera intermedia
		var mid_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h_base - mid_shelf_thick * 0.5, 0.0))
		builder.add_smart_box(mid_t, Vector3(w + 0.04, mid_shelf_thick, d_base + 0.04), texture_key, "wood_body")

		# 2 Puertas inferiores
		var door_h := h_base - plinth_h - 0.16
		var door_w := (w - wall_t * 2.0) * 0.5
		var door_y := plinth_h + door_h * 0.5
		for side: float in [-1.0, 1.0]:
			var door_x := side * (door_w * 0.5)
			var door_t := base_t * Transform3D(Basis.IDENTITY, Vector3(door_x, door_y, d_base * 0.5))
			builder.add_smart_box(door_t, Vector3(door_w - 0.005, door_h, 0.02), texture_key, "vitrine_glass")

		# 2 Cajones medianos sobre las puertas
		var drawer_y := h_base - mid_shelf_thick - 0.07
		for side: float in [-1.0, 1.0]:
			var d_x := side * (door_w * 0.5)
			var d_t := base_t * Transform3D(Basis.IDENTITY, Vector3(d_x, drawer_y, d_base * 0.5))
			builder.add_smart_box(d_t, Vector3(door_w - 0.005, 0.12, 0.02), texture_key, "drawers_strip")

		# --- CUERPO SUPERIOR (Repisas para vajilla) ---
		var h_top := h - h_base
		var top_back_z := -d_base * 0.5 + d_top * 0.5

		# Fondo machihembrado
		var top_back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h_base + h_top * 0.5, -d_base * 0.5 + wall_t * 0.5))
		builder.add_smart_box(top_back_t, Vector3(w - wall_t * 2.0, h_top, wall_t), texture_key, "wood_body")

		# Laterales superiores
		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), h_base + h_top * 0.5, top_back_z))
			builder.add_smart_box(s_t, Vector3(wall_t, h_top, d_top), texture_key, "wood_body")

		# Cornisa superior
		var crown_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.025, top_back_z))
		builder.add_smart_box(crown_t, Vector3(w + 0.04, 0.05, d_top + 0.04), texture_key, "wood_body")

		# 2 Repisas intermedias con vitrina / platos expuestos
		for s in range(1, 3):
			var sy := h_base + float(s) * (h_top / 3.0)
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, top_back_z))
			builder.add_smart_box(shelf_t, Vector3(w - wall_t * 2.0, 0.025, d_top - 0.02), texture_key, "vitrine_glass")


# =========================================================================
# 9. VITRINA ALTA MADERA NOBLE CON LIBROS (BOOKCASE_01)
# =========================================================================
class CupboardVitrineBooksRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.05)
		var d: float = params.get("depth", 0.45)
		var h: float = params.get("height", 1.90)
		var texture_key: String = params.get("texture_key", "bookcase_01")

		var plinth_h := 0.08
		var crown_h := 0.06
		var casing_h := h - plinth_h - crown_h
		var wall_t := 0.025

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w, plinth_h, d), texture_key, "wood_body")

		var crown_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - crown_h * 0.5, 0.0))
		builder.add_smart_box(crown_t, Vector3(w + 0.05, crown_h, d + 0.05), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(s_t, Vector3(wall_t, casing_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "wood_body")

		# Puertas de vitrina acristaladas superiores
		var glass_h := casing_h * 0.65
		var lower_h := casing_h * 0.35
		var door_w := (w - wall_t * 2.0) * 0.5

		# Puertas ciegas de madera inferiores
		var low_door_y := plinth_h + lower_h * 0.5
		for side: float in [-1.0, 1.0]:
			var d_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (door_w * 0.5), low_door_y, d * 0.5))
			builder.add_smart_box(d_t, Vector3(door_w - 0.005, lower_h - 0.01, 0.022), texture_key, "wood_cabinet")

		# Marcos acristalados superiores con cristales y libros
		var glass_door_y := plinth_h + lower_h + glass_h * 0.5
		for side: float in [-1.0, 1.0]:
			var d_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (door_w * 0.5), glass_door_y, d * 0.5))
			builder.add_smart_box(d_t, Vector3(door_w - 0.005, glass_h - 0.01, 0.022), texture_key, "vitrine_books")

		# 3 Repisas interiores
		for s in range(1, 4):
			var sy := plinth_h + lower_h + float(s) * (glass_h / 4.0)
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, 0.0))
			builder.add_smart_box(shelf_t, Vector3(w - wall_t * 2.0 - 0.02, 0.025, d - 0.05), texture_key, "vitrine_books", 0.45, 0.02, false)


# =========================================================================
# 10. VITRINA ALTA CON MOLDURAS ORNAMENTADAS (BOOKCASE_01)
# =========================================================================
class CupboardVitrineBooks02Recipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var p := params.duplicate()
		p["texture_key"] = params.get("texture_key", "bookcase_01")
		CupboardVitrineBooksRecipe.build(builder, base_t, p)


# =========================================================================
# 11. APARADOR VITRINA CLÁSICA CON CRISTALES (FITMENT)
# =========================================================================
class CupboardGlassTallRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.00)
		var d: float = params.get("depth", 0.44)
		var h: float = params.get("height", 1.85)
		var texture_key: String = params.get("texture_key", "fitment")

		var plinth_h := 0.08
		var crown_h := 0.05
		var casing_h := h - plinth_h - crown_h
		var wall_t := 0.025

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w, plinth_h, d), texture_key, "wood_body")

		var crown_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - crown_h * 0.5, 0.0))
		builder.add_smart_box(crown_t, Vector3(w + 0.04, crown_h, d + 0.04), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(s_t, Vector3(wall_t, casing_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "wood_body")

		# 2 Puertas acristaladas de altura completa
		var door_w := (w - wall_t * 2.0) * 0.5
		var door_y := plinth_h + casing_h * 0.5
		for side: float in [-1.0, 1.0]:
			var d_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (door_w * 0.5), door_y, d * 0.5))
			builder.add_smart_box(d_t, Vector3(door_w - 0.005, casing_h - 0.015, 0.022), texture_key, "vitrine_glass")

		# Repisas interiores de madera
		for s in range(1, 4):
			var sy := plinth_h + float(s) * (casing_h / 4.0)
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, 0.0))
			builder.add_smart_box(shelf_t, Vector3(w - wall_t * 2.0 - 0.02, 0.025, d - 0.05), texture_key, "wood_body", 0.50, 0.02, false)


# =========================================================================
# 12. LIBRERO ALTO CON 5 REPISAS DE LIBROS (BOOKCASE)
# =========================================================================
class BookcaseFullBooksTallRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.90)
		var d: float = params.get("depth", 0.32)
		var h: float = params.get("height", 1.95)
		var texture_key: String = params.get("texture_key", "bookcase")

		var plinth_h := 0.08
		var top_thick := 0.03
		var wall_t := 0.025
		var inner_h := h - plinth_h - top_thick

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w, plinth_h, d), texture_key, "wood_body")

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.02, top_thick, d + 0.02), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + inner_h * 0.5, 0.0))
			builder.add_smart_box(s_t, Vector3(wall_t, inner_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + inner_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, inner_h, wall_t), texture_key, "wood_body")

		# 5 Repisas intermedias llenas de libros
		var shelf_count := 5
		var shelf_h := inner_h / float(shelf_count)
		for s in range(shelf_count):
			var sy := plinth_h + float(s) * shelf_h
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, 0.0))
			builder.add_smart_box(shelf_t, Vector3(w - wall_t * 2.0, 0.025, d - wall_t), texture_key, "wood_body")

			# Hilera de libros volumétricos sobre la repisa
			var books_h := shelf_h - 0.06
			var books_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy + 0.025 + books_h * 0.5, 0.02))
			builder.add_smart_box(books_t, Vector3(w - wall_t * 2.0 - 0.04, books_h, d * 0.70), texture_key, "books_shelves", 0.70, 0.01, false)


# =========================================================================
# 13. LIBRERO ALTO CON ENCICLOPEDIAS (BOOKCASE)
# =========================================================================
class BookcaseFullBooksTall01Recipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var p := params.duplicate()
		p["texture_key"] = params.get("texture_key", "bookcase")
		BookcaseFullBooksTallRecipe.build(builder, base_t, p)


# =========================================================================
# 14. LIBRERO BAJO CON 2 NIVELES DE LIBROS (BOOKCASE)
# =========================================================================
class BookcaseBooksLowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.10)
		var d: float = params.get("depth", 0.32)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "bookcase")

		var plinth_h := 0.08
		var top_thick := 0.028
		var wall_t := 0.025
		var inner_h := h - plinth_h - top_thick

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w, plinth_h, d), texture_key, "wood_body")

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.02, top_thick, d + 0.02), texture_key, "wood_body")

		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + inner_h * 0.5, 0.0))
			builder.add_smart_box(s_t, Vector3(wall_t, inner_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + inner_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, inner_h, wall_t), texture_key, "wood_body")

		# 2 Niveles con repisa central
		var shelf_h := inner_h * 0.5
		var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + shelf_h, 0.0))
		builder.add_smart_box(shelf_t, Vector3(w - wall_t * 2.0, 0.025, d - wall_t), texture_key, "wood_body")

		for level in range(2):
			var ly := plinth_h + float(level) * shelf_h + 0.025 + (shelf_h - 0.06) * 0.5
			var books_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, ly, 0.02))
			builder.add_smart_box(books_t, Vector3(w - wall_t * 2.0 - 0.04, shelf_h - 0.06, d * 0.70), texture_key, "books_shelves", 0.70, 0.01, false)


# =========================================================================
# 15. ROPERO ABIERTO CON VESTIDOS Y PERCHAS (WARDROBE)
# =========================================================================
class WardrobeOpenClothesRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.10)
		var d: float = params.get("depth", 0.55)
		var h: float = params.get("height", 1.95)
		var texture_key: String = params.get("texture_key", "wardrobe")

		var plinth_h := 0.08
		var bottom_box_h := 0.35
		var top_thick := 0.03
		var wall_t := 0.025

		# Zócalo y tapa superior
		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w, plinth_h, d), texture_key, "wood_body")

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.04, top_thick, d + 0.04), texture_key, "wood_body")

		# Costados y trasera completa
		var casing_h := h - plinth_h - top_thick
		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), plinth_h + casing_h * 0.5, 0.0))
			builder.add_smart_box(s_t, Vector3(wall_t, casing_h, d), texture_key, "wood_body")
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + casing_h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, casing_h, wall_t), texture_key, "wood_body")

		# 2 Cajones inferiores
		var drawer_w := (w - wall_t * 2.0) * 0.5
		var drawer_y := plinth_h + bottom_box_h * 0.5
		for side: float in [-1.0, 1.0]:
			var d_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (drawer_w * 0.5), drawer_y, d * 0.5))
			builder.add_smart_box(d_t, Vector3(drawer_w - 0.005, bottom_box_h - 0.02, 0.022), texture_key, "wood_body")

		# Repisa sobre los cajones
		var mid_shelf_y := plinth_h + bottom_box_h
		var mid_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mid_shelf_y, 0.0))
		builder.add_smart_box(mid_t, Vector3(w - wall_t * 2.0, 0.025, d - wall_t), texture_key, "wood_body")

		# Repisa superior para sombreros/maletas
		var top_shelf_y := h - top_thick - 0.30
		var top_shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, top_shelf_y, 0.0))
		builder.add_smart_box(top_shelf_t, Vector3(w - wall_t * 2.0, 0.025, d - wall_t), texture_key, "wood_body")

		# Barra metálica para colgar ropa
		var rail_rect := ObjectAtlasScript.get_region(texture_key, "wood_body")
		var rail_y := top_shelf_y - 0.06
		var rail_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, rail_y, 0.0))
		builder.add_cylinder(rail_t, 0.015, w - wall_t * 2.0 - 0.02, texture_key, rail_rect, 0.20, 0.80, false)

		# Ropa colgada en perchas (vestidos, camisas, abrigos)
		var clothes_h := rail_y - mid_shelf_y - 0.08
		var clothes_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mid_shelf_y + clothes_h * 0.5 + 0.04, 0.0))
		builder.add_smart_box(clothes_t, Vector3(w - wall_t * 2.0 - 0.08, clothes_h, d * 0.65), texture_key, "clothes_hanging", 0.75, 0.01, false)


# =========================================================================
# 16. ROPERO ABIERTO CON ABRIGOS Y CHAQUETAS (WARDROBE)
# =========================================================================
class WardrobeOpenCoatsRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var p := params.duplicate()
		p["texture_key"] = params.get("texture_key", "wardrobe")
		WardrobeOpenClothesRecipe.build(builder, base_t, p)
