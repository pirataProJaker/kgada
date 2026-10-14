class_name CartonDrinks237mlRecipes
extends RefCounted

## Recetas Oficiales de Bebidas en Cartón 237ml (Jugos, Leches, Yogurt, Bebidas Vegetales)
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine con Texture2DArray)
## =========================================================================
## Envases compactos individuales de 237 ml (Tetra Brik Slim 237ml):
## Dimensiones métricas reales: 5.3 cm (frente) x 3.8 cm (profundidad) x 12.0 cm (altura).
##
## Catálogo canónico de 50 variedades comerciales:
## Fila 0 (Jugos y Leches 01..10):
##   01. frutalia_manzana        - Frutalia Jugo de Manzana 237ml
##   02. solviva_naranja         - SolViva Jugo de Naranja 237ml
##   03. tropicalin_mango        - Tropicalin Jugo de Mango 237ml
##   04. pinaluz_pina            - PiñaLuz Jugo de Piña 237ml
##   05. chocorio_chocolate      - ChocoRío Leche Chocolate 237ml
##   06. freski_fresa            - Freski Leche Fresa 237ml
##   07. vanigo_vainilla         - VaniGo Leche Vainilla 237ml
##   08. lacteareal_entera       - LácteaReal Leche Entera 237ml
##   09. lacteareal_deslactosada - LácteaReal Leche Deslactosada 237ml
##   10. almavi_almendra         - Almavi Bebida de Almendra 237ml
## Fila 1 (Bebidas Vegetales y Yogurts 11..20):
##   11. sojamix_soya            - SojaMix Bebida de Soya 237ml
##   12. cocovida_coco           - CocoVida Bebida de Coco 237ml
##   13. arrozzen_arroz          - ArrozZen Bebida de Arroz 237ml
##   14. avenago_avena           - AvenaGo Bebida de Avena 237ml
##   15. yogui_fresa             - Yogui Yogurt Bebible Fresa 237ml
##   16. yogui_arandano          - Yogui Yogurt Bebible Arándano 237ml
##   17. yogui_durazno           - Yogui Yogurt Bebible Durazno 237ml
##   18. yogui_mora              - Yogui Yogurt Bebible Mora 237ml
##   19. yogui_coco              - Yogui Yogurt Bebible Coco 237ml
##   20. yogui_frambuesa         - Yogui Yogurt Bebible Frambuesa 237ml
## Fila 2 (Leches Cultivadas, Café, Té, Isotónicas 21..30):
##   21. biolact_vainilla        - Biolact Leche Cultivada Vainilla 237ml
##   22. biolact_fresa           - Biolact Leche Cultivada Fresa 237ml
##   23. biolact_durazno         - Biolact Leche Cultivada Durazno 237ml
##   24. cacaonix_cacao          - CacaoNix Bebida de Cacao 237ml
##   25. cafenatura_cafe         - CaféNatura Bebida de Café 237ml
##   26. tezen_verde             - TéZen Té Verde 237ml
##   27. tezen_negro             - TéZen Té Negro 237ml
##   28. voltik_energetica       - Voltik Bebida Energética 237ml
##   29. hidrafit_isotonica      - HidraFit Bebida Isotónica 237ml
##   30. equiplus_electrolitos   - EquiPlus Bebida Electrolitos Limón 237ml
## Fila 3 (Aguas, Jugos, Sábila, Malvavisco 31..40):
##   31. cocomax_agua_coco       - CocoMax Agua de Coco 237ml
##   32. tomatix_tomate          - Tomatix Jugo de Tomate 237ml
##   33. verdeplus_vegetal       - VerdePlus Jugo Vegetal 237ml
##   34. aloevita_sabila         - AloeVita Bebida de Sábila 237ml
##   35. frutiluz_ponche         - FrutiLuz Ponche de Frutas 237ml
##   36. nube_malvavisco         - Nube Bebida de Malvavisco 237ml
##   37. delimoo_cookies_cream   - DeliMoo Leche Cookies & Cream 237ml
##   38. canelalac_canela        - CanelaLac Leche Canela 237ml
##   39. bananik_platano         - Bananik Jugo de Plátano 237ml
##   40. berrimix_frutos_rojos   - BerriMix Jugo de Frutos Rojos 237ml
## Fila 4 (Cítricos, Tés, Proteína, Cúrcuma 41..50):
##   41. limonfit_limon          - LimónFit Jugo de Limón 237ml
##   42. duraznosol_durazno      - DuraznoSol Jugo de Durazno 237ml
##   43. tefrio_negro            - TéFrío Té Negro con Limón 237ml
##   44. jamaika_jamaica         - Jamaika Té de Jamaica 237ml
##   45. limonada_limon          - Limonada Limonada 237ml
##   46. chocolite_chocolate     - ChocoLite Leche Chocolate Light 237ml
##   47. fresbanana_yogurt       - Fresbanana Yogurt Bebible Fresa-Plátano 237ml
##   48. bosquedulce_yogurt      - BosqueDulce Yogurt Bebible Frutos del Bosque 237ml
##   49. promax_proteina         - ProMax Bebida Proteína 20g 237ml
##   50. curcuma_curcuma         - Cúrcuma+ Bebida de Cúrcuma 237ml

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


# =========================================================================
# 1. ENVASE INDIVIDUAL DE BEBIDA EN CARTÓN 237ml (TETRA BRIK 237ml)
# =========================================================================
class CartonDrink237mlRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		# Dimensiones proporcionales exactas de 237 ml (más chico que 1 Litro)
		var w: float = params.get("width", 0.053)       # 5.3 cm de ancho
		var d: float = params.get("depth", 0.038)       # 3.8 cm de profundidad
		var h: float = params.get("height", 0.120)      # 12.0 cm de altura
		var has_straw: bool = params.get("has_straw", true) # Popote pegado al reverso
		var has_collision: bool = params.get("collision", true)

		# Selección de bebida (0..49, ID semántico o alias)
		var drink_param: Variant = params.get("drink", params.get("flavor", params.get("product", 0)))
		var drink_data: Dictionary = ObjectAtlasScript.get_carton_237ml_data(drink_param)
		var drink_id: String = drink_data["id"]
		var atlas_key: String = "carton_drinks_237ml_atlas"

		var t_panel := 0.0015
		var half_h := h * 0.5

		# 1. Núcleo estructural interno (bloque central con color sólido corporativo)
		var core_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, 0.0))
		builder.add_smart_box(
			core_t,
			Vector3(w - t_panel * 2.0, h - t_panel * 2.0, d - t_panel * 2.0),
			atlas_key,
			drink_id + "_side",
			0.50,
			0.02,
			has_collision
		)

		# 2. Cara Frontal (+Z): Logotipo oficial, gráfica de frutas/splash y contenido 237ml
		var front_z := d * 0.5 - t_panel * 0.5
		var front_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, front_z))
		builder.add_smart_box(
			front_t,
			Vector3(w, h, t_panel),
			atlas_key,
			drink_id + "_front",
			0.45,
			0.02,
			false
		)

		# 3. Cara Posterior (-Z): Diseño corporativo de reverso
		var back_z := -d * 0.5 + t_panel * 0.5
		var back_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, half_h, back_z))
		builder.add_smart_box(
			back_t,
			Vector3(w, h, t_panel),
			atlas_key,
			drink_id + "_front",
			0.45,
			0.02,
			false
		)

		# 4. Cara Lateral Derecha (+X): Tabla de información nutrimental y código de barras
		var right_x := w * 0.5 - t_panel * 0.5
		var right_t := base_t * Transform3D(Basis.IDENTITY, Vector3(right_x, half_h, 0.0))
		builder.add_smart_box(
			right_t,
			Vector3(t_panel, h, d),
			atlas_key,
			drink_id + "_side",
			0.45,
			0.02,
			false
		)

		# 5. Cara Lateral Izquierda (-X): Franja lateral corporativa
		var left_x := -w * 0.5 + t_panel * 0.5
		var left_t := base_t * Transform3D(Basis.IDENTITY, Vector3(left_x, half_h, 0.0))
		builder.add_smart_box(
			left_t,
			Vector3(t_panel, h, d),
			atlas_key,
			drink_id + "_side",
			0.45,
			0.02,
			false
		)

		# 6. Tapa Superior (+Y): Solapa superior del cartón con pliegues Tetra Brik
		var top_y := h - t_panel * 0.5
		var top_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, top_y, 0.0))
		builder.add_smart_box(
			top_t,
			Vector3(w, t_panel, d),
			atlas_key,
			drink_id + "_top",
			0.45,
			0.02,
			false
		)

		# 7. Base Inferior (-Y): Cierre inferior del envase
		var bot_y := t_panel * 0.5
		var bot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, bot_y, 0.0))
		builder.add_smart_box(
			bot_t,
			Vector3(w, t_panel, d),
			atlas_key,
			drink_id + "_side",
			0.55,
			0.02,
			false
		)

		# 8. Popote / Pajilla en bolsita plástica adherida al reverso (-Z)
		if has_straw:
			var straw_w := 0.010
			var straw_h := h * 0.75
			var straw_thick := 0.003
			var straw_z := -d * 0.5 - straw_thick * 0.5
			# Ligera inclinación diagonal característica de los popotes pegados con adhesivo
			var straw_rot := Basis(Vector3(0, 0, 1), deg_to_rad(6.0))
			var straw_t := base_t * Transform3D(straw_rot, Vector3(w * 0.05, half_h, straw_z))

			# Funda transparente de celofán (blanco translúcido sutil)
			builder.add_smart_box(
				straw_t,
				Vector3(straw_w, straw_h, straw_thick),
				atlas_key,
				drink_id + "_side",
				0.20,
				0.05,
				false
			)
			# Popote cilíndrico interno
			var inner_straw_t := straw_t * Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(90.0)), Vector3(0.0, 0.0, -0.0005))
			builder.add_smart_cylinder(
				inner_straw_t,
				0.002,
				straw_h * 0.88,
				atlas_key,
				drink_id + "_top",
				0.40,
				0.02,
				false
			)


# =========================================================================
# 2. FILA DE EXHIBICIÓN DE BEBIDAS 237ml (REPISAS Y MOSTRADORES)
# =========================================================================
class CartonDrinks237mlRowRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var drinks_list: Array = params.get("drinks", [0, 1, 2, 3, 4, 5, 6, 7])
		var gap: float = params.get("gap", 0.008)
		var carton_w: float = params.get("width", 0.053)
		var carton_d: float = params.get("depth", 0.038)
		var carton_h: float = params.get("height", 0.120)
		var has_straw: bool = params.get("has_straw", true)

		var step_x := carton_w + gap
		var start_x := -float(drinks_list.size() - 1) * step_x * 0.5

		for i in range(drinks_list.size()):
			var item_pos := Vector3(start_x + float(i) * step_x, 0.0, 0.0)
			var item_t := base_t * Transform3D(Basis.IDENTITY, item_pos)
			CartonDrink237mlRecipe.build(builder, item_t, {
				"drink": drinks_list[i],
				"width": carton_w,
				"depth": carton_d,
				"height": carton_h,
				"has_straw": has_straw,
				"collision": params.get("collision", true)
			})


# =========================================================================
# 3. EXHIBIDOR COMERCIAL / CHAROLA DE CARTÓN PARA TIENDA DE CONVENIENCIA
# =========================================================================
class CartonDrinks237mlDisplayRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var rows: int = params.get("rows", 3)
		var cols: int = params.get("cols", 4)
		var drink_start: int = params.get("drink_start", 0)
		var drinks_custom: Array = params.get("drinks", [])

		var carton_w: float = 0.053
		var carton_d: float = 0.038
		var carton_h: float = 0.120
		var gap_x: float = 0.005
		var gap_z: float = 0.006

		var step_x := carton_w + gap_x
		var step_z := carton_d + gap_z

		var total_w := float(cols) * step_x + 0.010
		var total_d := float(rows) * step_z + 0.010
		var tray_wall_h := 0.035
		var t_tray := 0.003

		# Charola de cartón corrugado comercial
		var tray_base_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, t_tray * 0.5, 0.0))
		builder.add_smart_box(
			tray_base_t,
			Vector3(total_w, t_tray, total_d),
			"carton_drinks_237ml_atlas",
			"frutalia_manzana_side",
			0.80,
			0.0,
			true
		)

		# Pared frontal baja de la charola
		var front_wall_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, tray_wall_h * 0.5, total_d * 0.5 - t_tray * 0.5))
		builder.add_smart_box(
			front_wall_t,
			Vector3(total_w, tray_wall_h, t_tray),
			"carton_drinks_237ml_atlas",
			"solviva_naranja_side",
			0.80,
			0.0,
			false
		)

		# Pared posterior de la charola
		var back_wall_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, (tray_wall_h * 1.5) * 0.5, -total_d * 0.5 + t_tray * 0.5))
		builder.add_smart_box(
			back_wall_t,
			Vector3(total_w, tray_wall_h * 1.5, t_tray),
			"carton_drinks_237ml_atlas",
			"frutalia_manzana_side",
			0.80,
			0.0,
			false
		)

		# Instanciación de la matriz de jugos/leches
		var start_x := -float(cols - 1) * step_x * 0.5
		var start_z := -float(rows - 1) * step_z * 0.5

		var item_count := 0
		for r in range(rows):
			for c in range(cols):
				var drink_val: Variant = drink_start + item_count
				if item_count < drinks_custom.size():
					drink_val = drinks_custom[item_count]

				var pos := Vector3(start_x + float(c) * step_x, t_tray, start_z + float(r) * step_z)
				var item_t := base_t * Transform3D(Basis.IDENTITY, pos)
				CartonDrink237mlRecipe.build(builder, item_t, {
					"drink": drink_val,
					"width": carton_w,
					"depth": carton_d,
					"height": carton_h,
					"has_straw": true,
					"collision": false
				})
				item_count += 1
