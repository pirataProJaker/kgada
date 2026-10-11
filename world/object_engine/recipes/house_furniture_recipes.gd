class_name HouseFurnitureRecipes
extends RefCounted

## Recetas Oficiales de Muebles de Casa para el Motor de Objetos (Play Sector X)
## Arquitectura: +0 Draw Calls (Vinculado 100% al Atlas Inteligente ObjectAtlas)
## Modelos geométricos con proporciones y texturas exactas a los originales de referencia.

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")


# =========================================================================
# 1. MESA DE COMEDOR (DINING TABLE)
# =========================================================================
class TableRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var finish: String = params.get("finish", "roble_claro")
		var l: float = params.get("length", 1.40)
		var w: float = params.get("width", 0.85)
		var h: float = params.get("height", 0.75)
		var t_thick: float = 0.04
		var leg_t: float = 0.07

		# 1. Cubierta de madera superior
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - t_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(l, t_thick, w), finish, "surface", 0.55, 0.02, true)

		# 2. Las 4 patas de madera
		var lx := (l * 0.5) - 0.045 - (leg_t * 0.5)
		var lz := (w * 0.5) - 0.045 - (leg_t * 0.5)
		var leg_h := h - t_thick
		var leg_y := leg_h * 0.5

		var leg_offsets := [
			Vector3(-lx, leg_y, -lz),
			Vector3( lx, leg_y, -lz),
			Vector3(-lx, leg_y,  lz),
			Vector3( lx, leg_y,  lz)
		]
		for off in leg_offsets:
			var leg_t_node := base_t * Transform3D(Basis.IDENTITY, off)
			builder.add_smart_box(leg_t_node, Vector3(leg_t, leg_h, leg_t), finish, "surface", 0.60, 0.02, true)

		# 3. Faldón estructural perimetral bajo la cubierta
		var apron_h := 0.06
		var apron_y := h - t_thick - apron_h * 0.5
		var apron_l_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, -lz))
		builder.add_smart_box(apron_l_t, Vector3(lx * 2.0 - leg_t, apron_h, 0.025), finish, "surface", 0.60, 0.02, false)
		var apron_r_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, lz))
		builder.add_smart_box(apron_r_t, Vector3(lx * 2.0 - leg_t, apron_h, 0.025), finish, "surface", 0.60, 0.02, false)


# =========================================================================
# 2. SILLA DE MADERA (CHAIR)
# =========================================================================
class ChairRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var finish: String = params.get("finish", "roble_claro")
		var seat_h := 0.44
		var seat_w := 0.44
		var seat_d := 0.44
		var seat_thick := 0.035

		# 1. Asiento de madera
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.0))
		builder.add_smart_box(seat_t, Vector3(seat_w, seat_thick, seat_d), finish, "surface", 0.55, 0.02, true)

		# 2. 4 Patas
		var px := seat_w * 0.5 - 0.03
		var pz := seat_d * 0.5 - 0.03
		var leg_h := seat_h - seat_thick * 0.5
		var leg_y := leg_h * 0.5
		var leg_offsets := [
			Vector3(-px, leg_y, -pz), Vector3(px, leg_y, -pz),
			Vector3(-px, leg_y,  pz), Vector3(px, leg_y,  pz)
		]
		for off in leg_offsets:
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, off), Vector3(0.04, leg_h, 0.04), finish, "surface", 0.60, 0.02, false)

		# 3. Respaldo (postes y travesaños)
		var back_h := 0.46
		var back_y := seat_h + back_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-px, back_y, -pz)), Vector3(0.04, back_h, 0.04), finish, "surface", 0.60, 0.02, false)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( px, back_y, -pz)), Vector3(0.04, back_h, 0.04), finish, "surface", 0.60, 0.02, false)

		# Travesaño superior
		var top_rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + back_h - 0.04, -pz))
		builder.add_smart_box(top_rail_t, Vector3(seat_w - 0.04, 0.08, 0.025), finish, "surface", 0.60, 0.02, false)


# =========================================================================
# 3. SILLÓN OREJERO DE CUERO (ARMCHAIR)
# =========================================================================
class ArmchairRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w := 0.95
		var d := 0.88
		var h := 0.85
		var leg_h := 0.20
		var apron_h := 0.08
		var arm_w := 0.12
		var arm_h := 0.56
		var back_t := 0.12

		var hw := w * 0.5
		var hd := d * 0.5

		# 1. 4 Patas de madera oscura torneada
		var foot_sz := Vector3(0.06, leg_h, 0.06)
		var lx := hw - 0.08
		var lz := hd - 0.08
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-lx, leg_h * 0.5, -lz)), foot_sz, "sofa_leather", "wood_leg", 0.70, 0.02, false)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( lx, leg_h * 0.5, -lz)), foot_sz, "sofa_leather", "wood_leg", 0.70, 0.02, false)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-lx, leg_h * 0.5,  lz)), foot_sz, "sofa_leather", "wood_leg", 0.70, 0.02, false)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( lx, leg_h * 0.5,  lz)), foot_sz, "sofa_leather", "wood_leg", 0.70, 0.02, false)

		# 2. Faldón perimetral de cuero liso bajo el asiento
		var apron_y := leg_h + apron_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, 0.0)), Vector3(w, apron_h, d), "sofa_leather", "smooth")

		# 3. Cojín de Asiento mullido (con textura cushion del atlas en cara superior)
		var c_w := w - (arm_w * 2.0)
		var c_d := d - back_t - 0.04
		var c_h := 0.14
		var c_y := leg_h + apron_h + c_h * 0.5
		var c_z := 0.02
		builder.add_top_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, c_y, c_z)), Vector3(c_w, c_h, c_d), "sofa_leather", "cushion", "smooth")

		# 4. Respaldo alto capitoné con botones romboidales en cuero
		var back_w := w - (arm_w * 2.0) + 0.02
		var back_h := h - (leg_h + apron_h)
		var back_y := (leg_h + apron_h) + back_h * 0.5
		var back_z := -hd + back_t * 0.5
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z)), Vector3(back_w, back_h, back_t), "sofa_leather", "capitone", "smooth")

		# 5. Descansabrazos redondos izquierdo y derecho
		var arm_len := d - back_t
		var arm_cz := (-hd + back_t) + arm_len * 0.5
		var arm_total_h := arm_h - (leg_h + apron_h)
		var arm_cy := (leg_h + apron_h) + arm_total_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + arm_w * 0.5, arm_cy, arm_cz)), Vector3(arm_w, arm_total_h, arm_len), "sofa_leather", "armrest")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - arm_w * 0.5, arm_cy, arm_cz)), Vector3(arm_w, arm_total_h, arm_len), "sofa_leather", "armrest")

		# 6. Orejeras laterales envolventes
		var wing_h := h - arm_h + 0.08
		var wing_y := arm_h + wing_h * 0.5 - 0.04
		var wing_z := -hd + back_t + 0.10
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-hw + arm_w * 0.5, wing_y, wing_z)), Vector3(arm_w * 0.8, wing_h, 0.22), "sofa_leather", "side")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( hw - arm_w * 0.5, wing_y, wing_z)), Vector3(arm_w * 0.8, wing_h, 0.22), "sofa_leather", "side")


# =========================================================================
# 4. MESA DE CENTRO DE SALA (COFFEE TABLE CON CAJÓN)
# =========================================================================
class CoffeeTableRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var is_open: bool = params.get("is_open", false)
		var w := 0.95
		var d := 0.55
		var h := 0.45
		var top_t := 0.035
		var leg_sz := 0.055
		var leg_h := h - top_t
		var apron_h := 0.12
		var drawer_w := w * 0.52
		var drawer_d := d * 0.75
		var drawer_h := apron_h * 0.88
		var drawer_slide := 0.22 if is_open else 0.0

		# 1. Tablero superior con duelas de madera (cara +Y del atlas coffee_table)
		var top_pos := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_t * 0.5, 0.0))
		builder.add_top_panel_box(top_pos, Vector3(w, top_t, d), "coffee_table", "tabletop", "wood_frame")

		# 2. 4 Patas de madera
		var leg_dx := w * 0.5 - leg_sz * 0.5 - 0.02
		var leg_dz := d * 0.5 - leg_sz * 0.5 - 0.02
		var leg_y := leg_h * 0.5
		for px in [-leg_dx, leg_dx]:
			for pz in [-leg_dz, leg_dz]:
				builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(px, leg_y, pz)), Vector3(leg_sz, leg_h, leg_sz), "coffee_table", "legs")

		# 3. Faldón perimetral del bastidor
		var apron_y := leg_h - apron_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, apron_y, -d * 0.5 + 0.02)), Vector3(w - leg_sz * 2.0, apron_h, 0.025), "coffee_table", "wood_frame")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.02, apron_y, 0.0)), Vector3(0.025, apron_h, d - leg_sz * 2.0), "coffee_table", "wood_frame")
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - 0.02, apron_y, 0.0)), Vector3(0.025, apron_h, d - leg_sz * 2.0), "coffee_table", "wood_frame")

		# 4. Cajón deslizante con frente enmarcado del atlas
		var drawer_y := leg_h - apron_h + (apron_h - drawer_h) * 0.5 + drawer_h * 0.5
		var drawer_z := (d * 0.5 - 0.015 - drawer_d * 0.5) + drawer_slide
		builder.add_panel_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_y, drawer_z)), Vector3(drawer_w, drawer_h, drawer_d), "coffee_table", "drawer_front", "wood_frame")


# =========================================================================
# 5. CAMA INDIVIDUAL CON ROPA DE CAMA DINÁMICA (BED SINGLE OAK)
# =========================================================================
class BedRecipe extends ObjectRecipeBase:
	enum BedState {
		MADE = 0,          ## Tendida con cobija drapeada, sábana y almohada
		UNMADE = 1,        ## Destendida con cobija arrugada hacia los pies y almohada ladeada
		STRIPPED = 2,      ## Sin cobija (solo sábana bajera y almohada)
		BARE_MATTRESS = 3  ## Sin sábana ni cobija (colchón vintage rayado desnudo)
	}

	## Reglas procedurales de generación idénticas al planificador de casas del juego
	static func generate_random_params(seed_val: int) -> Dictionary:
		var seed_u: int = absi(seed_val)
		var sheet_id: int = seed_u % 16
		var blanket_id: int = (seed_u >> 4) % 24
		var state_roll: int = (seed_u >> 8) % 100
		var b_state: int = BedState.MADE
		if state_roll >= 94:
			b_state = BedState.BARE_MATTRESS
		elif state_roll >= 85:
			b_state = BedState.STRIPPED
		elif state_roll >= 60:
			b_state = BedState.UNMADE

		var has_pillow: bool = (b_state != BedState.BARE_MATTRESS)
		if has_pillow and ((seed_u >> 11) % 20 == 0):
			has_pillow = false

		var dirt: float = float((seed_u >> 13) % 28) * 0.01
		var finishes := ["roble_claro", "nogal_oscuro", "caoba_rojiza", "pino_natural"]
		var finish: String = finishes[(seed_u >> 16) % finishes.size()]

		return {
			"bed_state": b_state,
			"sheet_id": sheet_id,
			"sheet_pattern_id": sheet_id,
			"blanket_id": blanket_id,
			"blanket_pattern_id": blanket_id,
			"has_pillow": has_pillow,
			"dirt_pct": dirt,
			"finish": finish
		}

	static func get_sheet_names() -> Array[String]:
		return FurnitureTextureManagerScript.SHEET_NAMES

	static func get_blanket_names() -> Array[String]:
		return FurnitureTextureManagerScript.BLANKET_NAMES

	static func get_rest_quality(params: Dictionary) -> Dictionary:
		var state: int = params.get("bed_state", BedState.MADE)
		var dirt: float = params.get("dirt_pct", 0.0)
		var base_comfort := 1.0
		match state:
			BedState.MADE: base_comfort = 1.0
			BedState.UNMADE: base_comfort = 0.85
			BedState.STRIPPED: base_comfort = 0.60
			BedState.BARE_MATTRESS: base_comfort = 0.35
		base_comfort -= dirt * 0.30
		return {
			"comfort": clampf(base_comfort, 0.1, 1.0),
			"stamina_recovery_multiplier": 1.0 + base_comfort * 0.5,
			"moral_bonus": 10 if state == BedState.MADE and dirt < 0.1 else (-5 if state == BedState.BARE_MATTRESS else 0)
		}

	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var finish: String = params.get("finish", "roble_claro")

		# Compatibilidad de estado (admite int o bool is_unmade)
		var state: int = BedState.MADE
		if params.has("bed_state"):
			state = params["bed_state"]
		elif params.has("is_unmade") and params["is_unmade"]:
			state = BedState.UNMADE

		var sheet_id: int = params.get("sheet_id", params.get("sheet_pattern_id", 0))
		var blanket_id: int = params.get("blanket_id", params.get("blanket_pattern_id", 12)) # Default: Cobertor Lobo San Marcos
		var has_pillow: bool = params.get("has_pillow", state != BedState.BARE_MATTRESS)

		var w := 1.05
		var l := 2.14
		var h := 1.095

		# ---------------------------------------------------------------------
		# 1. ESTRUCTURA DE MADERA: PATAS Y ARMAZÓN CON HUECO INFERIOR REAL
		# ---------------------------------------------------------------------
		var post_w := 0.055
		var post_d := 0.06
		var leg_x := w * 0.5 - post_w * 0.5
		var head_z := -l * 0.5 + post_d * 0.5
		var foot_z :=  l * 0.5 - post_d * 0.5

		# 1.1 Patas traseras del Cabecero (elevadas hasta 1.05m tocando el suelo en Y=0)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-leg_x, 1.05 * 0.5, head_z)), Vector3(post_w, 1.05, post_d), finish, "surface", 0.60, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( leg_x, 1.05 * 0.5, head_z)), Vector3(post_w, 1.05, post_d), finish, "surface", 0.60, 0.02, true)

		# 1.2 Patas delanteras del Piecero (elevadas hasta 0.60m)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-leg_x, 0.60 * 0.5, foot_z)), Vector3(post_w, 0.60, post_d), finish, "surface", 0.60, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( leg_x, 0.60 * 0.5, foot_z)), Vector3(post_w, 0.60, post_d), finish, "surface", 0.60, 0.02, true)

		# 1.3 Cabecero: Panel central de madera con corona superior
		var head_panel_w := w - post_w * 2.0
		var head_panel_h := 0.62
		var head_panel_y := 0.42 + head_panel_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, head_panel_y, head_z)), Vector3(head_panel_w, head_panel_h, 0.035), finish, "surface", 0.55, 0.02, true)
		# Corona superior tallada con voladizo perimetral
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.07, head_z)), Vector3(w + 0.03, 0.05, 0.08), finish, "surface", 0.55, 0.02, true)

		# 1.4 Piecero: Panel central con travesaño superior
		var foot_panel_w := w - post_w * 2.0
		var foot_panel_h := 0.36
		var foot_panel_y := 0.22 + foot_panel_h * 0.5
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, foot_panel_y, foot_z)), Vector3(foot_panel_w, foot_panel_h, 0.035), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.60, foot_z)), Vector3(w + 0.02, 0.04, 0.07), finish, "surface", 0.55, 0.02, true)

		# 1.5 Largueros laterales (elevados de 22cm a 42cm, dejando hueco libre real bajo la cama)
		var rail_h := 0.20
		var rail_y := 0.22 + rail_h * 0.5
		var rail_l := l - post_d * 2.0
		var rail_t := 0.038
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-leg_x, rail_y, 0.0)), Vector3(rail_t, rail_h, rail_l), finish, "surface", 0.60, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( leg_x, rail_y, 0.0)), Vector3(rail_t, rail_h, rail_l), finish, "surface", 0.60, 0.02, true)

		# 1.6 Somier / Tablero de soporte inferior del colchón
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.35, 0.0)), Vector3(w - post_w * 2.0, 0.02, rail_l), finish, "surface", 0.65, 0.02, false)

		# ---------------------------------------------------------------------
		# 2. COLCHÓN (ENCAJADO DENTRO DE LOS LARGUEROS)
		# ---------------------------------------------------------------------
		var mat_w := w - post_w * 2.0 - 0.01 # 0.93m
		var mat_l := l - post_d * 2.0 - 0.04 # 1.96m
		var mat_h := 0.205                   # Grosor de 20.5cm
		var mat_y := 0.36 + mat_h * 0.5      # Asentado sobre el somier (tope en Y=0.565m)
		var mat_center_z := 0.0

		var sheet_uv: Rect2 = ObjectAtlasScript.get_sheet_region(sheet_id)

		if state == BedState.BARE_MATTRESS:
			# Colchón desnudo con tela vintage rayada (Fila 5, Columna 0)
			var bare_uv: Rect2 = ObjectAtlasScript.get_bare_mattress_region()
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mat_y, mat_center_z)), Vector3(mat_w, mat_h, mat_l), "bed_linens_atlas", bare_uv, 0.80, 0.01, true)
		else:
			# Colchón con sábana bajera seleccionada del catálogo (16 patrones)
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mat_y, mat_center_z)), Vector3(mat_w, mat_h, mat_l), "bed_linens_atlas", sheet_uv, 0.70, 0.01, true)

		# ---------------------------------------------------------------------
		# 3. COBIJA / EDREDÓN (CON CAÍDAS LATERALES Y ESTADOS DEL JUEGO)
		# ---------------------------------------------------------------------
		var blanket_uv: Rect2 = ObjectAtlasScript.get_blanket_region(blanket_id)
		var pillow_uv: Rect2 = ObjectAtlasScript.get_pillow_region()

		# Sub-regiones especializadas de la cobija para el drapeado perimetral
		var bx := blanket_uv.position.x
		var by := blanket_uv.position.y
		var bw := blanket_uv.size.x
		var bh := blanket_uv.size.y

		# Centro decorativo de la cobija (Lobo, diseño, o franjas principales)
		var top_blanket_uv := Rect2(bx + bw * 0.04, by, bw * 0.92, bh * 0.92)
		# Cenefas/bordes laterales que caen a los costados
		var left_drape_uv := Rect2(bx, by, bw * 0.08, bh * 0.92)
		var right_drape_uv := Rect2(bx + bw * 0.92, by, bw * 0.08, bh * 0.92)
		var foot_drape_uv := Rect2(bx + bw * 0.04, by + bh * 0.92, bw * 0.92, bh * 0.08)

		if state == BedState.MADE:
			# === ESTADO TENDIDA (MADE) CON CAÍDAS LATERALES QUE CAEN SOBRE LOS LARGUEROS ===
			var quilt_l := mat_l * 0.70 # Cubre el 70% de la cama
			var quilt_z := (l * 0.5 - post_d - 0.02) - quilt_l * 0.5
			var quilt_top_y := mat_y + mat_h * 0.5 + 0.012

			# Superficie superior de la cobija
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, quilt_top_y, quilt_z)), Vector3(mat_w, 0.022, quilt_l), "bed_linens_atlas", top_blanket_uv, 0.75, 0.01, false)

			# Caída lateral izquierda (cuelga sobre el larguero izquierdo)
			var drop_h := 0.145
			var drop_y := quilt_top_y - drop_h * 0.5
			var drop_lx := -mat_w * 0.5 - 0.01
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(drop_lx, drop_y, quilt_z)), Vector3(0.02, drop_h, quilt_l), "bed_linens_atlas", left_drape_uv, 0.75, 0.01, false)

			# Caída lateral derecha (cuelga sobre el larguero derecho)
			var drop_rx := mat_w * 0.5 + 0.01
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(drop_rx, drop_y, quilt_z)), Vector3(0.02, drop_h, quilt_l), "bed_linens_atlas", right_drape_uv, 0.75, 0.01, false)

			# Caída hacia el piecero (+Z)
			var drop_foot_z := quilt_z + quilt_l * 0.5 + 0.01
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, drop_y, drop_foot_z)), Vector3(mat_w, drop_h, 0.02), "bed_linens_atlas", foot_drape_uv, 0.75, 0.01, false)

			# Doblez superior de la sábana vuelto hacia atrás (embozo de la sábana del juego)
			var cuff_z := quilt_z - quilt_l * 0.5 - 0.045
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, quilt_top_y - 0.005, cuff_z)), Vector3(mat_w, 0.018, 0.09), "bed_linens_atlas", sheet_uv, 0.75, 0.01, false)

		elif state == BedState.UNMADE:
			# === ESTADO DESTENDIDA (UNMADE) ARRUgada ASIMÉTRICAMENTE HACIA LOS PIES ===
			var bunch_base_z := l * 0.5 - 0.45
			# Capa base arrugada hacia los pies
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-0.04, mat_y + mat_h * 0.5 + 0.04, bunch_base_z)), Vector3(mat_w - 0.06, 0.075, 0.52), "bed_linens_atlas", blanket_uv, 0.75, 0.01, false)
			# Pliegue superior desacomodado
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.10, mat_y + mat_h * 0.5 + 0.08, bunch_base_z + 0.10)), Vector3(mat_w * 0.55, 0.065, 0.38), "bed_linens_atlas", top_blanket_uv, 0.75, 0.01, false)
			# Doblez caído por el lateral izquierdo colgando del larguero
			builder.add_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-mat_w * 0.5 - 0.012, mat_y + 0.03, bunch_base_z + 0.06)), Vector3(0.025, 0.13, 0.36), "bed_linens_atlas", left_drape_uv, 0.75, 0.01, false)

		# ---------------------------------------------------------------------
		# 4. ALMOHADA (PLUMP PILLOW CON FUNDA DE ALGODÓN Y BISELES SUAVES)
		# ---------------------------------------------------------------------
		if has_pillow and state != BedState.BARE_MATTRESS:
			var pillow_y := mat_y + mat_h * 0.5 + 0.045
			var pillow_z := head_z + 0.34

			if state != BedState.UNMADE:
				# Almohada perfectamente centrada y alineada con biseles suaves de cojín
				var p_pos := Vector3(0.0, pillow_y, pillow_z)
				builder.add_box(base_t * Transform3D(Basis.IDENTITY, p_pos), Vector3(0.50, 0.075, 0.22), "bed_linens_atlas", pillow_uv, 0.85, 0.01, false)
				# Bisel delantero y trasero redondeados
				builder.add_wedge(base_t * Transform3D(Basis.IDENTITY, p_pos + Vector3(0.0, -0.01, 0.13)), Vector3(0.50, 0.055, 0.05), "bed_linens_atlas", pillow_uv, 0.85, 0.01, false)
				builder.add_wedge(base_t * Transform3D(Basis(Vector3.UP, PI), p_pos + Vector3(0.0, -0.01, -0.13)), Vector3(0.50, 0.055, 0.05), "bed_linens_atlas", pillow_uv, 0.85, 0.01, false)
			else:
				# Almohada ladeada con inclinación angular de 14°
				var rot_p := Basis(Vector3.UP, deg_to_rad(14.0))
				var p_center := Vector3(-0.05, pillow_y, pillow_z + 0.03)
				builder.add_box(base_t * Transform3D(rot_p, p_center), Vector3(0.50, 0.075, 0.22), "bed_linens_atlas", pillow_uv, 0.85, 0.01, false)
				builder.add_wedge(base_t * Transform3D(rot_p, p_center + rot_p * Vector3(0.0, -0.01, 0.13)), Vector3(0.50, 0.055, 0.05), "bed_linens_atlas", pillow_uv, 0.85, 0.01, false)
				builder.add_wedge(base_t * Transform3D(rot_p * Basis(Vector3.UP, PI), p_center + rot_p * Vector3(0.0, -0.01, -0.13)), Vector3(0.50, 0.055, 0.05), "bed_linens_atlas", pillow_uv, 0.85, 0.01, false)


# =========================================================================
# 6. MESITA DE NOCHE (NIGHTSTAND CON CAJÓN DESLIZANTE)
# =========================================================================
class NightstandRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var finish: String = params.get("finish", "roble_claro")
		var is_open: bool = params.get("is_open", false)
		var drawer_slide: float = 0.18 if is_open else 0.0

		var w := 0.48
		var d := 0.43
		var h := 0.70

		# 1. Cuerpo principal
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.02, 0.0)), Vector3(w, 0.04, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.02, h * 0.5, 0.0)), Vector3(0.04, h - 0.04, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - 0.02, h * 0.5, 0.0)), Vector3(0.04, h - 0.04, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0)), Vector3(w - 0.08, 0.03, d - 0.04), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + 0.02)), Vector3(w - 0.08, h - 0.04, 0.03), finish, "surface", 0.55, 0.02, false)

		# 2. Cajón con jaladera de aluminio
		var drawer_z := (d * 0.5 - 0.18) + drawer_slide
		var drawer_y := h - 0.14
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_y, drawer_z)), Vector3(w - 0.10, 0.18, 0.34), finish, "surface", 0.55, 0.02, true)
		var pull_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_y, drawer_z + 0.18))
		builder.add_smart_cylinder(pull_t, 0.015, 0.03, "commercial_cooler", "aluminum_frame", 0.30, 0.85, false)


# =========================================================================
# 7. ROPERO ALTO (WARDROBE CON PUERTAS ABATIBLES)
# =========================================================================
class WardrobeRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var finish: String = params.get("finish", "roble_claro")
		var is_open: bool = params.get("is_open", false)

		var w := 1.10
		var d := 0.58
		var h := 1.95
		var t_wall := 0.04

		# 1. Armazón principal
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.03, 0.0)), Vector3(w, 0.06, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, 0.0)), Vector3(w, 0.12, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + t_wall * 0.5, h * 0.5, 0.0)), Vector3(t_wall, h - 0.12, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - t_wall * 0.5, h * 0.5, 0.0)), Vector3(t_wall, h - 0.12, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + 0.02)), Vector3(w - t_wall * 2.0, h - 0.12, 0.04), finish, "surface", 0.55, 0.02, false)

		# 2. Barra de perchero interna cromada
		var bar_t := base_t * Transform3D(Basis(Vector3.FORWARD, 1.570796), Vector3(0.0, h - 0.28, 0.0))
		builder.add_smart_cylinder(bar_t, 0.015, w - t_wall * 2.0, "commercial_cooler", "aluminum_frame", 0.25, 0.85, false)

		# 3. Puertas izquierda y derecha
		var door_w := (w - t_wall * 2.0) * 0.5 - 0.005
		var door_h := h - 0.18
		var door_y := h * 0.5 + 0.01
		var door_thick := 0.03

		if not is_open:
			var left_d_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-door_w * 0.5 - 0.002, door_y, d * 0.5 - door_thick * 0.5))
			builder.add_smart_box(left_d_t, Vector3(door_w, door_h, door_thick), finish, "surface", 0.55, 0.02, true)
			var right_d_t := base_t * Transform3D(Basis.IDENTITY, Vector3( door_w * 0.5 + 0.002, door_y, d * 0.5 - door_thick * 0.5))
			builder.add_smart_box(right_d_t, Vector3(door_w, door_h, door_thick), finish, "surface", 0.55, 0.02, true)
		else:
			var rot_l := Basis(Vector3.UP, deg_to_rad(95.0))
			var left_pivot := base_t * Transform3D(rot_l, Vector3(-w * 0.5 + t_wall, door_y, d * 0.5))
			builder.add_smart_box(left_pivot * Transform3D(Basis.IDENTITY, Vector3(door_w * 0.5, 0.0, 0.0)), Vector3(door_w, door_h, door_thick), finish, "surface", 0.55, 0.02, true)

			var rot_r := Basis(Vector3.UP, deg_to_rad(-95.0))
			var right_pivot := base_t * Transform3D(rot_r, Vector3( w * 0.5 - t_wall, door_y, d * 0.5))
			builder.add_smart_box(right_pivot * Transform3D(Basis.IDENTITY, Vector3(-door_w * 0.5, 0.0, 0.0)), Vector3(door_w, door_h, door_thick), finish, "surface", 0.55, 0.02, true)


# =========================================================================
# 8. LIBRERO ALTO (BOOKCASE)
# =========================================================================
class BookcaseRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var finish: String = params.get("finish", "roble_claro")
		var w := 0.90
		var d := 0.36
		var h := 1.90
		var t_wall := 0.035

		# Armazón (Laterales, techo, base, trasera)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.02, 0.0)), Vector3(w, 0.04, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)), Vector3(w, 0.08, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + t_wall * 0.5, h * 0.5, 0.0)), Vector3(t_wall, h, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - t_wall * 0.5, h * 0.5, 0.0)), Vector3(t_wall, h, d), finish, "surface", 0.55, 0.02, true)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, -d * 0.5 + 0.015)), Vector3(w - t_wall * 2.0, h - 0.08, 0.03), finish, "surface", 0.55, 0.02, false)

		# 4 Repisas intermedias
		var shelf_count := 4
		for s in range(1, shelf_count + 1):
			var sy := float(s) * (h / float(shelf_count + 1))
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, 0.0)), Vector3(w - t_wall * 2.0, 0.03, d - 0.04), finish, "surface", 0.55, 0.02, true)
