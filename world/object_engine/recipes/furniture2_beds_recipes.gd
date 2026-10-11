class_name Furniture2BedsRecipes
extends RefCounted

## Recetas Oficiales: Camas y Ropa de Cama (Furniture 2.0 - Imagen 3)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Modelos 1:1 fieles al asset pack "Interior Village" de elbolilloduro:
##   1. BedSinglePlaidRecipe         - Cama individual de madera oscura con cobertor escocés a cuadros
##   2. BedDoubleIronArabesqueRecipe - Cama matrimonial de hierro forjado blanco con arabescos
##   3. BedDoubleGreyDuvetRecipe     - Cama matrimonial de madera con cabecero liso y edredón gris
##   4. BedDoubleRusticBandRecipe    - Cama matrimonial de madera dorada con cenefa decorativa
##   5. BedDoubleRusticWrinkledRecipe- Cama matrimonial de madera oscura con sábanas arrugadas

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. CAMA INDIVIDUAL MADERA OSCURA CON COBERTOR ESCOCÉS (BED)
# =========================================================================
class BedSinglePlaidRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.10)
		var l: float = params.get("length", 2.05)
		var h_head: float = params.get("head_height", 0.95)
		var texture_key: String = params.get("texture_key", "bed")

		var post_w := 0.07
		var rail_h := 0.16
		var mattress_y := 0.38
		var foot_h := 0.60

		# 1. Postes esquineros y largueros de madera oscura
		# 2 Postes cabecero (traseros -Z)
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - post_w * 0.5)
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, h_head * 0.5, -l * 0.5 + post_w * 0.5))
			builder.add_smart_box(post_t, Vector3(post_w, h_head, post_w), texture_key, "")

		# 2 Postes piecero (delanteros +Z)
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - post_w * 0.5)
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, foot_h * 0.5, l * 0.5 - post_w * 0.5))
			builder.add_smart_box(post_t, Vector3(post_w, foot_h, post_w), texture_key, "")

		# Panel del Cabecero
		var head_p_h := 0.55
		var head_p_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h_head - head_p_h * 0.5 - 0.05, -l * 0.5 + post_w * 0.5))
		builder.add_smart_box(head_p_t, Vector3(w - post_w * 2.0, head_p_h, 0.035), texture_key, "")

		# Panel del Piecero
		var foot_p_h := 0.35
		var foot_p_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, foot_h - foot_p_h * 0.5 - 0.04, l * 0.5 - post_w * 0.5))
		builder.add_smart_box(foot_p_t, Vector3(w - post_w * 2.0, foot_p_h, 0.035), texture_key, "")

		# Largueros laterales del marco
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - 0.02)
			var rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.28, 0.0))
			builder.add_smart_box(rail_t, Vector3(0.04, rail_h, l - post_w * 2.0), texture_key, "")

		# 2. Colchón con sábana bajera
		var m_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mattress_y, 0.0))
		builder.add_smart_box(m_t, Vector3(w - 0.08, 0.18, l - post_w * 2.0 - 0.04), texture_key, "", 0.75, 0.02)

		# 3. Franja doblada de cobija escocesa a cuadros (tartan)
		var plaid_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mattress_y + 0.10, -0.20))
		builder.add_smart_box(plaid_t, Vector3(w - 0.06, 0.025, 0.40), texture_key, "", 0.70, 0.02)

		# 4. Almohada esponjosa
		var pillow_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0.0, mattress_y + 0.12, -l * 0.5 + 0.35))
		builder.add_smart_box(pillow_t, Vector3(w * 0.65, 0.10, 0.38), texture_key, "", 0.80, 0.01)


# =========================================================================
# 2. CAMA MATRIMONIAL HIERRO FORJADO BLANCO (BED_02)
# =========================================================================
class BedDoubleIronArabesqueRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.65)
		var l: float = params.get("length", 2.10)
		var h_head: float = params.get("head_height", 1.25)
		var texture_key: String = params.get("texture_key", "bed_02")

		var pipe_r := 0.02
		var foot_h := 0.85
		var mattress_y := 0.40

		# 1. Estructura de tubos de hierro blanco
		# 2 Postes principales cabecero
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - pipe_r)
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, h_head * 0.5, -l * 0.5 + pipe_r))
			builder.add_cylinder(post_t, pipe_r, h_head, texture_key, Rect2(0.35, 0.05, 0.08, 0.40), 0.35, 0.40)
			# Pomo esférico en la punta
			var finial_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, h_head + 0.03, -l * 0.5 + pipe_r))
			builder.add_smart_box(finial_t, Vector3(0.06, 0.06, 0.06), texture_key, "", 0.35, 0.40)

		# 2 Postes piecero
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - pipe_r)
			var post_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, foot_h * 0.5, l * 0.5 - pipe_r))
			builder.add_cylinder(post_t, pipe_r, foot_h, texture_key, Rect2(0.35, 0.05, 0.08, 0.40), 0.35, 0.40)
			var finial_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, foot_h + 0.03, l * 0.5 - pipe_r))
			builder.add_smart_box(finial_t, Vector3(0.06, 0.06, 0.06), texture_key, "", 0.35, 0.40)

		# Travesaños y reja de arabescos del cabecero
		var bar_top_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, h_head - 0.05, -l * 0.5 + pipe_r))
		builder.add_cylinder(bar_top_t, 0.015, w - 0.08, texture_key, Rect2(0.35, 0.05, 0.08, 0.40), 0.35, 0.40)
		var arabesque_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h_head - 0.32, -l * 0.5 + pipe_r))
		builder.add_smart_box(arabesque_t, Vector3(w - 0.12, 0.48, 0.02), texture_key, "", 0.35, 0.40, false)

		# Travesaño piecero
		var bar_foot_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, foot_h - 0.05, l * 0.5 - pipe_r))
		builder.add_cylinder(bar_foot_t, 0.015, w - 0.08, texture_key, Rect2(0.35, 0.05, 0.08, 0.40), 0.35, 0.40)
		var foot_mesh_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, foot_h - 0.25, l * 0.5 - pipe_r))
		builder.add_smart_box(foot_mesh_t, Vector3(w - 0.12, 0.38, 0.02), texture_key, "", 0.35, 0.40, false)

		# 2. Colchón con colcha de malla geométrica estampada
		var m_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mattress_y, 0.0))
		builder.add_smart_box(m_t, Vector3(w - 0.08, 0.22, l - 0.12), texture_key, "", 0.75, 0.02)

		# 3. 2 Almohadas blancas
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.25)
			var pillow_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(px, mattress_y + 0.14, -l * 0.5 + 0.38))
			builder.add_smart_box(pillow_t, Vector3(w * 0.40, 0.11, 0.42), texture_key, "", 0.80, 0.01)


# =========================================================================
# 3. CAMA MATRIMONIAL MADERA CLARA CON EDREDÓN GRIS (BED_03)
# =========================================================================
class BedDoubleGreyDuvetRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.70)
		var l: float = params.get("length", 2.10)
		var h_head: float = params.get("head_height", 1.05)
		var texture_key: String = params.get("texture_key", "bed_03")

		var mattress_y := 0.42
		var frame_thick := 0.06

		# 1. Cabecero de madera amplio y continuo
		var head_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h_head * 0.5, -l * 0.5 + frame_thick * 0.5))
		builder.add_smart_box(head_t, Vector3(w, h_head, frame_thick), texture_key, "")

		# Marco perimetral y patas de madera
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - frame_thick * 0.5)
			var rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.22, 0.0))
			builder.add_smart_box(rail_t, Vector3(frame_thick, 0.20, l - frame_thick), texture_key, "")

		var foot_rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.22, l * 0.5 - frame_thick * 0.5))
		builder.add_smart_box(foot_rail_t, Vector3(w - frame_thick * 2.0, 0.20, frame_thick), texture_key, "")

		# 2. Colchón con edredón gris/marrón
		var m_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mattress_y, 0.02))
		builder.add_smart_box(m_t, Vector3(w - frame_thick * 2.0 - 0.02, 0.22, l - frame_thick * 2.0 - 0.02), texture_key, "", 0.75, 0.02)

		# 3. 2 Almohadas oscuras de confort
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.25)
			var pillow_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(px, mattress_y + 0.14, -l * 0.5 + 0.40))
			builder.add_smart_box(pillow_t, Vector3(w * 0.40, 0.12, 0.42), texture_key, "", 0.80, 0.01)


# =========================================================================
# 4. CAMA MATRIMONIAL MADERA DORADA CON CENEFA (BED_01)
# =========================================================================
class BedDoubleRusticBandRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.75)
		var l: float = params.get("length", 2.15)
		var h_head: float = params.get("head_height", 1.10)
		var texture_key: String = params.get("texture_key", "bed_01")

		var mattress_y := 0.44
		var post_sz := 0.10

		# 1. 4 Postes macizos de madera rústica
		for sx: float in [-1.0, 1.0]:
			var px := sx * (w * 0.5 - post_sz * 0.5)
			# Postes cabecero
			var p_head_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, h_head * 0.5, -l * 0.5 + post_sz * 0.5))
			builder.add_smart_box(p_head_t, Vector3(post_sz, h_head, post_sz), texture_key, "")
			# Postes piecero
			var p_foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.50 * 0.5, l * 0.5 - post_sz * 0.5))
			builder.add_smart_box(p_foot_t, Vector3(post_sz, 0.50, post_sz), texture_key, "")

		# Cabecero de paneles verticales de madera
		var head_p_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h_head * 0.5 + 0.10, -l * 0.5 + post_sz * 0.5))
		builder.add_smart_box(head_p_t, Vector3(w - post_sz * 2.0, h_head - 0.25, 0.05), texture_key, "")

		# 2. Colchón con frazada suave
		var m_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mattress_y, 0.0))
		builder.add_smart_box(m_t, Vector3(w - post_sz * 2.0 - 0.02, 0.22, l - post_sz * 2.0 - 0.02), texture_key, "", 0.70, 0.02)

		# Cenefa decorativa estampada doblada sobre la cama
		var band_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mattress_y + 0.12, -0.22))
		builder.add_smart_box(band_t, Vector3(w - post_sz * 2.0, 0.025, 0.35), texture_key, "", 0.75, 0.02)

		# 3. 2 Almohadas
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.25)
			var pillow_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(px, mattress_y + 0.14, -l * 0.5 + 0.42))
			builder.add_smart_box(pillow_t, Vector3(w * 0.40, 0.12, 0.42), texture_key, "", 0.80, 0.01)


# =========================================================================
# 5. CAMA MATRIMONIAL MADERA CON SÁBANAS ARRUGADAS (BED_04)
# =========================================================================
class BedDoubleRusticWrinkledRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.70)
		var l: float = params.get("length", 2.10)
		var h_head: float = params.get("head_height", 1.08)
		var texture_key: String = params.get("texture_key", "bed_04")

		var mattress_y := 0.42
		var frame_thick := 0.08

		# 1. Cabecero y piecero con postes salientes
		var head_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h_head * 0.5, -l * 0.5 + frame_thick * 0.5))
		builder.add_smart_box(head_t, Vector3(w, h_head, frame_thick), texture_key, "")

		var foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.45 * 0.5, l * 0.5 - frame_thick * 0.5))
		builder.add_smart_box(foot_t, Vector3(w, 0.45, frame_thick), texture_key, "")

		# Largueros laterales
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.5 - frame_thick * 0.5)
			var rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.22, 0.0))
			builder.add_smart_box(rail_t, Vector3(frame_thick, 0.20, l - frame_thick * 2.0), texture_key, "")

		# 2. Colchón con sábanas blancas y pliegues arrugados realistas
		var m_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mattress_y, 0.0))
		builder.add_smart_box(m_t, Vector3(w - frame_thick * 2.0 - 0.02, 0.22, l - frame_thick * 2.0 - 0.02), texture_key, "", 0.80, 0.01)

		# 3. 2 Almohadas con pliegues
		for side: float in [-1.0, 1.0]:
			var px := side * (w * 0.25)
			var pillow_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(px, mattress_y + 0.14, -l * 0.5 + 0.40))
			builder.add_smart_box(pillow_t, Vector3(w * 0.40, 0.12, 0.42), texture_key, "", 0.80, 0.01)
