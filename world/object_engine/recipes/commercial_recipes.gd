class_name CommercialRecipes
extends RefCounted

## Recetas Oficiales de Mobiliario Comercial para el Motor de Objetos (Play Sector X)
## Arquitectura: +0 Draw Calls (Vinculado 100% al Atlas Inteligente ObjectAtlas)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. ESTANTERÍA / GÓNDOLA MODULAR DE TIENDA OXXO (COMMERCIAL SHELF)
# =========================================================================
class CommercialShelfRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var modules: int = clampi(params.get("modules", 1), 1, 4)
		var texture_key: String = params.get("texture_key", "commercial_shelf")

		var module_w := 1.00
		var total_w := float(modules) * module_w
		var d := 0.55
		var h := 1.80

		# 1. Fondo ranurado panel pegboard
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + 0.02))
		builder.add_smart_box(back_t, Vector3(total_w, h, 0.03), texture_key, "shelf_surface")

		# 2. Zócalo base inferior
		var base_shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.0))
		builder.add_smart_box(base_shelf_t, Vector3(total_w, 0.24, d), texture_key, "shelf_surface")

		# 3. Postes estructurales verticales en cada unión de módulos
		var half_w := total_w * 0.5
		for m in range(modules + 1):
			var px := -half_w + float(m) * module_w
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, h * 0.5, -d * 0.5 + 0.02))
			builder.add_smart_box(post_t, Vector3(0.05, h, 0.05), texture_key, "upright_post")

		# 4. 4 Repisas horizontales intermedias
		var shelf_levels := [0.55, 0.95, 1.35, 1.70]
		for sy in shelf_levels:
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, -0.04))
			builder.add_smart_box(shelf_t, Vector3(total_w - 0.02, 0.04, d - 0.10), texture_key, "shelf_surface")


# =========================================================================
# 2. VITRINA REFRIGERADA COMERCIAL (COMMERCIAL COOLER 1 Y 2 PUERTAS)
# =========================================================================
class CommercialCoolerRecipe extends ObjectRecipeBase:
	static func build(builder: ObjectBuilder, base_t: Transform3D, params: Dictionary = {}) -> void:
		var is_double: bool = params.get("is_double", false)
		var doors_open: bool = params.get("doors_open", false)
		var texture_key: String = params.get("texture_key", "commercial_cooler")
		var is_black: bool = params.get("is_black", false)
		var body_region: String = "black_enamel" if is_black else "white_enamel"

		var w: float = 1.80 if is_double else 1.00
		var d: float = 0.90
		var h: float = 2.05
		var t_wall: float = 0.05
		var canopy_h := 0.26
		var grille_h := 0.28

		# 1. Gabinete comercial esmaltado
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.025, 0.0)), Vector3(w, 0.05, d), texture_key, body_region)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.025, 0.0)), Vector3(w, 0.05, d), texture_key, body_region)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + t_wall * 0.5, h * 0.5, 0.0)), Vector3(t_wall, h, d), texture_key, body_region)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - t_wall * 0.5, h * 0.5, 0.0)), Vector3(t_wall, h, d), texture_key, body_region)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + 0.02)), Vector3(w - t_wall * 2.0, h - 0.10, 0.04), texture_key, body_region, 0.35, 0.05, false)

		# 2. Marquesina Luminosa Superior (Lightbox Canopy)
		var canopy_y := h - canopy_h * 0.5
		var canopy_z := d * 0.5 - 0.03
		if is_double:
			var logo_w := 0.90
			var wing_w := (w - logo_w) * 0.5
			# Sección central con logo
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, canopy_y, canopy_z)), Vector3(logo_w, canopy_h, 0.06), texture_key, "canopy_logo", body_region)
			# Alas retroiluminadas
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + wing_w * 0.5, canopy_y, canopy_z)), Vector3(wing_w, canopy_h, 0.06), texture_key, "canopy_wings", body_region)
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - wing_w * 0.5, canopy_y, canopy_z)), Vector3(wing_w, canopy_h, 0.06), texture_key, "canopy_wings", body_region)
		else:
			builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, canopy_y, canopy_z)), Vector3(w - 0.02, canopy_h, 0.06), texture_key, "canopy_logo", body_region)

		# 3. Rejilla Inferior Louver con Termostato Digital
		var grille_y := grille_h * 0.5
		var grille_z := d * 0.5 - 0.03
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, grille_y, grille_z)), Vector3(w - 0.02, grille_h, 0.06), texture_key, "stripes", body_region)

		# Display digital -2.4°C en la esquina inferior derecha
		var disp_w := 0.18
		var disp_h := 0.09
		var disp_x := w * 0.5 - t_wall - disp_w * 0.5 - 0.04
		var disp_y := grille_h * 0.55
		var disp_z := d * 0.5 + 0.012
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(disp_x, disp_y, disp_z)), Vector3(disp_w, disp_h, 0.02), texture_key, "thermostat", 0.20, 0.05, false)

		# 4. Estantes Interiores de Alambre
		var shelf_count := 4
		var interior_h := h - canopy_h - grille_h
		for s in range(1, shelf_count + 1):
			var sy := grille_h + float(s) * (interior_h / float(shelf_count + 1))
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, -0.05)), Vector3(w - t_wall * 2.0 - 0.02, 0.02, d - 0.16), texture_key, "wire_shelf", 0.30, 0.80, true)

		# 5. Puertas de Cristal con Marco de Aluminio
		var door_count := 2 if is_double else 1
		var single_door_w := (w - t_wall * 2.0) / float(door_count) - 0.005
		var door_h := interior_h - 0.02
		var door_y := grille_h + interior_h * 0.5
		var door_z := d * 0.5 - 0.02

		for i in range(door_count):
			var pivot_x: float = (-w * 0.5 + t_wall) if i == 0 else (w * 0.5 - t_wall)
			var door_sign: float = 1.0 if i == 0 else -1.0

			if not doors_open:
				var closed_x := -w * 0.5 + t_wall + float(i) * single_door_w + single_door_w * 0.5
				var d_t := base_t * Transform3D(Basis.IDENTITY, Vector3(closed_x, door_y, door_z))
				# Marco exterior de aluminio
				builder.add_smart_box(d_t, Vector3(single_door_w, door_h, 0.035), texture_key, "aluminum_frame", 0.30, 0.85, true)
				# Vidrio interior transparente
				builder.add_smart_box(d_t, Vector3(single_door_w - 0.08, door_h - 0.08, 0.010), texture_key, "glass", 0.05, 0.10, false)
			else:
				var rot_open := Basis(Vector3.UP, deg_to_rad(95.0 * door_sign))
				var door_pivot := base_t * Transform3D(rot_open, Vector3(pivot_x, door_y, d * 0.5))
				var offset_t := Transform3D(Basis.IDENTITY, Vector3(single_door_w * 0.5 * door_sign, 0.0, 0.0))
				builder.add_smart_box(door_pivot * offset_t, Vector3(single_door_w, door_h, 0.035), texture_key, "aluminum_frame", 0.30, 0.85, true)
				builder.add_smart_box(door_pivot * offset_t, Vector3(single_door_w - 0.08, door_h - 0.08, 0.010), texture_key, "glass", 0.05, 0.10, false)
