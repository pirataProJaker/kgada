class_name Furniture2KitchenRecipes
extends RefCounted

## Recetas Oficiales: Cocina y Comedor (Furniture 2.0 - Imagen 2)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Modelos 1:1 fieles al asset pack "Interior Village" de elbolilloduro:
##   1. KitchenCornerWallCabinetRecipe - Alacena superior esquinera blanca (fitment)
##   2. KitchenBaseCounterSinkRecipe   - Encimera en L con fregadero de acero y mármol (fitment, marble)
##   3. KitchenIslandRecipe            - Isla central de cocina con encimera de mármol (fitment, marble)
##   4. KitchenStoveGasWhiteRecipe     - Estufa de gas blanca con 4 quemadores y horno (stove)
##   5. KitchenRefrigeratorBeigeRecipe - Refrigerador retro crema con 2 puertas (refrigerator)
##   6. TableHexGinghamRackRecipe      - Mesa hexagonal mantel vichy con vajilla y escurreplatos (table, plates)
##   7. TableRectGinghamRecipe         - Mesa rectangular con mantel vichy rojo caído (table_01)
##   8. TableRectLaceFloralRecipe      - Mesa rectangular con mantel de encaje floreado (table_02)
##   9. KitchenHangingUtensilsRecipe   - Riel de pared con utensilios de cocina colgados (cutlery)
##  10. ChairKitchenSlatRecipe         - Silla de cocina de pino con respaldo de listones (chair)
##  11. ChairKitchenSpindleRecipe      - Silla de cocina con barrotes torneados Windsor (chair_01)
##  12. ChairKitchenUpholsteredRecipe  - Silla de comedor tapizada en tela beige y patas oscuras (chair_02)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. ALACENA SUPERIOR ESQUINERA BLANCA (FITMENT)
# =========================================================================
class KitchenCornerWallCabinetRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.20)
		var d: float = params.get("depth", 0.36)
		var h: float = params.get("height", 0.72)
		var texture_key: String = params.get("texture_key", "fitment")

		var wall_t := 0.02
		var door_count := 4
		var door_w := w / float(door_count)
		var door_thick := 0.022

		# Carcasa superior / inferior y laterales
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - wall_t * 0.5, 0.0))
		builder.add_box(top_t, Vector3(w, wall_t, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.10)

		var bot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, wall_t * 0.5, 0.0))
		builder.add_box(bot_t, Vector3(w, wall_t, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.10)

		for side: float in [-1.0, 1.0]:
			var s_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - wall_t * 0.5), h * 0.5, 0.0))
			builder.add_box(s_t, Vector3(wall_t, h - wall_t * 2.0, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.10)

		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + wall_t * 0.5))
		builder.add_box(back_t, Vector3(w - wall_t * 2.0, h - wall_t * 2.0, wall_t), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.35, 0.05)

		# 4 Puertas frontales blancas con ranura y tirador vertical
		for i in range(door_count):
			var dx := -w * 0.5 + float(i) * door_w + door_w * 0.5
			var door_t := base_t * Transform3D(Basis.IDENTITY, Vector3(dx, h * 0.5, d * 0.5))
			builder.add_box(door_t, Vector3(door_w - 0.006, h - wall_t * 2.0 - 0.008, door_thick), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.25, 0.15)

			# Tirador vertical de acero inoxidable
			var handle_x := dx + (door_w * 0.35 if (i % 2 == 0) else -door_w * 0.35)
			var handle_t := base_t * Transform3D(Basis.IDENTITY, Vector3(handle_x, h * 0.5 - 0.10, d * 0.5 + 0.018))
			builder.add_cylinder(handle_t, 0.008, 0.12, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.15, 0.90, false)


# =========================================================================
# 2. ENCIMERA EN L CON FREGADERO (FITMENT, MARBLE)
# =========================================================================
class KitchenBaseCounterSinkRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.80)
		var d: float = params.get("depth", 0.65)
		var h: float = params.get("height", 0.88)
		var cabinet_tex: String = params.get("cabinet_tex", "fitment")
		var marble_tex: String = params.get("marble_tex", "marble")

		var plinth_h := 0.08
		var counter_thick := 0.04
		var body_h := h - plinth_h - counter_thick

		# 1. Zócalo inferior
		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, -0.02))
		builder.add_box(plinth_t, Vector3(w - 0.02, plinth_h, d - 0.04), cabinet_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.40, 0.10)

		# 2. Cuerpo de gabinetes modulares blancos
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + body_h * 0.5, 0.0))
		builder.add_box(body_t, Vector3(w, body_h, d - 0.02), cabinet_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.10)

		# 3. Encimera de mármol negro pulido
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - counter_thick * 0.5, 0.0))
		builder.add_box(top_t, Vector3(w + 0.02, counter_thick, d + 0.02), marble_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.15, 0.20)

		# 4. Fregadero empotrado de acero inoxidable
		var sink_w := 0.52
		var sink_d := 0.42
		var sink_pos := Vector3(-0.35, h - 0.01, 0.02)
		var sink_t := base_t * Transform3D(Basis.IDENTITY, sink_pos)
		builder.add_box(sink_t, Vector3(sink_w, 0.02, sink_d), "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.20, 0.85, false)

		# Cuenco hundido
		var basin_t := base_t * Transform3D(Basis.IDENTITY, sink_pos + Vector3(0.0, -0.08, 0.0))
		builder.add_box(basin_t, Vector3(sink_w - 0.06, 0.14, sink_d - 0.06), "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.20, 0.85, false)

		# 5. Grifo mezclador curvado de cuello de ganso
		var faucet_base_t := base_t * Transform3D(Basis.IDENTITY, sink_pos + Vector3(0.0, 0.06, -sink_d * 0.5 + 0.04))
		builder.add_cylinder(faucet_base_t, 0.015, 0.14, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.10, 0.95, false)

		var faucet_spout_t := base_t * Transform3D(Basis.IDENTITY, sink_pos + Vector3(0.0, 0.16, -sink_d * 0.5 + 0.10))
		builder.add_box(faucet_spout_t, Vector3(0.025, 0.025, 0.12), "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.10, 0.95, false)


# =========================================================================
# 3. ISLA CENTRAL DE COCINA (FITMENT, MARBLE)
# =========================================================================
class KitchenIslandRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.40)
		var d: float = params.get("depth", 0.85)
		var h: float = params.get("height", 0.90)
		var cabinet_tex: String = params.get("cabinet_tex", "fitment")
		var marble_tex: String = params.get("marble_tex", "marble")

		var plinth_h := 0.08
		var counter_thick := 0.045
		var body_h := h - plinth_h - counter_thick

		# Zócalo inferior retranqueado
		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_box(plinth_t, Vector3(w - 0.06, plinth_h, d - 0.06), cabinet_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.40, 0.10)

		# Módulo de cajoneras y puertas blancas
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + body_h * 0.5, 0.0))
		builder.add_box(body_t, Vector3(w, body_h, d - 0.04), cabinet_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.28, 0.10)

		# Encimera volada de mármol negro veteado
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - counter_thick * 0.5, 0.0))
		builder.add_box(top_t, Vector3(w + 0.10, counter_thick, d + 0.10), marble_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.12, 0.22)


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
		builder.add_box(body_t, Vector3(w, body_h, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.15)

		# 2. Puerta del horno con ventana de cristal ahumado y manija
		var door_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + body_h * 0.45, d * 0.5 + 0.01))
		builder.add_box(door_t, Vector3(w - 0.06, body_h * 0.60, 0.025), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.20, 0.30)

		# Manija horizontal de acero
		var handle_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, plinth_h + body_h * 0.72, d * 0.5 + 0.035))
		builder.add_cylinder(handle_t, 0.012, w * 0.65, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.15, 0.85, false)

		# 3. Panel de perillas frontales
		var panel_y := cooktop_y - 0.06
		for i in range(4):
			var knob_x := -w * 0.30 + float(i) * (w * 0.20)
			var knob_t := base_t * Transform3D(Basis.IDENTITY, Vector3(knob_x, panel_y, d * 0.5 + 0.02))
			builder.add_cylinder(knob_t, 0.018, 0.022, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.25, 0.60, false)

		# 4. Salpicadero posterior (Backsplash)
		var splash_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, cooktop_y + splash_h * 0.5, -d * 0.5 + 0.025))
		builder.add_box(splash_t, Vector3(w, splash_h, 0.05), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.15)

		# 5. 4 Quemadores de gas circulares
		for bx: float in [-1.0, 1.0]:
			for bz: float in [-1.0, 1.0]:
				var burner_pos := Vector3(bx * 0.18, cooktop_y + 0.015, bz * 0.16)
				var burner_t := base_t * Transform3D(Basis.IDENTITY, burner_pos)
				builder.add_cylinder(burner_t, 0.065, 0.02, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.40, 0.50, false)


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

		# 4 Patas de apoyo
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 - 0.05), leg_h * 0.5, sz * (d * 0.5 - 0.05)))
				builder.add_cylinder(leg_t, 0.025, leg_h, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.60, 0.20, false)

		# Cuerpo principal redondeado crema
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + casing_h * 0.5, 0.0))
		builder.add_box(body_t, Vector3(w, casing_h, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.32, 0.12)

		# Puerta del congelador (superior)
		var freezer_h := casing_h * 0.32
		var freezer_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - freezer_h * 0.5, d * 0.5 + 0.015))
		builder.add_box(freezer_t, Vector3(w - 0.02, freezer_h - 0.015, 0.03), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.28, 0.15)

		# Puerta principal (inferior)
		var main_door_h := casing_h * 0.64
		var main_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, leg_h + main_door_h * 0.5 + 0.01, d * 0.5 + 0.015))
		builder.add_box(main_t, Vector3(w - 0.02, main_door_h - 0.015, 0.03), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.28, 0.15)

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
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (radius * 0.55), leg_h * 0.5, sz * (radius * 0.55))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.025, leg_h, table_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.55, 0.02)

		# Tablero con mantel vichy rojo hexagonal
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_cylinder(top_t, radius, top_thick, table_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.65, 0.02)

		# Caídas drapeadas del mantel a los costados
		var skirt_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick - 0.12, 0.0))
		builder.add_cylinder(skirt_t, radius - 0.02, 0.24, table_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.70, 0.01, false)

		# Escurreplatos y platos apilados
		var rack_pos := Vector3(0.0, h + 0.08, 0.0)
		var rack_t := base_t * Transform3D(Basis.IDENTITY, rack_pos)
		builder.add_box(rack_t, Vector3(0.35, 0.16, 0.28), plates_tex, Rect2(0.0, 0.0, 1.0, 1.0), 0.35, 0.40, false)


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

		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.028, leg_h, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.55, 0.02)

		# Tablero cubierto por mantel rojo a cuadros
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_box(top_t, Vector3(w + 0.08, top_thick, d + 0.08), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.65, 0.01)

		# Caídas del mantel en las cuatro esquinas
		var skirt_h := 0.25
		var skirt_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick - skirt_h * 0.5, 0.0))
		builder.add_box(skirt_t, Vector3(w + 0.06, skirt_h, d + 0.06), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.70, 0.01, false)


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

		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.08), leg_h * 0.5, sz * (d * 0.5 - 0.08))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.028, leg_h, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.50, 0.02)

		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_box(top_t, Vector3(w + 0.06, top_thick, d + 0.06), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.60, 0.02)

		var skirt_h := 0.28
		var skirt_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick - skirt_h * 0.5, 0.0))
		builder.add_box(skirt_t, Vector3(w + 0.04, skirt_h, d + 0.04), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.65, 0.01, false)


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

		# Placa de utensilios colgantes (cucharón, espátula, tenedor, espumadera)
		var utensil_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.16, 0.005))
		builder.add_box(utensil_t, Vector3(w * 0.80, 0.32, 0.01), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.30, 0.60, false)


# =========================================================================
# 10. SILLA DE COCINA DE PINO CON RESPALDO DE LISTONES (CHAIR)
# =========================================================================
class ChairKitchenSlatRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.44)
		var d: float = params.get("depth", 0.46)
		var h: float = params.get("height", 0.88)
		var texture_key: String = params.get("texture_key", "chair")

		var seat_h := 0.45
		var seat_thick := 0.03

		# 4 Patas
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.04), seat_h * 0.5, sz * (d * 0.5 - 0.04))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.018, seat_h, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.52, 0.02)

		# Asiento de pino
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + seat_thick * 0.5, 0.0))
		builder.add_box(seat_t, Vector3(w, seat_thick, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.48, 0.02)

		# Respaldo de listones verticales
		var back_h := h - seat_h - seat_thick
		var back_z := -d * 0.5 + 0.02
		# 2 Postes laterales del respaldo
		for side: float in [-1.0, 1.0]:
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(side * (w * 0.5 - 0.03), seat_h + seat_thick + back_h * 0.5, back_z))
			builder.add_cylinder(post_t, 0.016, back_h, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.50, 0.02)

		# Travesaño superior curvo
		var top_rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.025, back_z))
		builder.add_box(top_rail_t, Vector3(w, 0.05, 0.025), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.45, 0.02)

		# 3 Listones verticales centrales
		for i in range(3):
			var lx := -0.09 + float(i) * 0.09
			var slat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(lx, seat_h + seat_thick + back_h * 0.48, back_z))
			builder.add_box(slat_t, Vector3(0.02, back_h - 0.06, 0.015), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.52, 0.02)


# =========================================================================
# 11. SILLA DE COCINA CON BARROTES TORNEADOS WINDSOR (CHAIR_01)
# =========================================================================
class ChairKitchenSpindleRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.46)
		var d: float = params.get("depth", 0.48)
		var h: float = params.get("height", 0.92)
		var texture_key: String = params.get("texture_key", "chair_01")

		var seat_h := 0.45
		var seat_thick := 0.035

		# 4 Patas torneadas inclinadas
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.05), seat_h * 0.5, sz * (d * 0.5 - 0.05))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.016, seat_h, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.50, 0.02)

		# Asiento redondeado
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + seat_thick * 0.5, 0.0))
		builder.add_box(seat_t, Vector3(w, seat_thick, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.45, 0.02)

		# Respaldo en arco con 5 husos/barrotes torneados
		var back_h := h - seat_h - seat_thick
		var back_z := -d * 0.5 + 0.03

		# Arco superior
		var arch_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.02, back_z))
		builder.add_box(arch_t, Vector3(w - 0.02, 0.04, 0.025), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.45, 0.02)

		# 5 Husos torneados verticales
		for i in range(5):
			var sp_x := -w * 0.35 + float(i) * (w * 0.175)
			var sp_t := base_t * Transform3D(Basis.IDENTITY, Vector3(sp_x, seat_h + seat_thick + back_h * 0.48, back_z))
			builder.add_cylinder(sp_t, 0.009, back_h - 0.05, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.50, 0.02)


# =========================================================================
# 12. SILLA DE COMEDOR TAPIZADA EN TELA BEIGE (CHAIR_02)
# =========================================================================
class ChairKitchenUpholsteredRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.48)
		var d: float = params.get("depth", 0.50)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "chair_02")

		var seat_h := 0.46
		var seat_thick := 0.06

		# 4 Patas oscuras elegantes
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var leg_pos := Vector3(sx * (w * 0.5 - 0.05), (seat_h - seat_thick * 0.5) * 0.5, sz * (d * 0.5 - 0.05))
				var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
				builder.add_cylinder(leg_t, 0.018, seat_h - seat_thick * 0.5, texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.45, 0.02)

		# Asiento acolchado grueso tapizado en tela beige
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.0))
		builder.add_box(seat_t, Vector3(w, seat_thick, d), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.65, 0.05)

		# Respaldo acolchado completo
		var back_h := h - seat_h - seat_thick * 0.5
		var back_z := -d * 0.5 + 0.035
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h * 0.5, back_z))
		builder.add_box(back_t, Vector3(w - 0.04, back_h, 0.06), texture_key, Rect2(0.0, 0.0, 1.0, 1.0), 0.65, 0.05)
