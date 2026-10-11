class_name AppliancesRecipes
extends RefCounted

## Recetas Oficiales de Electrodomésticos y Gabinetes para el Motor de Objetos (Play Sector X)
## Arquitectura: +0 Draw Calls (Vinculado 100% al Atlas Inteligente ObjectAtlas)
## Modelos geométricos fieles 1:1 a los originales de referencia con mapeo semántico exacto.

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. REFRIGERADOR DOMÉSTICO (REFRIGERATOR CON PUERTAS ABATIBLES)
# =========================================================================
class RefrigeratorRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var is_open: bool = params.get("is_open", false)
		var texture_key: String = params.get("texture_key", "refrigerador")

		var w := 0.72
		var d := 0.68
		var h := 1.68
		var grille_h := 0.10
		var door_t := 0.055
		var body_d := d - door_t
		var wall_t := 0.045

		# 1. Gabinete / Carcasa principal esmaltada
		var body_center_z := -door_t * 0.5
		# Paredes laterales y techo
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + wall_t * 0.5, h * 0.5, body_center_z)), Vector3(wall_t, h, body_d), texture_key, "metal_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - wall_t * 0.5, h * 0.5, body_center_z)), Vector3(wall_t, h, body_d), texture_key, "metal_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - wall_t * 0.5, body_center_z)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "metal_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, grille_h + wall_t * 0.5, body_center_z)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "metal_body")
		# Fondo posterior
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + wall_t * 0.5)), Vector3(w, h, wall_t), texture_key, "metal_body")

		# 2. Rejilla inferior de ventilación frontal
		var grille_z := d * 0.5 - wall_t * 0.5
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, grille_h * 0.5, grille_z)), Vector3(w, grille_h, wall_t), texture_key, "grille", "metal_body")

		# 3. Dimensiones de puertas
		var main_h := (h - grille_h) * 0.58
		var freezer_h := (h - grille_h) * 0.40
		var gap := (h - grille_h) * 0.02
		var main_y := grille_h + main_h * 0.5
		var freezer_y := grille_h + main_h + gap + freezer_h * 0.5
		var door_front_z := body_d * 0.5 + door_t * 0.5

		# 4. Divisor interno entre congelador y nevera
		var sep_y := grille_h + main_h + gap * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sep_y, body_center_z)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "metal_body")

		if not is_open:
			# Puerta congelador cerrada (+Z con bisel y logo CFE/marca, bordes con metal_body)
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, freezer_y, door_front_z)), Vector3(w, freezer_h, door_t), texture_key, "freezer_door", "metal_body")
			# Puerta principal cerrada
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, main_y, door_front_z)), Vector3(w, main_h, door_t), texture_key, "main_door", "metal_body")

			# Manijas cromadas verticales estilizadas
			var h_freezer_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.05, freezer_y - 0.12, d * 0.5 + 0.015))
			builder.add_smart_cylinder(h_freezer_t, 0.012, 0.22, texture_key, "handle", 0.20, 0.85, false)
			var h_main_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.05, main_y + 0.18, d * 0.5 + 0.015))
			builder.add_smart_cylinder(h_main_t, 0.012, 0.32, texture_key, "handle", 0.20, 0.85, false)
		else:
			# Puertas abiertas rotadas en bisagra derecha
			var rot_open := Basis(Vector3.UP, deg_to_rad(105.0))
			var hinge_x := w * 0.5
			var hinge_z := body_d * 0.5

			var freezer_pivot := base_t * Transform3D(rot_open, Vector3(hinge_x, freezer_y, hinge_z))
			builder.add_panel_box(freezer_pivot * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, 0.0, door_t * 0.5)), Vector3(w, freezer_h, door_t), texture_key, "freezer_door", "metal_body")

			var main_pivot := base_t * Transform3D(rot_open, Vector3(hinge_x, main_y, hinge_z))
			builder.add_panel_box(main_pivot * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, 0.0, door_t * 0.5)), Vector3(w, main_h, door_t), texture_key, "main_door", "metal_body")

			# Repisas interiores de cristal expuestas
			var inner_w := w - wall_t * 2.0 - 0.02
			var shelf_d := body_d - 0.06
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, grille_h + main_h * 0.35, body_center_z)), Vector3(inner_w, 0.015, shelf_d), texture_key, "shelves", 0.15, 0.20, false)
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, grille_h + main_h * 0.70, body_center_z)), Vector3(inner_w, 0.015, shelf_d), texture_key, "shelves", 0.15, 0.20, false)
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, freezer_y, body_center_z)), Vector3(inner_w, 0.015, shelf_d), texture_key, "shelves", 0.15, 0.20, false)


# =========================================================================
# 2. ESTUFA DE COCINA (STOVE)
# =========================================================================
class StoveRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "estufa")
		var is_open: bool = params.get("is_open", false)

		var w := 0.76
		var d := 0.66
		var h := 0.86
		var drawer_h := 0.18
		var oven_h := 0.44
		var bg_h := 0.15
		var bg_t := 0.06
		var door_t := 0.045
		var wall_t := 0.040

		var hw := w * 0.5
		var hd := d * 0.5

		# 1. Base / Cajón inferior calientaplatos (+Z panel con drawer, cuerpo side)
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_h * 0.5, 0.0)), Vector3(w, drawer_h, d), texture_key, "drawer", "side")

		# 2. Laterales y fondo del horno
		var side_h := h - drawer_h
		var side_y := drawer_h + side_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + wall_t * 0.5, side_y, 0.0)), Vector3(wall_t, side_h, d), texture_key, "side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - wall_t * 0.5, side_y, 0.0)), Vector3(wall_t, side_h, d), texture_key, "side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, side_y, -hd + wall_t * 0.5)), Vector3(w, side_h, wall_t), texture_key, "side")

		# 3. Marco superior frontal sobre la puerta del horno
		var top_lip_h := h - (drawer_h + oven_h)
		var top_lip_y := drawer_h + oven_h + top_lip_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, top_lip_y, hd - wall_t * 0.5)), Vector3(w, top_lip_h, wall_t), texture_key, "side")

		# 4. Puerta del Horno (Frontal con cristal ahumado y manija de horno)
		var oven_y := drawer_h + oven_h * 0.5
		var oven_z := hd - door_t * 0.5
		if not is_open:
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, oven_y, oven_z)), Vector3(w - wall_t * 0.5, oven_h - 0.01, door_t), texture_key, "oven_door", "side")
		else:
			# Abatida hacia adelante en bisagra inferior
			var rot_oven := Basis(Vector3.RIGHT, deg_to_rad(85.0))
			var oven_pivot := base_t * Transform3D(rot_oven, Vector3(0.0, drawer_h, hd))
			builder.add_panel_box(oven_pivot * Transform3D(Basis.IDENTITY, Vector3(0.0, oven_h * 0.5, door_t * 0.5)), Vector3(w - wall_t * 0.5, oven_h - 0.01, door_t), texture_key, "oven_door", "side")

		# 5. Rejilla metálica interior del horno
		var inner_w := w - wall_t * 2.0 - 0.02
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_h + oven_h * 0.45, 0.0)), Vector3(inner_w, 0.012, d - wall_t * 2.0 - 0.04), texture_key, "side", 0.30, 0.80, false)

		# 6. Cubierta Superior con los 4 Quemadores (+Y con textura burners del atlas, cantos con side)
		var cooktop_y := h - 0.015
		builder.add_top_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, cooktop_y, 0.0)), Vector3(w, 0.03, d), texture_key, "burners", "side")

		# 7. Copete Posterior con Panel de Control (Display y reloj en +Z)
		var bg_y := h + bg_h * 0.5
		var bg_z := -hd + bg_t * 0.5
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, bg_y, bg_z)), Vector3(w, bg_h, bg_t), texture_key, "backguard", "side")

		# 8. Perillas cromadas frontales en el copete
		for i in range(4):
			var px := -0.22 + float(i) * 0.15
			var knob_t := base_t * Transform3D(Basis(Vector3.RIGHT, 1.570796), Vector3(px, bg_y - 0.02, bg_z + bg_t * 0.5 + 0.015))
			builder.add_smart_cylinder(knob_t, 0.018, 0.022, texture_key, "knobs", 0.25, 0.85, false)


# =========================================================================
# 3. MICROONDAS (MICROWAVE)
# =========================================================================
class MicrowaveRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "microondas")
		var is_open: bool = params.get("is_open", false)

		var w := 0.52
		var d := 0.38
		var h := 0.32
		var wall_t := 0.025
		var door_w := w * 0.72
		var panel_w := w - door_w
		var door_t := 0.030

		var hw := w * 0.5
		var hd := d * 0.5
		var body_d := d - door_t

		# 1. Carcasa principal (techo, fondo, base, laterales)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -hd + wall_t * 0.5)), Vector3(w, h, wall_t), texture_key, "metal")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - wall_t * 0.5, 0.0)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "metal")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, wall_t * 0.5, 0.0)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "metal")
		# Lateral izquierdo con rejilla de ventilación del atlas
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + wall_t * 0.5, h * 0.5, 0.0)), Vector3(wall_t, h, body_d), texture_key, "vent")
		# Lateral derecho metálico liso
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - wall_t * 0.5, h * 0.5, 0.0)), Vector3(wall_t, h, body_d), texture_key, "metal")

		# 2. Panel frontal fijo de control a la derecha (+X) con teclado numérico
		var panel_center_x := hw - panel_w * 0.5
		var panel_center_z := hd - door_t * 0.5
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(panel_center_x, h * 0.5, panel_center_z)), Vector3(panel_w, h, door_t), texture_key, "control_panel", "metal")

		# 3. Puerta batiente frontal izquierda con ventana de cristal y manija
		var door_center_x := -hw + door_w * 0.5
		if not is_open:
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(door_center_x, h * 0.5, panel_center_z)), Vector3(door_w - 0.005, h - 0.005, door_t), texture_key, "door_window", "metal")
		else:
			# Bisagra izquierda rotada a -95 grados
			var rot_door := Basis(Vector3.UP, deg_to_rad(-95.0))
			var door_pivot := base_t * Transform3D(rot_door, Vector3(-hw, h * 0.5, panel_center_z))
			builder.add_panel_box(door_pivot * Transform3D(Basis.IDENTITY, Vector3(door_w * 0.5, 0.0, 0.0)), Vector3(door_w - 0.005, h - 0.005, door_t), texture_key, "door_window", "metal")

		# 4. Cavidad interior de cocción oscura y plato giratorio
		var cavity_w := door_w - wall_t * 2.0
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(door_center_x, h * 0.5, -hd + wall_t + 0.01)), Vector3(cavity_w, h - wall_t * 2.0, 0.015), texture_key, "cavity")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(door_center_x, wall_t + 0.006, 0.0)), Vector3(cavity_w * 0.85, 0.010, body_d * 0.75), texture_key, "plate")


# =========================================================================
# 4. LAVADORA Y SECADORA (WASHER & DRYER)
# =========================================================================
class WasherRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "washer")
		var is_open: bool = params.get("is_open", false)
		var w := 0.68
		var d := 0.68
		var h := 0.88
		var console_h := 0.16
		var console_d := 0.12
		var top_d := 0.065
		var wedge_d := console_d - top_d # 0.055m
		var wall_t := 0.025

		var hw := w * 0.5
		var hd := d * 0.5

		# 1. Carcasa principal de esmalte blanco (Base, Trasera, Laterales)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, wall_t * 0.5, 0.0)), Vector3(w, wall_t, d), texture_key, "white_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -hd + wall_t * 0.5)), Vector3(w, h, wall_t), texture_key, "white_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + wall_t * 0.5, h * 0.5, 0.0)), Vector3(wall_t, h, d), texture_key, "white_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - wall_t * 0.5, h * 0.5, 0.0)), Vector3(wall_t, h, d), texture_key, "white_body")

		# Frontal blanco limpio con costura superior negra continua
		var front_z := hd - wall_t * 0.5
		var seam_h := 0.012
		var lower_front_h := h - seam_h
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, lower_front_h * 0.5, front_z)), Vector3(w, lower_front_h, wall_t), texture_key, "white_body")
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - seam_h * 0.5, front_z + 0.001)), Vector3(w, seam_h, wall_t), texture_key, "front_seam", "white_body")

		# 2. Copete trasero en cuña (Prisma triangular + caja posterior + panel centrado)
		var back_box_z := -hd + top_d * 0.5
		var wedge_z := -hd + top_d + wedge_d * 0.5
		var console_center_y := h + console_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, console_center_y, back_box_z)), Vector3(w, console_h, top_d), texture_key, "white_body")
		builder.add_smart_wedge(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, console_center_y, wedge_z)), Vector3(w, console_h, wedge_d), texture_key, "white_body")

		# Panel frontal con perillas y display LED azul centrado sobre la rampa
		var ctrl_w := 0.46
		var ctrl_slant_len := sqrt(console_h * console_h + wedge_d * wedge_d)
		var rot_x := -atan2(wedge_d, console_h)
		var rot_slope := Basis(Vector3.RIGHT, rot_x)
		var slope_pos := Vector3(0.0, console_center_y, wedge_z)
		var quad_t := base_t * Transform3D(rot_slope, slope_pos + rot_slope * Vector3(0.0, 0.0, 0.002))
		builder.add_smart_quad(quad_t, Vector2(ctrl_w, ctrl_slant_len * 0.94), texture_key, "control_panel")

		# 3. Encimera superior (Top Deck) con marco perimetral alrededor del hueco de la tina
		var deck_z_start := -hd + console_d
		var deck_d := d - console_d
		var deck_center_z := deck_z_start + deck_d * 0.5
		var lid_w := 0.48
		var lid_d := 0.42
		var lid_thickness := 0.018
		var hole_offset := Vector2(0.0, 0.0)

		var deck_t_pos := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - wall_t * 0.5, deck_center_z))
		builder.add_cutout_surface(deck_t_pos, Vector3(w, wall_t, deck_d), Vector2(lid_w, lid_d), hole_offset, texture_key, "white_body")

		# 4. Tambor de acero inoxidable cilíndrico interior y agitador central
		var tub_cz := deck_center_z + hole_offset.y
		var tub_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.48, tub_cz))
		builder.add_smart_cylinder(tub_t, 0.21, 0.44, texture_key, "steel_drum", 0.25, 0.85, false)

		var agitator_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.42, tub_cz))
		builder.add_smart_cylinder(agitator_t, 0.045, 0.36, texture_key, "white_body", 0.35, 0.05, false)

		# 5. Tapa Superior de la Lavadora (con recuadro negro y bisel)
		var lid_closed_y := h + lid_thickness * 0.5 - 0.002
		var lid_closed_z := tub_cz
		if not is_open:
			# Tapa cerrada plana en +Y
			var lid_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, lid_closed_y, lid_closed_z))
			builder.add_top_panel_box(lid_t, Vector3(lid_w, lid_thickness, lid_d), texture_key, "lid", "white_body")
		else:
			# Tapa abierta abatida hacia arriba en bisagra trasera a -78 grados
			var hinge_z := tub_cz - lid_d * 0.5
			var rot_lid := Basis(Vector3.RIGHT, deg_to_rad(-78.0))
			var lid_pivot := base_t * Transform3D(rot_lid, Vector3(0.0, h, hinge_z))
			var lid_open_t := lid_pivot * Transform3D(Basis.IDENTITY, Vector3(0.0, lid_thickness * 0.5, lid_d * 0.5))
			builder.add_top_panel_box(lid_open_t, Vector3(lid_w, lid_thickness, lid_d), texture_key, "lid", "white_body")


class DryerRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "dryer")
		var is_open: bool = params.get("is_open", false)
		var w := 0.68
		var d := 0.68
		var h := 0.88
		var console_h := 0.16
		var console_d := 0.12
		var top_d := 0.065
		var wedge_d := console_d - top_d # 0.055m
		var wall_t := 0.025

		var hw := w * 0.5
		var hd := d * 0.5

		# 1. Carcasa principal de esmalte blanco (Base, Trasera, Laterales)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, wall_t * 0.5, 0.0)), Vector3(w, wall_t, d), texture_key, "white_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -hd + wall_t * 0.5)), Vector3(w, h, wall_t), texture_key, "white_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + wall_t * 0.5, h * 0.5, 0.0)), Vector3(wall_t, h, d), texture_key, "white_body")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - wall_t * 0.5, h * 0.5, 0.0)), Vector3(wall_t, h, d), texture_key, "white_body")

		# 2. Copete trasero en cuña (Prisma triangular + caja posterior + panel centrado)
		var back_box_z := -hd + top_d * 0.5
		var wedge_z := -hd + top_d + wedge_d * 0.5
		var console_center_y := h + console_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, console_center_y, back_box_z)), Vector3(w, console_h, top_d), texture_key, "white_body")
		builder.add_smart_wedge(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, console_center_y, wedge_z)), Vector3(w, console_h, wedge_d), texture_key, "white_body")

		# Panel frontal con perillas y display LED azul centrado sobre la rampa
		var ctrl_w := 0.46
		var ctrl_slant_len := sqrt(console_h * console_h + wedge_d * wedge_d)
		var rot_x := -atan2(wedge_d, console_h)
		var rot_slope := Basis(Vector3.RIGHT, rot_x)
		var slope_pos := Vector3(0.0, console_center_y, wedge_z)
		var quad_t := base_t * Transform3D(rot_slope, slope_pos + rot_slope * Vector3(0.0, 0.0, 0.002))
		builder.add_smart_quad(quad_t, Vector2(ctrl_w, ctrl_slant_len * 0.94), texture_key, "control_panel")

		# 3. Encimera superior lisa completamente cerrada
		var deck_z_start := -hd + console_d
		var deck_d := d - console_d
		var deck_center_z := deck_z_start + deck_d * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - wall_t * 0.5, deck_center_z)), Vector3(w, wall_t, deck_d), texture_key, "white_body")

		# 4. Frontal (+Z) con costura de ancho completo y marco perimetral para el hueco de la puerta
		var door_w := 0.48
		var door_h := 0.48
		var door_thickness := 0.022
		var door_y := 0.44
		var front_z := hd - wall_t * 0.5

		# Costura negra superior fina (Y=74) de ancho completo
		var seam_h := 0.012
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - seam_h * 0.5, front_z + 0.001)), Vector3(w, seam_h, wall_t), texture_key, "front_seam", "white_body")

		# Panel blanco entre costura y puerta
		var top_band_h := (h - seam_h) - (door_y + door_h * 0.5)
		if top_band_h > 0.005:
			var white_band_y := (door_y + door_h * 0.5) + top_band_h * 0.5
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, white_band_y, front_z)), Vector3(w, top_band_h, wall_t), texture_key, "white_body")

		# Franja inferior bajo la puerta
		var bot_band_h := (door_y - door_h * 0.5) - wall_t
		if bot_band_h > 0.005:
			var bot_band_y := wall_t + bot_band_h * 0.5
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, bot_band_y, front_z)), Vector3(w, bot_band_h, wall_t), texture_key, "white_body")

		# Flancos laterales a izquierda y derecha del hueco
		var side_band_w := (w - door_w) * 0.5
		if side_band_w > 0.005:
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + side_band_w * 0.5, door_y, front_z)), Vector3(side_band_w, door_h, wall_t), texture_key, "white_body")
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - side_band_w * 0.5, door_y, front_z)), Vector3(side_band_w, door_h, wall_t), texture_key, "white_body")

		# 5. Tambor Cilíndrico Horizontal de Secado en el interior
		var drum_r := minf(door_w, door_h) * 0.44
		var drum_len := d - wall_t * 2.0 - 0.04
		var drum_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, door_y, 0.0))
		builder.add_smart_cylinder(drum_t, drum_r, drum_len, texture_key, "steel_drum", 0.25, 0.85, false)

		# 6. Puerta Frontal de Secadora (con marco biselado negro y manija)
		if not is_open:
			# Cerrada enrasada con el frontal
			var door_t_pos := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, door_y, hd + door_thickness * 0.5 - wall_t * 0.5))
			builder.add_panel_box(door_t_pos, Vector3(door_w, door_h, door_thickness), texture_key, "door", "white_body")
		else:
			# Abierta hacia la izquierda abatida en bisagra (-X) a -95 grados
			var hinge_x := -door_w * 0.5
			var rot_door := Basis(Vector3.UP, deg_to_rad(-95.0))
			var door_pivot := base_t * Transform3D(rot_door, Vector3(hinge_x, door_y, hd))
			var door_open_t := door_pivot * Transform3D(Basis.IDENTITY, Vector3(door_w * 0.5, 0.0, door_thickness * 0.5))
			builder.add_panel_box(door_open_t, Vector3(door_w, door_h, door_thickness), texture_key, "door", "white_body")


# =========================================================================
# 5. TOSTADORA DE PAN (TOASTER)
# =========================================================================
class ToasterRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "toaster")
		var w := 0.28
		var d := 0.17
		var h := 0.19
		var f_h := 0.015
		var body_h := h - f_h

		# 1. Cuerpo principal cromado con ranuras superiores en +Y y laterales brillantes
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, f_h + body_h * 0.5, 0.0))
		builder.add_top_panel_box(body_t, Vector3(w, body_h, d), texture_key, "slots", "steel_sides")

		# 2. Canal de palanca eyectora en el lateral derecho (+X)
		var lever_sz := Vector3(0.015, body_h * 0.60, 0.035)
		var lever_pos := Vector3(w * 0.5 + 0.005, f_h + body_h * 0.5, 0.0)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, lever_pos), lever_sz, texture_key, "lever_track")

		# 3. 4 Patitas de goma negra antideslizante
		var foot_sz := Vector3(0.024, f_h, 0.024)
		var foot_dx := w * 0.5 - 0.025
		var foot_dz := d * 0.5 - 0.025
		for px in [-foot_dx, foot_dx]:
			for pz in [-foot_dz, foot_dz]:
				builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(px, f_h * 0.5, pz)), foot_sz, texture_key, "rubber_feet", 0.90, 0.02, false)

		# 4. Dos rebanadas de pan tostado dorado asomándose
		var toast_sz := Vector3(w * 0.60, 0.10, 0.020)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.03, -0.030)), toast_sz, texture_key, "toast_bread", 0.85, 0.01, false)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.03,  0.030)), toast_sz, texture_key, "toast_bread", 0.85, 0.01, false)


# =========================================================================
# 6. GABINETES DE COCINA (CABINET: BASE Y AÉREO CON PUERTAS ABATIBLES)
# =========================================================================
class CabinetRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var is_wall: bool = params.get("is_wall", false)
		var is_open: bool = params.get("is_open", false)
		var texture_key: String = params.get("texture_key", "cabinets")

		var w := 0.85
		var d := 0.38 if is_wall else 0.65
		var h := 0.70 if is_wall else 0.90
		var kick_h := 0.0 if is_wall else 0.08
		var counter_t := 0.0 if is_wall else 0.038
		var drawer_h := 0.0 if is_wall else 0.12
		var wall_t := 0.025
		var door_t := 0.025
		var body_d := d - door_t

		var hw := w * 0.5
		var hd := d * 0.5
		var body_center_z := -door_t * 0.5
		var body_h := (h - counter_t) if not is_wall else h

		# 1. Carcasa de Madera Clara (Fondo posterior, laterales, piso y techo)
		# Nota: la altura de paredes laterales y fondo se limita a body_h para que la
		# cubierta de granito se asiente limpiamente encima (+Y) sin Z-fighting ni sangrado de madera lateral.
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, body_h * 0.5, -hd + wall_t * 0.5)), Vector3(w, body_h, wall_t), texture_key, "wood_side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + wall_t * 0.5, body_h * 0.5, body_center_z)), Vector3(wall_t, body_h, body_d), texture_key, "wood_side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - wall_t * 0.5, body_h * 0.5, body_center_z)), Vector3(wall_t, body_h, body_d), texture_key, "wood_side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h + wall_t * 0.5, body_center_z)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "wood_side")
		if is_wall:
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - wall_t * 0.5, body_center_z)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "wood_side")

		# 2. Zócalo inferior retranqueado (Kickplate) si es mueble bajo
		if not is_wall:
			var kick_z := hd - 0.05
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h * 0.5, kick_z)), Vector3(w, kick_h, 0.03), texture_key, "kick", "wood_side")

			# Falsa faja / Cajón superior de madera
			var drawer_y := body_h - drawer_h * 0.5
			var drawer_z := hd - door_t * 0.5
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_y, drawer_z)), Vector3(w, drawer_h, door_t), texture_key, "drawer", "wood_side")

			# Cubierta de Granito superior con voladizo frontal y lateral limpio de 1cm
			var counter_y := body_h + counter_t * 0.5
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, counter_y, 0.015)), Vector3(w + 0.02, counter_t, d + 0.03), texture_key, "granite")

		# 3. Puertas estilo Shaker con marco biselado
		var doors_y_bottom := kick_h
		var doors_y_top := (body_h - drawer_h) if not is_wall else h
		var doors_h := doors_y_top - doors_y_bottom
		var doors_center_y := doors_y_bottom + doors_h * 0.5
		var single_door_w := (w - 0.008) * 0.5
		var door_z := hd - door_t * 0.5

		if not is_open:
			# Puerta izquierda cerrada
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + single_door_w * 0.5 + 0.002, doors_center_y, door_z)), Vector3(single_door_w, doors_h, door_t), texture_key, "door_front", "wood_side")
			# Puerta derecha cerrada
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - single_door_w * 0.5 - 0.002, doors_center_y, door_z)), Vector3(single_door_w, doors_h, door_t), texture_key, "door_front", "wood_side")
		else:
			# Puertas abiertas
			var rot_l := Basis(Vector3.UP, deg_to_rad(100.0))
			var left_pivot := base_t * Transform3D(rot_l, Vector3(-hw, doors_center_y, body_d * 0.5))
			builder.add_panel_box(left_pivot * Transform3D(Basis.IDENTITY, Vector3(single_door_w * 0.5, 0.0, door_t * 0.5)), Vector3(single_door_w, doors_h, door_t), texture_key, "door_front", "wood_side")

			var rot_r := Basis(Vector3.UP, deg_to_rad(-100.0))
			var right_pivot := base_t * Transform3D(rot_r, Vector3(hw, doors_center_y, body_d * 0.5))
			builder.add_panel_box(right_pivot * Transform3D(Basis.IDENTITY, Vector3(-single_door_w * 0.5, 0.0, door_t * 0.5)), Vector3(single_door_w, doors_h, door_t), texture_key, "door_front", "wood_side")

		# Repisa interior divisoria
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, doors_center_y, body_center_z)), Vector3(w - wall_t * 2.0 - 0.01, 0.018, body_d - 0.04), texture_key, "wood_side", 0.65, 0.02, false)


# =========================================================================
# 7. FREGADERO / TARJA DE COCINA (SINK CON TARJA EMBUTIDA Y GRIFO CROMADO)
# =========================================================================
class SinkRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "cabinets")
		var is_open: bool = params.get("is_open", false)

		var w := 0.85
		var d := 0.65
		var h := 0.90
		var kick_h := 0.08
		var counter_t := 0.038
		var wall_t := 0.025
		var door_t := 0.025

		var hw := w * 0.5
		var hd := d * 0.5
		var body_d := d - door_t
		var body_center_z := -door_t * 0.5
		var body_h := h - counter_t

		# 1. Mueble base de madera
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, body_h * 0.5, -hd + wall_t * 0.5)), Vector3(w, body_h, wall_t), texture_key, "wood_side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + wall_t * 0.5, body_h * 0.5, body_center_z)), Vector3(wall_t, body_h, body_d), texture_key, "wood_side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - wall_t * 0.5, body_h * 0.5, body_center_z)), Vector3(wall_t, body_h, body_d), texture_key, "wood_side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h + wall_t * 0.5, body_center_z)), Vector3(w - wall_t * 2.0, wall_t, body_d), texture_key, "wood_side")

		# Zócalo inferior
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h * 0.5, hd - 0.05)), Vector3(w, kick_h, 0.03), texture_key, "kick", "wood_side")

		# Puertas inferiores de fregadero
		var doors_h := body_h - kick_h
		var doors_y := kick_h + doors_h * 0.5
		var single_w := (w - 0.008) * 0.5
		var door_z := hd - door_t * 0.5

		if not is_open:
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + single_w * 0.5 + 0.002, doors_y, door_z)), Vector3(single_w, doors_h, door_t), texture_key, "door_front", "wood_side")
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - single_w * 0.5 - 0.002, doors_y, door_z)), Vector3(single_w, doors_h, door_t), texture_key, "door_front", "wood_side")
		else:
			var rot_l := Basis(Vector3.UP, deg_to_rad(100.0))
			var left_pivot := base_t * Transform3D(rot_l, Vector3(-hw, doors_y, body_d * 0.5))
			builder.add_panel_box(left_pivot * Transform3D(Basis.IDENTITY, Vector3(single_w * 0.5, 0.0, door_t * 0.5)), Vector3(single_w, doors_h, door_t), texture_key, "door_front", "wood_side")

			var rot_r := Basis(Vector3.UP, deg_to_rad(-100.0))
			var right_pivot := base_t * Transform3D(rot_r, Vector3(hw, doors_y, body_d * 0.5))
			builder.add_panel_box(right_pivot * Transform3D(Basis.IDENTITY, Vector3(-single_w * 0.5, 0.0, door_t * 0.5)), Vector3(single_w, doors_h, door_t), texture_key, "door_front", "wood_side")

		# 2. Encimera de Granito continua con recorte central para la tarja
		# Utiliza add_cutout_surface para garantizar partición UV continua:
		# - Misma escala y dirección en toda la encimera.
		# - Cero estiramiento ni deformación en alas o fajas.
		# - Continuidad matemática 100% en las juntas perimetrales del hueco.
		var counter_y := body_h + counter_t * 0.5
		var counter_total_w := w + 0.02
		var counter_total_d := d + 0.03
		var counter_center_z := 0.015

		var sink_w := 0.48
		var sink_d := 0.40
		var sink_center_z := counter_center_z + 0.02
		var back_deck_d := (sink_center_z - sink_d * 0.5) - (counter_center_z - counter_total_d * 0.5)
		var back_deck_z := (counter_center_z - counter_total_d * 0.5) + back_deck_d * 0.5

		var counter_t_pos := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, counter_y, counter_center_z))
		var counter_sz := Vector3(counter_total_w, counter_t, counter_total_d)
		var hole_sz := Vector2(sink_w, sink_d)
		var hole_off := Vector2(0.0, 0.02)
		builder.add_cutout_surface(counter_t_pos, counter_sz, hole_sz, hole_off, texture_key, "granite")

		# 3. Tarja Embutida de Acero Inoxidable (Rim perimetral y tina rehundida)
		var rim_thick := 0.008
		var rim_y := h + rim_thick * 0.5
		var lip_w := 0.025
		# 4 cejas perimetrales que enmarcan la tarja dejando el hueco central completamente abierto
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-sink_w * 0.5 + lip_w * 0.5, rim_y, sink_center_z)), Vector3(lip_w, rim_thick, sink_d), texture_key, "sink_rim", 0.25, 0.80)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( sink_w * 0.5 - lip_w * 0.5, rim_y, sink_center_z)), Vector3(lip_w, rim_thick, sink_d), texture_key, "sink_rim", 0.25, 0.80)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, rim_y, sink_center_z - sink_d * 0.5 + lip_w * 0.5)), Vector3(sink_w - lip_w * 2.0, rim_thick, lip_w), texture_key, "sink_rim", 0.25, 0.80)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, rim_y, sink_center_z + sink_d * 0.5 - lip_w * 0.5)), Vector3(sink_w - lip_w * 2.0, rim_thick, lip_w), texture_key, "sink_rim", 0.25, 0.80)

		# Fondo hundido de la tina (a 14cm bajo el mesón) en acero inoxidable satinado uniforme
		var basin_drop := 0.14
		var basin_floor_y := h - basin_drop
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, basin_floor_y, sink_center_z)), Vector3(sink_w - 0.04, 0.012, sink_d - 0.04), texture_key, "sink_rim", 0.28, 0.75)

		# Paredes internas de la tina
		var wall_in_h := basin_drop - 0.012
		var wall_in_y := basin_floor_y + wall_in_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-sink_w * 0.5 + 0.02, wall_in_y, sink_center_z)), Vector3(0.01, wall_in_h, sink_d - 0.04), texture_key, "sink_rim", 0.28, 0.75)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( sink_w * 0.5 - 0.02, wall_in_y, sink_center_z)), Vector3(0.01, wall_in_h, sink_d - 0.04), texture_key, "sink_rim", 0.28, 0.75)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, wall_in_y, sink_center_z - sink_d * 0.5 + 0.02)), Vector3(sink_w - 0.04, wall_in_h, 0.01), texture_key, "sink_rim", 0.28, 0.75)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, wall_in_y, sink_center_z + sink_d * 0.5 - 0.02)), Vector3(sink_w - 0.04, wall_in_h, 0.01), texture_key, "sink_rim", 0.28, 0.75)

		# Coladera / Desagüe central plateado
		var drain_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, basin_floor_y + 0.007, sink_center_z))
		builder.add_smart_cylinder(drain_t, 0.035, 0.006, texture_key, "sink_rim", 0.15, 0.95, false)

		# 4. Grifería Monomando Cuello de Cisne en Cromo Pulido
		var faucet_z := back_deck_z
		var spout_base_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.015, faucet_z))
		builder.add_smart_cylinder(spout_base_t, 0.022, 0.030, texture_key, "sink_rim", 0.10, 0.95, false)

		# Columna vertical del caño
		var pipe_v_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.12, faucet_z))
		builder.add_smart_cylinder(pipe_v_t, 0.011, 0.18, texture_key, "sink_rim", 0.10, 0.95, false)

		# Arco horizontal hacia el frente
		var pipe_h_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, h + 0.21, faucet_z + 0.06))
		builder.add_smart_cylinder(pipe_h_t, 0.011, 0.12, texture_key, "sink_rim", 0.10, 0.95, false)

		# Boquilla aireadora apuntando hacia la tina
		var nozzle_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.18, faucet_z + 0.12))
		builder.add_smart_cylinder(nozzle_t, 0.013, 0.040, texture_key, "sink_rim", 0.10, 0.95, false)

		# Manerales mezcladores a izquierda y derecha
		var handle_l_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-0.08, h + 0.025, faucet_z))
		builder.add_smart_cylinder(handle_l_t, 0.016, 0.040, texture_key, "sink_rim", 0.10, 0.95, false)
		var handle_r_t := base_t * Transform3D(Basis.IDENTITY, Vector3( 0.08, h + 0.025, faucet_z))
		builder.add_smart_cylinder(handle_r_t, 0.016, 0.040, texture_key, "sink_rim", 0.10, 0.95, false)
