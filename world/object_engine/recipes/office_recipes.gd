class_name OfficeRecipes
extends RefCounted

## Recetas Oficiales del Conjunto de Mobiliario de Oficina (Office Pack)
## Para el Motor de Objetos (Play Sector X)
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Reproducción fiel 1:1 de los 12 modelos de referencia:
## Fila 1 (Escritorios):
##   1. OfficeDeskDoublePedestalRecipe - Escritorio ejecutivo doble pedestal de madera
##   2. OfficeDeskMetalTankerRecipe    - Escritorio metálico tanker vintage (cubierta oscura, pedestales grises)
##   3. OfficeDeskLShapedRecipe        - Escritorio modular en L con patas tubulares azules y cajonera
##   4. OfficeDeskSinglePedestalRecipe - Escritorio sencillo con cajonera derecha y patas abiertas
## Fila 2 (Sillas y Archiveros):
##   5. OfficeChairGreenRecipe         - Silla ergonómica giratoria tapizada en verde con base de 5 radios
##   6. OfficeChairRedRecipe           - Silla giratoria de oficina roja con soporte tubular cromado
##   7. OfficeFileCabinetClosedRecipe  - Archivero vertical metálico de 3 gavetas cerrado
##   8. OfficeFileCabinetOpenRecipe    - Archivero vertical metálico con gavetas abiertas y carpetas colgantes
## Fila 3 (Libreros y Armarios):
##   9. OfficeCabinetTallRecipe        - Armario alto de oficina de 2 puertas con pomos
##  10. OfficeCabinetLowRecipe         - Mueble bajo / aparador de oficina de 2 puertas
##  11. OfficeBookcaseTallRecipe       - Librero alto abierto de 5 niveles
##  12. OfficeBookcaseLowRecipe        - Librero bajo abierto de 2 niveles

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. ESCRITORIO EJECUTIVO DOBLE PEDESTAL (DESK 01)
# =========================================================================
class OfficeDeskDoublePedestalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.55)
		var d: float = params.get("depth", 0.78)
		var h: float = params.get("height", 0.76)
		var texture_key: String = params.get("texture_key", "desk01")

		var top_thick := 0.04
		var foot_h := 0.08
		var ped_w := 0.42
		var ped_d := d - 0.06
		var ped_h := h - top_thick - foot_h
		var half_w := w * 0.5
		var ped_offset_x := half_w - ped_w * 0.5 - 0.02

		# 1. Cubierta superior de madera: rotada 90 grados para que la veta corra a lo largo del escritorio (X)
		var top_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(d, top_thick, w), texture_key, "wood_top")

		# 2. Pedestales Izquierdo y Derecho
		var drawer_regions := ["drawer", "drawer_mid", "drawer_bot"]
		for side: float in [-1.0, 1.0]:
			var px: float = side * ped_offset_x
			var ped_center_y := foot_h + ped_h * 0.5

			# Cuerpo del pedestal (laterales y fondo)
			var ped_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, ped_center_y, 0.0))
			builder.add_smart_box(ped_t, Vector3(ped_w, ped_h, ped_d), texture_key, "wood_body", -1.0, -1.0, false)

			# 3 Gavetas frontales con tiradores metálicos
			var drawer_count := 3
			var drawer_gap := 0.015
			var drawer_h := (ped_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
			for i in range(drawer_count):
				var dy := foot_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
				var drawer_pos := Vector3(px, dy, ped_d * 0.5 + 0.005)
				var drawer_t := base_t * Transform3D(Basis.IDENTITY, drawer_pos)
				var d_reg: String = drawer_regions[i] if i < drawer_regions.size() else "drawer"
				builder.add_panel_box(drawer_t, Vector3(ped_w - 0.03, drawer_h, 0.02), texture_key, d_reg, "wood_body")

				# Tirador horizontal plateado
				var handle_pos := Vector3(px, dy, ped_d * 0.5 + 0.02)
				var handle_t := base_t * Transform3D(Basis.IDENTITY, handle_pos)
				builder.add_smart_box(handle_t, Vector3(0.12, 0.02, 0.015), texture_key, "handle", 0.30, 0.10, false)

			# 2 Patitas cuadradas bajo el pedestal
			var foot_sz := 0.06
			for fz in [-ped_d * 0.5 + foot_sz, ped_d * 0.5 - foot_sz]:
				var foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, foot_h * 0.5, fz))
				builder.add_smart_box(foot_t, Vector3(foot_sz, foot_h, foot_sz), texture_key, "foot")

		# 3. Faldón de modestia trasero central
		var knee_w := (ped_offset_x - ped_w * 0.5) * 2.0
		var modesty_h := ped_h * 0.70
		var modesty_y := h - top_thick - modesty_h * 0.5
		var modesty_z := -ped_d * 0.5 + 0.06
		var modesty_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, modesty_y, modesty_z))
		builder.add_smart_box(modesty_t, Vector3(knee_w + 0.02, modesty_h, 0.025), texture_key, "wood_body", -1.0, -1.0, false)


# =========================================================================
# 2. ESCRITORIO METÁLICO TANKER (DESK 02)
# =========================================================================
class OfficeDeskMetalTankerRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.55)
		var d: float = params.get("depth", 0.78)
		var h: float = params.get("height", 0.76)
		var texture_key: String = params.get("texture_key", "desk02")

		var top_thick := 0.04
		var leg_h := 0.12
		var ped_w := 0.42
		var ped_d := d - 0.06
		var ped_h := h - top_thick - leg_h
		var half_w := w * 0.5
		var ped_offset_x := half_w - ped_w * 0.5 - 0.02

		# 1. Cubierta de linóleo oscuro continua sin costura central (rotada 90 grados para orientación de textura)
		var top_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(d, top_thick, w), texture_key, "top_linoleum", 0.45, 0.05)

		# 2. Pedestales metálicos grises
		for side: float in [-1.0, 1.0]:
			var px: float = side * ped_offset_x
			var ped_center_y := leg_h + ped_h * 0.5

			# Cuerpo de chapa metálica gris
			var ped_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, ped_center_y, 0.0))
			builder.add_smart_box(ped_t, Vector3(ped_w, ped_h, ped_d), texture_key, "metal_grey", 0.35, 0.25, false)

			# 3 Gavetas metálicas con jaladeras curvas tipo tanker
			var drawer_count := 3
			var drawer_gap := 0.015
			var drawer_h := (ped_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
			for i in range(drawer_count):
				var dy := leg_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
				var drawer_pos := Vector3(px, dy, ped_d * 0.5 + 0.005)
				var drawer_t := base_t * Transform3D(Basis.IDENTITY, drawer_pos)
				builder.add_panel_box(drawer_t, Vector3(ped_w - 0.03, drawer_h, 0.02), texture_key, "drawer", "metal_grey", 0.35, 0.25)

				# Jaladera horizontal cromada
				var handle_pos := Vector3(px, dy, ped_d * 0.5 + 0.02)
				var handle_t := base_t * Transform3D(Basis.IDENTITY, handle_pos)
				builder.add_smart_box(handle_t, Vector3(0.12, 0.02, 0.018), texture_key, "handle", 0.30, 0.10, false)

			# 4 Patas tubulares metálicas bajo cada pedestal
			var leg_radius := 0.024
			var leg_inset_x := ped_w * 0.5 - 0.05
			var leg_inset_z := ped_d * 0.5 - 0.06
			for lx in [-leg_inset_x, leg_inset_x]:
				for lz in [-leg_inset_z, leg_inset_z]:
					var leg_pos := Vector3(px + lx, leg_h * 0.5, lz)
					var leg_t := base_t * Transform3D(Basis.IDENTITY, leg_pos)
					builder.add_cylinder(leg_t, leg_radius, leg_h, texture_key, Rect2(0.773, 0.700, 0.227, 0.290), 0.30, 0.75, false)

		# 3. Faldón de modestia central metálico
		var knee_w := (ped_offset_x - ped_w * 0.5) * 2.0
		var modesty_h := ped_h * 0.75
		var modesty_y := h - top_thick - modesty_h * 0.5
		var modesty_z := -ped_d * 0.5 + 0.06
		var modesty_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, modesty_y, modesty_z))
		builder.add_smart_box(modesty_t, Vector3(knee_w + 0.02, modesty_h, 0.02), texture_key, "metal_grey", 0.35, 0.25, false)


# =========================================================================
# 3. ESCRITORIO MODULAR EN L (DESK 04 - ROBLE CLARO Y ESTRUCTURA AZUL)
# =========================================================================
class OfficeDeskLShapedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var main_w: float = params.get("main_width", 1.60)
		var main_d: float = params.get("main_depth", 0.70)
		var return_w: float = params.get("return_width", 0.90)
		var return_d: float = params.get("return_depth", 0.55)
		var h: float = params.get("height", 0.74)
		var texture_key: String = params.get("texture_key", "desk04")

		var top_thick := 0.035
		var top_y := h - top_thick * 0.5

		# 1. Cubierta principal recta con veta horizontal (rotada 90° para que corra a lo largo del escritorio)
		var main_top_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(0.0, top_y, 0.0))
		builder.add_smart_box(main_top_t, Vector3(main_d, top_thick, main_w), texture_key, "wood_top_main")

		# 2. Ala lateral de retorno hacia el frente-izquierda con veta a lo largo del ala
		var return_center_x := -main_w * 0.5 + return_d * 0.5
		var return_center_z := main_d * 0.5 + return_w * 0.5
		var return_top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(return_center_x, top_y, return_center_z))
		builder.add_smart_box(return_top_t, Vector3(return_d, top_thick, return_w), texture_key, "wood_top_return")

		# 3. Estructura de Patas en T Azul Metálico (Blue Sled Frame) en el extremo izquierdo
		var blue_rect := Rect2(0.640, 0.115, 0.300, 0.165)
		var leg_h := h - top_thick
		var leg_radius := 0.026

		# Poste vertical 1 (ala de retorno)
		var post1_pos := Vector3(return_center_x, leg_h * 0.5, return_center_z + return_w * 0.5 - 0.08)
		builder.add_cylinder(base_t * Transform3D(Basis.IDENTITY, post1_pos), leg_radius, leg_h, texture_key, blue_rect, 0.35, 0.50)

		# Patín horizontal de apoyo en piso
		var foot1_pos := Vector3(return_center_x, 0.02, return_center_z + return_w * 0.5 - 0.08)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, foot1_pos), Vector3(return_d - 0.06, 0.04, 0.06), texture_key, "blue_metal", 0.35, 0.50)

		# Poste vertical 2 (frente del ala principal)
		var post2_pos := Vector3(-main_w * 0.5 + 0.08, leg_h * 0.5, -main_d * 0.5 + 0.08)
		builder.add_cylinder(base_t * Transform3D(Basis.IDENTITY, post2_pos), leg_radius, leg_h, texture_key, blue_rect, 0.35, 0.50)
		var foot2_pos := Vector3(-main_w * 0.5 + 0.08, 0.02, 0.0)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, foot2_pos), Vector3(0.06, 0.04, main_d - 0.10), texture_key, "blue_metal", 0.35, 0.50)

		# Travesaño horizontal azul de refuerzo
		var crossbar_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-main_w * 0.5 + 0.08, h - 0.08, 0.0))
		builder.add_smart_box(crossbar_t, Vector3(0.04, 0.04, main_d - 0.12), texture_key, "blue_metal", 0.35, 0.50, false)

		# 4. Pedestal cajonero de madera a la derecha
		var ped_w := 0.42
		var ped_d := main_d - 0.08
		var ped_h := h - top_thick
		var ped_x := main_w * 0.5 - ped_w * 0.5 - 0.04
		var ped_t := base_t * Transform3D(Basis.IDENTITY, Vector3(ped_x, ped_h * 0.5, 0.0))
		builder.add_smart_box(ped_t, Vector3(ped_w, ped_h, ped_d), texture_key, "wood_body", -1.0, -1.0, false)

		# 3 Gavetas con tiradores
		var drawer_count := 3
		var drawer_gap := 0.015
		var drawer_h := (ped_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		for i in range(drawer_count):
			var dy := drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var drawer_pos := Vector3(ped_x, dy, ped_d * 0.5 + 0.005)
			var drawer_t := base_t * Transform3D(Basis.IDENTITY, drawer_pos)
			var d_reg: String = "drawer_deep" if i == 0 else "drawer"
			builder.add_panel_box(drawer_t, Vector3(ped_w - 0.03, drawer_h, 0.02), texture_key, d_reg, "wood_body")

			var handle_pos := Vector3(ped_x, dy, ped_d * 0.5 + 0.02)
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, handle_pos), Vector3(0.12, 0.02, 0.015), texture_key, "handle", 0.30, 0.10, false)


# =========================================================================
# 4. ESCRITORIO SENCILLO CON CAJONERA DERECHA (DESK 03 - VETA HORIZONTAL)
# =========================================================================
class OfficeDeskSinglePedestalRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 1.25)
		var d: float = params.get("depth", 0.68)
		var h: float = params.get("height", 0.75)
		var texture_key: String = params.get("texture_key", "desk03")

		var top_thick := 0.035
		var foot_h := 0.08
		var ped_w := 0.38
		var ped_d := d - 0.06
		var ped_h := h - top_thick - foot_h
		var half_w := w * 0.5

		# 1. Cubierta de madera con nudo y veta que corre a lo largo del escritorio (rotada 90°)
		var top_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(d, top_thick, w), texture_key, "wood_top")

		# 2. Cajonera derecha con 3 gavetas y patas
		var ped_x := half_w - ped_w * 0.5 - 0.02
		var ped_t := base_t * Transform3D(Basis.IDENTITY, Vector3(ped_x, foot_h + ped_h * 0.5, 0.0))
		builder.add_smart_box(ped_t, Vector3(ped_w, ped_h, ped_d), texture_key, "wood_body", -1.0, -1.0, false)

		var drawer_count := 3
		var drawer_gap := 0.015
		var drawer_h := (ped_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		for i in range(drawer_count):
			var dy := foot_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var drawer_pos := Vector3(ped_x, dy, ped_d * 0.5 + 0.005)
			var drawer_t := base_t * Transform3D(Basis.IDENTITY, drawer_pos)
			var d_reg: String = "drawer_deep" if i == 0 else "drawer"
			builder.add_panel_box(drawer_t, Vector3(ped_w - 0.03, drawer_h, 0.02), texture_key, d_reg, "wood_body")

			var handle_pos := Vector3(ped_x, dy, ped_d * 0.5 + 0.02)
			builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, handle_pos), Vector3(0.12, 0.02, 0.015), texture_key, "handle", 0.30, 0.10, false)

		# Patas de la cajonera
		var foot_sz := 0.05
		for fz in [-ped_d * 0.5 + foot_sz, ped_d * 0.5 - foot_sz]:
			var foot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(ped_x, foot_h * 0.5, fz))
			builder.add_smart_box(foot_t, Vector3(foot_sz, foot_h, foot_sz), texture_key, "wood_body")

		# 3. Estructura de patas abiertas a la izquierda (A-frame / patas dobles)
		var leg_x := -half_w + 0.06
		var leg_sz := 0.045
		var leg_h_total := h - top_thick
		# Pata delantera izquierda
		var leg_f_t := base_t * Transform3D(Basis.IDENTITY, Vector3(leg_x, leg_h_total * 0.5, ped_d * 0.5 - 0.03))
		builder.add_smart_box(leg_f_t, Vector3(leg_sz, leg_h_total, leg_sz), texture_key, "leg")
		# Pata trasera izquierda
		var leg_b_t := base_t * Transform3D(Basis.IDENTITY, Vector3(leg_x, leg_h_total * 0.5, -ped_d * 0.5 + 0.03))
		builder.add_smart_box(leg_b_t, Vector3(leg_sz, leg_h_total, leg_sz), texture_key, "leg")
		# Travesaño inferior entre patas
		var leg_rail_t := base_t * Transform3D(Basis.IDENTITY, Vector3(leg_x, 0.08, 0.0))
		builder.add_smart_box(leg_rail_t, Vector3(leg_sz, 0.035, ped_d - 0.06), texture_key, "leg", -1.0, -1.0, false)

		# 4. Faldón de modestia central
		var knee_w := w - ped_w - 0.16
		var modesty_h := ped_h * 0.55
		var modesty_y := h - top_thick - modesty_h * 0.5
		var modesty_x := -half_w + 0.06 + knee_w * 0.5 + 0.02
		var modesty_t := base_t * Transform3D(Basis.IDENTITY, Vector3(modesty_x, modesty_y, -ped_d * 0.5 + 0.04))
		builder.add_smart_box(modesty_t, Vector3(knee_w, modesty_h, 0.02), texture_key, "modesty", -1.0, -1.0, false)


# =========================================================================
# 5. SILLA ERGONÓMICA GIRATORIA VERDE (CHAIR 01)
# =========================================================================
class OfficeChairGreenRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "chair01")
		var seat_h := 0.48
		var seat_w := 0.48
		var seat_d := 0.46
		var cushion_thick := 0.065

		# 1. Asiento acolchado verde con bordes redondeados
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.0))
		builder.add_smart_box(seat_t, Vector3(seat_w, cushion_thick, seat_d), texture_key, "cushion_seat", 0.70, 0.02)

		# Placa inferior de plástico negro del asiento
		var underpan_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h - cushion_thick * 0.5 - 0.015, 0.0))
		builder.add_smart_box(underpan_t, Vector3(seat_w - 0.02, 0.03, seat_d - 0.02), texture_key, "shell_bottom", 0.45, 0.10, false)

		# 2. Respaldo acolchado verde con carcasa plástica negra posterior
		var back_w := 0.42
		var back_h := 0.32
		var back_thick := 0.05
		var back_y := seat_h + 0.12 + back_h * 0.5
		var back_z := -seat_d * 0.5 + 0.02
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z))
		builder.add_panel_box(back_t, Vector3(back_w, back_h, back_thick), texture_key, "cushion_back", "shell_back", 0.70, 0.02)

		# Soporte de columna en J/L (stem) conectando el asiento al respaldo
		var stem_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h + 0.10, back_z - back_thick * 0.5 - 0.015))
		builder.add_smart_box(stem_t, Vector3(0.06, 0.22, 0.03), texture_key, "plastic_black", 0.35, 0.20, false)
		var stem_under_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h - 0.03, back_z * 0.5))
		builder.add_smart_box(stem_under_t, Vector3(0.06, 0.03, -back_z), texture_key, "plastic_black", 0.35, 0.20, false)

		# 3. Cilindro neumático central con fuelle de goma estriado (accordion)
		var cylinder_h := seat_h - 0.08
		var cylinder_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, cylinder_h * 0.5 + 0.04, 0.0))
		builder.add_cylinder(cylinder_t, 0.032, cylinder_h, texture_key, Rect2(0.625, 0.141, 0.133, 0.215), 0.50, 0.10)

		# 4. Base estrellada de 5 radios con ruedas de nylon
		var hub_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, 0.0))
		builder.add_cylinder(hub_t, 0.07, 0.05, texture_key, Rect2(0.125, 0.063, 0.313, 0.328), 0.45, 0.10, false)

		var arm_count := 5
		var arm_length := 0.25
		for a in range(arm_count):
			var angle := deg_to_rad(float(a) * (360.0 / float(arm_count)))
			var arm_rot := Basis(Vector3.UP, angle)
			var arm_pos := arm_rot * Vector3(0.0, 0.05, arm_length * 0.5)
			var arm_t := base_t * Transform3D(arm_rot, arm_pos)
			builder.add_smart_box(arm_t, Vector3(0.045, 0.035, arm_length), texture_key, "base_arms", 0.45, 0.10, false)

			# Rueda giratoria al final de cada radio
			var wheel_pos := arm_rot * Vector3(0.0, 0.03, arm_length)
			var wheel_t := base_t * Transform3D(arm_rot, wheel_pos)
			builder.add_cylinder(wheel_t, 0.028, 0.035, texture_key, Rect2(0.008, 0.781, 0.086, 0.086), 0.40, 0.10, false)


# =========================================================================
# 6. SILLA GIRATORIA DE OFICINA ROJA VINTAGE (CHAIR 02)
# =========================================================================
class OfficeChairRedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "chair02")
		var seat_h := 0.46
		var seat_w := 0.44
		var seat_d := 0.42
		var cushion_thick := 0.05

		# 1. Asiento curvo circular rojo
		var seat_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, seat_h, 0.0))
		builder.add_smart_box(seat_t, Vector3(seat_w, cushion_thick, seat_d), texture_key, "cushion_seat", 0.65, 0.02)

		# 2. Respaldo acolchado ovalado rojo con soporte tubular metálico
		var back_w := 0.38
		var back_h := 0.22
		var back_thick := 0.045
		var back_y := seat_h + 0.16 + back_h * 0.5
		var back_z := -seat_d * 0.5 + 0.03
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, back_y, back_z))
		builder.add_smart_box(back_t, Vector3(back_w, back_h, back_thick), texture_key, "cushion_back", 0.65, 0.02)

		# Estructura de tubo de acero cromado en forma de herradura detrás del respaldo
		var pipe_w := back_w + 0.04
		var pipe_top_pos := Vector3(0.0, back_y + back_h * 0.5 + 0.02, back_z - 0.01)
		builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, pipe_top_pos), Vector3(pipe_w, 0.025, 0.025), texture_key, "metal_pipe", 0.25, 0.85, false)

		for side: float in [-1.0, 1.0]:
			var pipe_side_pos := Vector3(side * pipe_w * 0.5, back_y, back_z - 0.01)
			builder.add_cylinder(base_t * Transform3D(Basis.IDENTITY, pipe_side_pos), 0.013, back_h + 0.04, texture_key, Rect2(0.922, 0.008, 0.070, 0.602), 0.25, 0.85, false)

		# Tubo que baja bajo el asiento
		var spine_pos := Vector3(0.0, seat_h + 0.08, back_z - 0.02)
		builder.add_cylinder(base_t * Transform3D(Basis.IDENTITY, spine_pos), 0.016, 0.16, texture_key, Rect2(0.922, 0.008, 0.070, 0.602), 0.25, 0.85, false)

		# 3. Mecanismo central giratorio y columna con fuelle estriado
		var cylinder_h := seat_h - 0.08
		var cylinder_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, cylinder_h * 0.5 + 0.04, 0.0))
		builder.add_cylinder(cylinder_t, 0.028, cylinder_h, texture_key, Rect2(0.594, 0.414, 0.121, 0.188), 0.45, 0.15)

		# 4. Base de 4 radios metálicos grises
		var arm_count := 4
		var arm_length := 0.24
		for a in range(arm_count):
			var angle := deg_to_rad(float(a) * (360.0 / float(arm_count)) + 45.0)
			var arm_rot := Basis(Vector3.UP, angle)
			var arm_pos := arm_rot * Vector3(0.0, 0.05, arm_length * 0.5)
			var arm_t := base_t * Transform3D(arm_rot, arm_pos)
			builder.add_smart_box(arm_t, Vector3(0.04, 0.03, arm_length), texture_key, "base_grey", 0.35, 0.50, false)

			# Rueda al final
			var wheel_pos := arm_rot * Vector3(0.0, 0.028, arm_length)
			builder.add_cylinder(base_t * Transform3D(arm_rot, wheel_pos), 0.024, 0.03, texture_key, Rect2(0.602, 0.609, 0.281, 0.305), 0.35, 0.50, false)


# =========================================================================
# 7. ARCHIVERO VERTICAL METÁLICO CERRADO (FILE CABINET CLOSED)
# =========================================================================
class OfficeFileCabinetClosedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.46)
		var d: float = params.get("depth", 0.62)
		var h: float = params.get("height", 1.05)
		var texture_key: String = params.get("texture_key", "file_cabinet")

		var kick_h := 0.06
		var top_thick := 0.025
		var casing_h := h - kick_h - top_thick

		# 1. Cubierta superior y cuerpo exterior metálico
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w, top_thick, d), texture_key, "top_surface", 0.40, 0.25)

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h + casing_h * 0.5, 0.0))
		builder.add_smart_box(body_t, Vector3(w, casing_h, d), texture_key, "metal_body", 0.40, 0.25, false)

		# Zócalo inferior
		var kick_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h * 0.5, 0.0))
		builder.add_smart_box(kick_t, Vector3(w - 0.02, kick_h, d - 0.02), texture_key, "kickplate", 0.45, 0.20)

		# 2. Las 3 gavetas verticales (con jaladera y portarótulo integrados en la textura del atlas)
		var drawer_count := 3
		var drawer_gap := 0.015
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		for i in range(drawer_count):
			var dy := kick_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var drawer_pos := Vector3(0.0, dy, d * 0.5 + 0.005)
			var drawer_t := base_t * Transform3D(Basis.IDENTITY, drawer_pos)
			builder.add_panel_box(drawer_t, Vector3(w - 0.03, drawer_h, 0.02), texture_key, "drawer_front", "metal_body", 0.35, 0.30)


# =========================================================================
# 8. ARCHIVERO VERTICAL METÁLICO ABIERTO (FILE CABINET OPEN)
# =========================================================================
class OfficeFileCabinetOpenRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.46)
		var d: float = params.get("depth", 0.62)
		var h: float = params.get("height", 1.05)
		var texture_key: String = params.get("texture_key", "file_cabinet")

		var kick_h := 0.06
		var top_thick := 0.025
		var casing_h := h - kick_h - top_thick

		# 1. Armazón exterior
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w, top_thick, d), texture_key, "top_surface", 0.40, 0.25)

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h + casing_h * 0.5, 0.0))
		builder.add_smart_box(body_t, Vector3(w, casing_h, d), texture_key, "metal_body", 0.40, 0.25, false)

		var kick_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, kick_h * 0.5, 0.0))
		builder.add_smart_box(kick_t, Vector3(w - 0.02, kick_h, d - 0.02), texture_key, "kickplate", 0.45, 0.20)

		# 2. Gavetas: Superior cerrada, Media abierta (0.20m), Inferior muy abierta (0.32m)
		var drawer_count := 3
		var drawer_gap := 0.015
		var drawer_h := (casing_h - float(drawer_count + 1) * drawer_gap) / float(drawer_count)
		var extensions := [0.32, 0.20, 0.00] # Index 0 es inferior, 1 es media, 2 es superior

		for i in range(drawer_count):
			var ext: float = extensions[i]
			var dy := kick_h + drawer_gap + float(i) * (drawer_h + drawer_gap) + drawer_h * 0.5
			var drawer_pos := Vector3(0.0, dy, d * 0.5 + ext + 0.005)
			var drawer_t := base_t * Transform3D(Basis.IDENTITY, drawer_pos)
			builder.add_panel_box(drawer_t, Vector3(w - 0.03, drawer_h, 0.02), texture_key, "drawer_front", "metal_body", 0.35, 0.30)

			# Si la gaveta está extendida, construir el cajón interior y las carpetas colgantes
			if ext > 0.05:
				var box_depth := ext
				var box_center_z := d * 0.5 + ext * 0.5
				# Laterales del cajón abierto
				var side_l := base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.025, dy, box_center_z))
				builder.add_smart_box(side_l, Vector3(0.015, drawer_h - 0.04, box_depth), texture_key, "metal_body", 0.40, 0.25, false)
				var side_r := base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - 0.025, dy, box_center_z))
				builder.add_smart_box(side_r, Vector3(0.015, drawer_h - 0.04, box_depth), texture_key, "metal_body", 0.40, 0.25, false)

				# Carpetas colgantes manila con pestañas
				var folder_pos := Vector3(0.0, dy + 0.01, box_center_z)
				builder.add_smart_box(base_t * Transform3D(Basis.IDENTITY, folder_pos), Vector3(w - 0.08, drawer_h - 0.03, box_depth - 0.04), texture_key, "folders", 0.85, 0.01, false)


# =========================================================================
# 9. ARMARIO ALTO DE OFICINA CON 2 PUERTAS (CUPBOARD 02 TALL)
# =========================================================================
class OfficeCabinetTallRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.95)
		var d: float = params.get("depth", 0.48)
		var h: float = params.get("height", 1.85)
		var texture_key: String = params.get("texture_key", "cupboard02")

		var plinth_h := 0.08
		var top_thick := 0.04
		var door_h := h - plinth_h - top_thick

		# 1. Carcasa exterior de madera (tapa rotada 90° para que la veta corra horizontalmente)
		var top_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(d, top_thick, w), texture_key, "top_panel")

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + door_h * 0.5, 0.0))
		builder.add_smart_box(body_t, Vector3(w, door_h, d), texture_key, "wood_frame", -1.0, -1.0, false)

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w - 0.02, plinth_h, d - 0.02), texture_key, "plinth")

		# 2. Par frontal de puertas batientes Shaker con pomos integrados en la textura del atlas
		var doors_w := w - 0.04
		var door_y := plinth_h + door_h * 0.5
		var doors_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, door_y, d * 0.5 + 0.005))
		builder.add_panel_box(doors_t, Vector3(doors_w, door_h, 0.025), texture_key, "doors_tall_pair", "wood_frame")


# =========================================================================
# 10. MUEBLE BAJO / APARADOR DE OFICINA (CUPBOARD 02 LOW)
# =========================================================================
class OfficeCabinetLowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.95)
		var d: float = params.get("depth", 0.48)
		var h: float = params.get("height", 0.85)
		var texture_key: String = params.get("texture_key", "cupboard02")

		var plinth_h := 0.08
		var top_thick := 0.035
		var door_h := h - plinth_h - top_thick

		# 1. Carcasa de madera (tapa rotada 90° para que la veta corra horizontalmente)
		var top_t := base_t * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(d, top_thick, w), texture_key, "top_panel")

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + door_h * 0.5, 0.0))
		builder.add_smart_box(body_t, Vector3(w, door_h, d), texture_key, "wood_frame", -1.0, -1.0, false)

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w - 0.02, plinth_h, d - 0.02), texture_key, "plinth")

		# 2. Par frontal de puertas bajas con pomos integrados en la textura del atlas
		var doors_w := w - 0.04
		var door_y := plinth_h + door_h * 0.5
		var doors_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, door_y, d * 0.5 + 0.005))
		builder.add_panel_box(doors_t, Vector3(doors_w, door_h, 0.025), texture_key, "doors_low_pair", "wood_frame")


# =========================================================================
# 11. LIBRERO ALTO ABIERTO DE 5 NIVELES (CUPBOARD 01 TALL)
# =========================================================================
class OfficeBookcaseTallRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.95)
		var d: float = params.get("depth", 0.36)
		var h: float = params.get("height", 1.85)
		var shelf_count: int = clampi(params.get("shelf_count", 5), 3, 6)
		var texture_key: String = params.get("texture_key", "cupboard01")

		var wall_thick := 0.035
		var plinth_h := 0.08
		var top_thick := 0.035
		var inner_w := w - wall_thick * 2.0
		var inner_d := d - 0.03

		# 1. Laterales izquierdo y derecho con veta vertical
		var side_h := h - plinth_h - top_thick
		var side_y := plinth_h + side_h * 0.5
		var left_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + wall_thick * 0.5, side_y, 0.0))
		builder.add_smart_box(left_t, Vector3(wall_thick, side_h, d), texture_key, "wood_frame")
		var right_t := base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - wall_thick * 0.5, side_y, 0.0))
		builder.add_smart_box(right_t, Vector3(wall_thick, side_h, d), texture_key, "wood_frame")

		# 2. Techo y Zócalo
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w, top_thick, d), texture_key, "shelf")

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w, plinth_h, d), texture_key, "plinth")

		# 3. Panel de fondo trasero con listones verticales
		var back_h := h - plinth_h - top_thick
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + back_h * 0.5, -d * 0.5 + 0.015))
		builder.add_smart_box(back_t, Vector3(inner_w, back_h, 0.02), texture_key, "back_panel", -1.0, -1.0, false)

		# 4. Repisas intermedias abiertas con veta horizontal
		var shelf_thick := 0.03
		var usable_h := h - plinth_h - top_thick
		var shelf_spacing := usable_h / float(shelf_count)
		for s in range(1, shelf_count):
			var sy := plinth_h + float(s) * shelf_spacing
			var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, sy, 0.01))
			builder.add_smart_box(shelf_t, Vector3(inner_w, shelf_thick, inner_d), texture_key, "shelf")


# =========================================================================
# 12. LIBRERO BAJO ABIERTO DE 2 NIVELES (CUPBOARD 01 LOW)
# =========================================================================
class OfficeBookcaseLowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.95)
		var d: float = params.get("depth", 0.36)
		var h: float = params.get("height", 0.85)
		var texture_key: String = params.get("texture_key", "cupboard01")

		var wall_thick := 0.035
		var plinth_h := 0.08
		var top_thick := 0.035
		var inner_w := w - wall_thick * 2.0
		var inner_d := d - 0.03

		# 1. Laterales con veta vertical
		var side_h := h - plinth_h - top_thick
		var side_y := plinth_h + side_h * 0.5
		var left_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + wall_thick * 0.5, side_y, 0.0))
		builder.add_smart_box(left_t, Vector3(wall_thick, side_h, d), texture_key, "wood_frame")
		var right_t := base_t * Transform3D(Basis.IDENTITY, Vector3( w * 0.5 - wall_thick * 0.5, side_y, 0.0))
		builder.add_smart_box(right_t, Vector3(wall_thick, side_h, d), texture_key, "wood_frame")

		# 2. Techo y Zócalo
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - top_thick * 0.5, 0.0))
		builder.add_smart_box(top_t, Vector3(w, top_thick, d), texture_key, "shelf")

		var plinth_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h * 0.5, 0.0))
		builder.add_smart_box(plinth_t, Vector3(w, plinth_h, d), texture_key, "plinth")

		# 3. Panel de fondo trasero con listones verticales
		var back_h := h - plinth_h - top_thick
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, plinth_h + back_h * 0.5, -d * 0.5 + 0.015))
		builder.add_smart_box(back_t, Vector3(inner_w, back_h, 0.02), texture_key, "back_panel", -1.0, -1.0, false)

		# 4. 1 Repisa intermedia con veta horizontal
		var shelf_thick := 0.03
		var mid_y := plinth_h + (h - plinth_h - top_thick) * 0.5
		var shelf_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, mid_y, 0.01))
		builder.add_smart_box(shelf_t, Vector3(inner_w, shelf_thick, inner_d), texture_key, "shelf")
