class_name Furniture2KitchenRecipes
extends RefCounted

## Recetas Oficiales: Cocina y Comedor (Furniture 2.0 - Imagen 2)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Modelos 1:1 fieles al asset pack "Interior Village" de elbolilloduro:
##   1. KitchenCornerWallCabinetRecipe - Alacena superior blanca con puertas shaker (cupboard_01)
##   2. KitchenBaseCounterSinkRecipe   - Encimera con fregadero de acero y mármol (cupboard, marble, metal)
##   3. KitchenIslandRecipe            - Isla central de cocina con encimera de mármol (cupboard_02, marble)
##   4. KitchenStoveGasWhiteRecipe     - Estufa de gas blanca con quemadores, panel y horno (stove)
##   5. KitchenRefrigeratorBeigeRecipe - Refrigerador retro crema con 2 puertas (refrigerator)
##   6. TableHexGinghamRackRecipe      - Mesa hexagonal mantel vichy con vajilla y escurreplatos (table, plates)
##   7. TableRectGinghamRecipe         - Mesa rectangular con mantel vichy rojo caído (table_01)
##   8. TableRectLaceFloralRecipe      - Mesa rectangular con mantel de encaje floreado (table_02)
##   9. KitchenHangingUtensilsRecipe   - Riel de pared con utensilios de cocina colgados (cutlery)
##  10. ChairKitchenSlatRecipe         - Silla de cocina de pino con respaldo de listones (chair_03)
##  11. ChairKitchenSpindleRecipe      - Silla de cocina con barrotes torneados Windsor (chair_04)
##  12. ChairKitchenUpholsteredRecipe  - Silla de comedor tapizada en bouclé marfil y patas oscuras (chair_05)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. ALACENA SUPERIOR BLANCA CON PUERTAS SHAKER (CUPBOARD_01)
# =========================================================================
class KitchenCornerWallCabinetRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.20)
		var d: float = params.get("depth", 0.36)
		var h: float = params.get("height", 0.72)
		var texture_key: String = params.get("texture_key", "cupboard_01")

		var wall_t := 0.02
		var door_count := 4
		var door_w := w / float(door_count)
		var door_thick := 0.022

		# Carcasa superior / inferior y laterales en esmalte blanco
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - wall_t * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w, wall_t, d), texture_key, "white_body")

		var bot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, wall_t * 0.5, 0.0))
		builder.add_smart_box(bot_t, Vector3(w, wall_t, d), texture_key, "white_body")

		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), h * 0.5, 0.0))
			builder.add_smart_box(s_t, Vector3(wall_t, h - wall_t * 2.0, d), texture_key, "white_body")

		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_smart_box(back_t, Vector3(w - wall_t * 2.0, h - wall_t * 2.0, wall_t), texture_key, "white_body")

		# 4 Puertas frontales blancas shaker alternando tiradores
		for i in range(door_count):
			var dx := -w * 0.5 + float(i) * door_w + door_w * 0.5
			var door_t := base_t * Transform3D(Basis.IDENTITY, Vector3(dx, h * 0.5, d * 0.5))
			var region := "door_left" if (i % 2 == 0) else "door_right"
			builder.add_smart_box(door_t, Vector3(door_w - 0.006, h - wall_t * 2.0 - 0.008, door_thick), texture_key, region)

			# Tirador vertical de acero inoxidable
			var handle_x := dx + (door_w * 0.35 if (i % 2 == 0) else -door_w * 0.35)
			var handle_t := base_t * Transform3D(Basis.IDENTITY, Vector3(handle_x, h * 0.5 - 0.10, d * 0.5 + 0.018))
			builder.add_cylinder(handle_t, 0.008, 0.12, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.15, 0.90, false)


# =========================================================================
# 2. ENCIMERA CON FREGADERO (CUPBOARD, MARBLE, METAL)
# =========================================================================
class KitchenBaseCounterSinkRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.80)
		var d: float = params.get("depth", 0.65)
		var h: float = params.get("height", 0.88)
		var cabinet_tex: String = params.get("cabinet_tex", "cupboard")
		var marble_tex: String = params.get("marble_tex", "marble")

		var plinth_h := 0.08
		var counter_thick := 0.04
		var body_h := h - plinth_h - counter_thick

		# 1. Zócalo inferior
		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, -0.02))
		builder.add_smart_box(plinth_t, Vector3(w - 0.02, plinth_h, d - 0.04), cabinet_tex, "white_body")

		# 2. Módulos de gabinetes y cajones blancos shaker
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + body_h * 0.5, 0.0))
		builder.add_panel_box(body_t, Vector3(w, body_h, d - 0.02), cabinet_tex, "doors", "white_body")

		# 3. Encimera de mármol negro pulido
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - counter_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.02, counter_thick, d + 0.02), marble_tex, "")

		# 4. Fregadero empotrado de acero inoxidable
		var sink_w := 0.52
		var sink_d := 0.42
		var sink_pos := Vector3(-0.35, h - 0.01, 0.02)
		var sink_t := base_t * Transform3D(Basis.IDENTITY, sink_pos)
		builder.add_smart_box(sink_t, Vector3(sink_w, 0.02, sink_d), "metal", "", 0.20, 0.85, false)

		# Cuenco hundido
		var basin_t := base_t * Transform3D(Basis.IDENTITY, sink_pos + Vector3(0.0, -0.08, 0.0))
		builder.add_smart_box(basin_t, Vector3(sink_w - 0.06, 0.14, sink_d - 0.06), "metal", "", 0.20, 0.85, false)

		# 5. Grifo mezclador curvado de cuello de ganso
		var faucet_base_t := base_t * Transform3D(Basis.IDENTITY, sink_pos + Vector3(0.0, 0.06, -sink_d * 0.5 + 0.04))
		builder.add_cylinder(faucet_base_t, 0.015, 0.14, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.10, 0.95, false)

		var faucet_spout_t := base_t * Transform3D(Basis.IDENTITY, sink_pos + Vector3(0.0, 0.16, -sink_d * 0.5 + 0.10))
		builder.add_smart_box(faucet_spout_t, Vector3(0.025, 0.025, 0.12), "metal", "", 0.10, 0.95, false)


# =========================================================================
# 3. ISLA CENTRAL DE COCINA (CUPBOARD_02, MARBLE)
# =========================================================================
class KitchenIslandRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.40)
		var d: float = params.get("depth", 0.85)
		var h: float = params.get("height", 0.90)
		var cabinet_tex: String = params.get("cabinet_tex", "cupboard_02")
		var marble_tex: String = params.get("marble_tex", "marble")

		var plinth_h := 0.08
		var counter_thick := 0.045
		var body_h := h - plinth_h - counter_thick

		# Zócalo inferior retranqueado
		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w - 0.06, plinth_h, d - 0.06), cabinet_tex, "grey_body")

		# Módulo de cajoneras y puertas gris suave shaker
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + body_h * 0.5, 0.0))
		builder.add_panel_box(body_t, Vector3(w, body_h, d - 0.04), cabinet_tex, "doors", "grey_body")

		# Encimera volada de mármol negro veteado
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - counter_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.10, counter_thick, d + 0.10), marble_tex, "")


# =========================================================================
# 4. ESTUFA DE GAS BLANCA CON HORNO (STOVE)
# =========================================================================
class KitchenStoveGasWhiteRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.76)
		var d: float = params.get("depth", 0.65)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "stove")

		var plinth_h := 0.06
		var splash_h := 0.10
		var cooktop_y := h

		# 1. Cuerpo principal blanco esmaltado
		var body_h := cooktop_y - plinth_h
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + body_h * 0.5, 0.0))
		builder.add_smart_box(body_t, Vector3(w, body_h, d), texture_key, "white_side")

		# 2. Puerta del horno con cristal y logo
		var door_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + body_h * 0.38, d * 0.5 + 0.01))
		builder.add_smart_box(door_t, Vector3(w - 0.06, body_h * 0.55, 0.025), texture_key, "oven_door")

		# Manija horizontal de acero
		var handle_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, plinth_h + body_h * 0.68, d * 0.5 + 0.035))
		builder.add_cylinder(handle_t, 0.012, w * 0.65, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.15, 0.85, false)

		# 3. Panel de perillas frontales
		var panel_y := cooktop_y - 0.05
		var panel_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, panel_y, d * 0.5 + 0.01))
		builder.add_smart_box(panel_t, Vector3(w - 0.04, 0.08, 0.02), texture_key, "knobs")

		for i in range(4):
			var knob_x := -w * 0.30 + float(i) * (w * 0.20)
			var knob_t := base_t * Transform3D(Basis.IDENTITY, Vector3(knob_x, panel_y, d * 0.5 + 0.026))
			builder.add_cylinder(knob_t, 0.018, 0.022, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.25, 0.60, false)

		# 4. Salpicadero posterior (Backsplash)
		var splash_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, cooktop_y + splash_h * 0.5, -d * 0.5 + 0.025))
		builder.add_smart_box(splash_t, Vector3(w, splash_h, 0.05), texture_key, "white_side")

		# 5. Superficie de parrilla y 4 Quemadores de gas
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, cooktop_y + 0.005, 0.0))
		builder.add_smart_box(top_t, Vector3(w - 0.02, 0.01, d - 0.04), texture_key, "burners")

		var burner_rect := ObjectAtlasScript.get_region("stove", "burners")
		for bx: float in [-1.0, 1.0]:
			for bz: float in [-1.0, 1.0]:
				var burner_pos := Vector3(bx * 0.18, cooktop_y + 0.018, bz * 0.16)
				var burner_t := base_t * Transform3D(Basis.IDENTITY, burner_pos)
				builder.add_cylinder(burner_t, 0.065, 0.02, "stove", burner_rect, 0.85, 0.15, false)


# =========================================================================
# 5. REFRIGERADOR RETRO CREMA (REFRIGERATOR)
# =========================================================================
class KitchenRefrigeratorBeigeRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.72)
		var d: float = params.get("depth", 0.68)
		var h: float = params.get("height", 1.70)
		var texture_key: String = params.get("texture_key", "refrigerator")

		var leg_h := 0.04
		var casing_h := h - leg_h

		# 4 Patas cromadas
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.05), leg_h * 0.5, sz * (d * 0.5 - 0.05)))
				builder.add_cylinder(leg_t, 0.025, leg_h, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.70, false)

		# Cuerpo principal redondeado crema
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, 0.0))
		builder.add_smart_box(body_t, Vector3(w, casing_h, d), texture_key, "enamel_body")

		# Puerta del congelador (superior)
		var freezer_h := casing_h * 0.32
		var freezer_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - freezer_h * 0.5, d * 0.5 + 0.015))
		builder.add_smart_box(freezer_t, Vector3(w - 0.02, freezer_h - 0.015, 0.03), texture_key, "freezer_door")

		# Puerta principal (inferior) con notas y magnetos
		var main_door_h := casing_h * 0.64
		var main_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + main_door_h * 0.5 + 0.01, d * 0.5 + 0.015))
		builder.add_smart_box(main_t, Vector3(w - 0.02, main_door_h - 0.015, 0.03), texture_key, "main_door")

		# Manijas cromadas curvas
		var f_handle_t := base_t * Transform3D(Basis.IDENTITY, Vector3(w * 0.38, h - freezer_h * 0.5, d * 0.5 + 0.045))
		builder.add_cylinder(f_handle_t, 0.012, 0.18, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.10, 0.95, false)

		var m_handle_t := base_t * Transform3D(Basis.IDENTITY, Vector3(w * 0.38, leg_h + main_door_h * 0.70, d * 0.5 + 0.045))
		builder.add_cylinder(m_handle_t, 0.012, 0.28, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.10, 0.95, false)


# =========================================================================
# 6. MESA HEXAGONAL MANTEL VICHY CON VAJILLA (TABLE, PLATES)
# =========================================================================
class TableHexGinghamRackRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var radius: float = params.get("radius", 0.65)
		var h: float = params.get("height", 0.76)
		var table_tex: String = params.get("table_tex", "table")
		var plates_tex: String = params.get("plates_tex", "plates")

		var leg_h := h - 0.05
		var top_thick := 0.05

		# 4 Patas de madera
		var leg_rect := ObjectAtlasScript.get_region(table_tex, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (radius * 0.55), leg_h * 0.5, sz * (radius * 0.55))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.025, leg_h, table_tex, leg_rect, 0.60, 0.02)

		# Tablero con mantel vichy rojo
		var cloth_rect := ObjectAtlasScript.get_region(table_tex, "gingham_cloth")
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_cylinder(top_t, radius, top_thick, table_tex, cloth_rect, 0.70, 0.01)

		# Caídas drapeadas del mantel
		var skirt_rect := ObjectAtlasScript.get_region(table_tex, "gingham_skirt")
		var skirt_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick - 0.12, 0.0))
		builder.add_cylinder(skirt_t, radius - 0.02, 0.24, table_tex, skirt_rect, 0.70, 0.01, false)

		# Escurreplatos y platos apilados
		var rack_pos := Vector3(0.0, h + 0.08, 0.0)
		var rack_t := base_t * Transform3D(Basis.IDENTITY, rack_pos)
		builder.add_smart_box(rack_t, Vector3(0.35, 0.16, 0.28), plates_tex, "", 0.35, 0.40, false)


# =========================================================================
# 7. MESA RECTANGULAR CON MANTEL VICHY ROJO (TABLE_01)
# =========================================================================
class TableRectGinghamRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.40)
		var d: float = params.get("depth", 0.85)
		var h: float = params.get("height", 0.76)
		var texture_key: String = params.get("texture_key", "table_01")

		var leg_h := h - 0.04
		var top_thick := 0.04

		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.028, leg_h, texture_key, leg_rect, 0.60, 0.02)

		# Tablero cubierto por mantel rojo a cuadros
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.08, top_thick, d + 0.08), texture_key, "gingham_top")

		# Caídas del mantel en las cuatro esquinas
		var skirt_h := 0.25
		var skirt_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick - skirt_h * 0.5, 0.0))
		builder.add_smart_box(skirt_t, Vector3(w + 0.06, skirt_h, d + 0.06), texture_key, "lace_trim", -1.0, -1.0, false)


# =========================================================================
# 8. MESA RECTANGULAR CON MANTEL DE ENCAJE FLOREADO (TABLE_02)
# =========================================================================
class TableRectLaceFloralRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.50)
		var d: float = params.get("depth", 0.90)
		var h: float = params.get("height", 0.76)
		var texture_key: String = params.get("texture_key", "table_02")

		var leg_h := h - 0.04
		var top_thick := 0.04

		var leg_rect := ObjectAtlasScript.get_region(texture_key, "dark_walnut")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.028, leg_h, texture_key, leg_rect, 0.60, 0.02)

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w + 0.06, top_thick, d + 0.06), texture_key, "lace_cloth")

		var skirt_h := 0.28
		var skirt_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick - skirt_h * 0.5, 0.0))
		builder.add_smart_box(skirt_t, Vector3(w + 0.04, skirt_h, d + 0.04), texture_key, "lace_cloth", -1.0, -1.0, false)


# =========================================================================
# 9. RIEL DE PARED CON UTENSILIOS DE COCINA (CUTLERY)
# =========================================================================
class KitchenHangingUtensilsRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.85)
		var texture_key: String = params.get("texture_key", "cutlery")

		# Barra metálica horizontal
		var bar_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, 0.0, 0.0))
		builder.add_cylinder(bar_t, 0.01, w, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.15, 0.85, false)

		# Soportes de pared en los extremos
		for side: float in [-1.0, 1.0]:
			var mount_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - 0.03), 0.0, -0.025))
			builder.add_cylinder(mount_t, 0.015, 0.05, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.20, 0.80, false)

		# Placa de utensilios colgantes
		var utensil_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.16, 0.005))
		builder.add_smart_box(utensil_t, Vector3(w * 0.80, 0.32, 0.01), texture_key, "", 0.30, 0.60, false)


# =========================================================================
# 10. SILLA DE COCINA DE PINO CON RESPALDO DE LISTONES (CHAIR_03)
# =========================================================================
class ChairKitchenSlatRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.44)
		var d: float = params.get("depth", 0.46)
		var h: float = params.get("height", 0.88)
		var texture_key: String = params.get("texture_key", "chair_03")

		var seat_h := 0.45
		var seat_thick := 0.03

		# 4 Patas
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_leg")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.04), seat_h * 0.5, sz * (d * 0.5 - 0.04))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.018, seat_h, texture_key, leg_rect, 0.60, 0.02)

		# Asiento de pino
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + seat_thick * 0.5, 0.0))
		builder.add_smart_box(seat_t, Vector3(w, seat_thick, d), texture_key, "wood_seat")

		# Respaldo de listones verticales
		var back_h := h - seat_h - seat_thick
		var back_z := -d * 0.5 + 0.02
		for side: float in [-1.0, 1.0]:
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - 0.03), seat_h + seat_thick + back_h * 0.5, back_z))
			builder.add_cylinder(post_t, 0.016, back_h, texture_key, leg_rect, 0.60, 0.02)

		# Travesaño superior curvo
		var top_rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.025, back_z))
		builder.add_smart_box(top_rail_t, Vector3(w, 0.05, 0.025), texture_key, "wood_seat")

		# 3 Listones verticales centrales
		for i in range(3):
			var lx := -0.09 + float(i) * 0.09
			var slat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(lx, seat_h + seat_thick + back_h * 0.48, back_z))
			builder.add_smart_box(slat_t, Vector3(0.02, back_h - 0.06, 0.015), texture_key, "slat_back")


# =========================================================================
# 11. SILLA DE COCINA CON BARROTES TORNEADOS WINDSOR (CHAIR_04)
# =========================================================================
class ChairKitchenSpindleRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.46)
		var d: float = params.get("depth", 0.48)
		var h: float = params.get("height", 0.92)
		var texture_key: String = params.get("texture_key", "chair_04")

		var seat_h := 0.45
		var seat_thick := 0.035

		# 4 Patas torneadas
		var wood_rect := ObjectAtlasScript.get_region(texture_key, "wood_seat")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.05), seat_h * 0.5, sz * (d * 0.5 - 0.05))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.016, seat_h, texture_key, wood_rect, 0.60, 0.02)

		# Asiento redondeado
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + seat_thick * 0.5, 0.0))
		builder.add_smart_box(seat_t, Vector3(w, seat_thick, d), texture_key, "wood_seat")

		# Respaldo en arco con 5 husos torneados
		var back_h := h - seat_h - seat_thick
		var back_z := -d * 0.5 + 0.03

		# Arco superior
		var arch_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.02, back_z))
		builder.add_smart_box(arch_t, Vector3(w - 0.02, 0.04, 0.025), texture_key, "wood_seat")

		# 5 Husos torneados verticales
		var spindle_rect := ObjectAtlasScript.get_region(texture_key, "spindles")
		for i in range(5):
			var sp_x := -w * 0.35 + float(i) * (w * 0.175)
			var sp_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sp_x, seat_h + seat_thick + back_h * 0.48, back_z))
			builder.add_cylinder(sp_t, 0.009, back_h - 0.05, texture_key, spindle_rect, 0.55, 0.02)


# =========================================================================
# 12. SILLA DE COMEDOR TAPIZADA EN BOUCLÉ MARFIL (CHAIR_05)
# =========================================================================
class ChairKitchenUpholsteredRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.48)
		var d: float = params.get("depth", 0.50)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "chair_05")

		var seat_h := 0.46
		var seat_thick := 0.06

		# 4 Patas oscuras cónicas
		var leg_rect := ObjectAtlasScript.get_region(texture_key, "wood_legs")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.05), (seat_h - seat_thick * 0.5) * 0.5, sz * (d * 0.5 - 0.05))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.018, seat_h - seat_thick * 0.5, texture_key, leg_rect, 0.60, 0.02)

		# Asiento acolchado grueso bouclé
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.0))
		builder.add_smart_box(seat_t, Vector3(w, seat_thick, d), texture_key, "boucle_seat")

		# Respaldo acolchado bouclé
		var back_h := h - seat_h - seat_thick * 0.5
		var back_z := -d * 0.5 + 0.035
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, back_z))
		builder.add_smart_box(back_t, Vector3(w - 0.04, back_h, 0.06), texture_key, "boucle_back")
