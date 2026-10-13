class_name CerealBoxesRecipes
extends RefCounted

## Recetas Oficiales de Cajas de Cereal 375g (Play Sector X)
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine con Texture2DArray)
## =========================================================================
## 1 Solo Modelo Paramétrico Universal que soporta las 20 marcas del atlas:
##
##   0. krisp_max        - Krisp Max 375g (Corn Flakes Clásicos)
##   1. zucarinix        - Zucarinix 375g (Azucarados de Maíz con Tigre)
##   2. corny_bits       - Corny Bits 375g (Cereal de Maíz Crujiente)
##   3. choco_bites      - Choco Bites 375g (Cereal con Chocolate)
##   4. fruti_loops      - Fruti Loops 375g (Aros Frutales Multicolores)
##   5. choco_krunch     - Choco Krunch 375g (Bolitas de Chocolate con Oso)
##   6. miel_dorada      - Miel Dorada 375g (Cereal de Maíz con Miel y Abejita)
##   7. estrella_flakes  - Estrella Flakes 375g (Estrellitas Dulces con Estrella)
##   8. granola_mix      - Granola Mix 375g (Granola con Fresa y Arándano)
##   9. avena_crunch     - Avena Crunch 375g (Cereal de Avena Integral)
##  10. tornado_flakes   - Tornado Flakes 375g (Hojuelas con Remolino de Leche)
##  11. frosty_crunch    - Frosty Crunch 375g (Almohaditas Glaseadas con Oso Polar)
##  12. rayo_cereal      - Rayo Cereal 375g (Almohaditas Crujientes con Rayo)
##  13. selva_crunch     - Selva Crunch 375g (Aros Selváticos con Tucán)
##  14. sol_nativo       - Sol Nativo 375g (Hojuelas Tostadas de Trigo y Maíz)
##  15. campo_feliz      - Campo Feliz 375g (Bolitas Dulces con Vaquita)
##  16. dulce_maiz       - Dulce Maíz 375g (Bolitas Multicolores con Conejito)
##  17. choco_rizos      - Choco Rizos 375g (Rizos y Aros de Chocolate Intenso)
##  18. nube_crispy      - Nube Crispy 375g (Arroz Inflado con Nubecita Feliz)
##  19. bosque_crunch    - Bosque Crunch 375g (Aros Dulces con Oso de los Bosques)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. CAJA INDIVIDUAL DE CEREAL (375G)
# =========================================================================
class CerealBoxRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones estándar comerciales de una caja de cereal de 375g
		var w: float = params.get("width", 0.180)    # 18 cm de frente
		var h: float = params.get("height", 0.260)   # 26 cm de altura
		var d: float = params.get("depth", 0.060)    # 6 cm de grosor lateral
		var has_collision: bool = params.get("collision", true)

		# Selección del cereal (por índice 0..19, skin, marca o sabor)
		var cereal_param: Variant = params.get("cereal", params.get("skin", params.get("brand", params.get("box", 0))))
		var box_data: Dictionary = ObjectAtlasScript.get_cereal_box_data(cereal_param)
		var box_id: String = box_data["id"]
		var atlas_key: String = "cereal_boxes_atlas"

		# Orientación horizontal (yaw)
		var yaw_offset: float = float(params.get("rot_y", params.get("yaw", 0.0)))
		var rot_basis := Basis(Vector3.UP, deg_to_rad(yaw_offset))
		var box_t := base_t * Transform3D(rot_basis, Vector3.ZERO)

		var t_panel := 0.002
		var half_h := h * 0.5

		# 1. Núcleo base / lomo / tapas (Color sólido de marca en caras laterales, superior e inferior)
		var core_t := box_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, 0.0))
		builder.add_smart_box(
			core_t,
			Vector3(w - t_panel * 2.0, h, d - t_panel * 2.0),
			atlas_key,
			box_id + "_color",
			0.50,
			0.02,
			has_collision
		)

		# 2. Portada Frontal (+Z): Logotipo de marca, tazón de cereal, mascota y CONT. NET. 375g
		var front_z := (d * 0.5) - (t_panel * 0.5)
		var front_t := box_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, front_z))
		builder.add_smart_box(
			front_t,
			Vector3(w, h, t_panel),
			atlas_key,
			box_id + "_front",
			0.45,
			0.02,
			false
		)

		# 3. Portada Posterior (-Z): Diseño completo de marca
		var back_z := (-d * 0.5) + (t_panel * 0.5)
		var back_t := box_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, back_z))
		builder.add_smart_box(
			back_t,
			Vector3(w, h, t_panel),
			atlas_key,
			box_id + "_front",
			0.45,
			0.02,
			false
		)

		# 4. Panel Lateral Derecho (+X): Tabla de Información Nutricional, icono reciclable y código de barras
		var side_x := (w * 0.5) - (t_panel * 0.5)
		var side_t := box_t * Transform3D(Basis.IDENTITY, Vector3(side_x, half_h, 0.0))
		builder.add_smart_box(
			side_t,
			Vector3(t_panel, h, d),
			atlas_key,
			box_id + "_side",
			0.50,
			0.02,
			false
		)


# =========================================================================
# 2. FILA DE CAJAS DE CEREAL (PARA ANAQUELES Y SUPERMERCADOS)
# =========================================================================
class CerealBoxesRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var boxes_list: Array = params.get("cereals", [0, 1, 2, 3, 4])
		var gap: float = params.get("gap", 0.015)
		var w: float = params.get("width", 0.180)
		var h: float = params.get("height", 0.260)
		var d: float = params.get("depth", 0.060)

		var total_count: int = boxes_list.size()
		var step_x := w + gap
		var total_span := float(total_count - 1) * step_x

		for i in range(total_count):
			var px := -total_span * 0.5 + float(i) * step_x
			var can_t := base_t * Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 0.0))
			CerealBoxRecipe.build(builder, can_t, {
				"cereal": boxes_list[i],
				"width": w,
				"height": h,
				"depth": d,
				"collision": params.get("collision", true)
			})


# =========================================================================
# 3. EXHIBIDOR APILADO / MULTINIVEL DE CEREALES (PASILLO OXXO / TIENDA)
# =========================================================================
class CerealBoxesDisplayRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var rows_data: Array = params.get("rows", [
			[0, 1, 2, 3, 4],
			[5, 6, 7, 8, 9],
			[10, 11, 12, 13, 14],
			[15, 16, 17, 18, 19]
		])
		var shelf_gap_y: float = params.get("shelf_gap_y", 0.320)
		var w: float = params.get("width", 0.180)
		var h: float = params.get("height", 0.260)
		var d: float = params.get("depth", 0.060)

		for r_idx in range(rows_data.size()):
			var row_cereals: Array = rows_data[r_idx]
			var py := float(r_idx) * shelf_gap_y
			var row_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, py, 0.0))
			CerealBoxesRowRecipe.build(builder, row_t, {
				"cereals": row_cereals,
				"width": w,
				"height": h,
				"depth": d,
				"collision": params.get("collision", true)
			})
