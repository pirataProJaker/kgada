extends SceneTree

const DRINK_INFOS: Array[Dictionary] = [
	# Row 0:
	{ "id": "frutalia_manzana", "name": "Frutalia Jugo de Manzana (237ml)", "brand": "Frutalia", "cat": "Jugo" },
	{ "id": "solviva_naranja", "name": "SolViva Jugo de Naranja (237ml)", "brand": "SolViva", "cat": "Jugo" },
	{ "id": "tropicalin_mango", "name": "Tropicalin Jugo de Mango (237ml)", "brand": "Tropicalin", "cat": "Jugo" },
	{ "id": "pinaluz_pina", "name": "PiñaLuz Jugo de Piña (237ml)", "brand": "PiñaLuz", "cat": "Jugo" },
	{ "id": "chocorio_chocolate", "name": "ChocoRío Leche Chocolate (237ml)", "brand": "ChocoRío", "cat": "Leche" },
	{ "id": "freski_fresa", "name": "Freski Leche Fresa (237ml)", "brand": "Freski", "cat": "Leche" },
	{ "id": "vanigo_vainilla", "name": "VaniGo Leche Vainilla (237ml)", "brand": "VaniGo", "cat": "Leche" },
	{ "id": "lacteareal_entera", "name": "LácteaReal Leche Entera (237ml)", "brand": "LácteaReal", "cat": "Leche" },
	{ "id": "lacteareal_deslactosada", "name": "LácteaReal Leche Deslactosada (237ml)", "brand": "LácteaReal", "cat": "Leche" },
	{ "id": "almavi_almendra", "name": "Almavi Bebida de Almendra (237ml)", "brand": "Almavi", "cat": "Vegetal" },

	# Row 1:
	{ "id": "sojamix_soya", "name": "SojaMix Bebida de Soya (237ml)", "brand": "SojaMix", "cat": "Vegetal" },
	{ "id": "cocovida_coco", "name": "CocoVida Bebida de Coco (237ml)", "brand": "CocoVida", "cat": "Vegetal" },
	{ "id": "arrozzen_arroz", "name": "ArrozZen Bebida de Arroz (237ml)", "brand": "ArrozZen", "cat": "Vegetal" },
	{ "id": "avenago_avena", "name": "AvenaGo Bebida de Avena (237ml)", "brand": "AvenaGo", "cat": "Vegetal" },
	{ "id": "yogui_fresa", "name": "Yogui Yogurt Bebible Fresa (237ml)", "brand": "Yogui", "cat": "Yogurt" },
	{ "id": "yogui_arandano", "name": "Yogui Yogurt Bebible Arándano (237ml)", "brand": "Yogui", "cat": "Yogurt" },
	{ "id": "yogui_durazno", "name": "Yogui Yogurt Bebible Durazno (237ml)", "brand": "Yogui", "cat": "Yogurt" },
	{ "id": "yogui_mora", "name": "Yogui Yogurt Bebible Mora (237ml)", "brand": "Yogui", "cat": "Yogurt" },
	{ "id": "yogui_coco", "name": "Yogui Yogurt Bebible Coco (237ml)", "brand": "Yogui", "cat": "Yogurt" },
	{ "id": "yogui_frambuesa", "name": "Yogui Yogurt Bebible Frambuesa (237ml)", "brand": "Yogui", "cat": "Yogurt" },

	# Row 2:
	{ "id": "biolact_vainilla", "name": "Biolact Leche Cultivada Vainilla (237ml)", "brand": "Biolact", "cat": "Leche" },
	{ "id": "biolact_fresa", "name": "Biolact Leche Cultivada Fresa (237ml)", "brand": "Biolact", "cat": "Leche" },
	{ "id": "biolact_durazno", "name": "Biolact Leche Cultivada Durazno (237ml)", "brand": "Biolact", "cat": "Leche" },
	{ "id": "cacaonix_cacao", "name": "CacaoNix Bebida de Cacao (237ml)", "brand": "CacaoNix", "cat": "Bebida" },
	{ "id": "cafenatura_cafe", "name": "CaféNatura Bebida de Café (237ml)", "brand": "CaféNatura", "cat": "Café" },
	{ "id": "tezen_verde", "name": "TéZen Té Verde (237ml)", "brand": "TéZen", "cat": "Té" },
	{ "id": "tezen_negro", "name": "TéZen Té Negro (237ml)", "brand": "TéZen", "cat": "Té" },
	{ "id": "voltik_energetica", "name": "Voltik Bebida Energética (237ml)", "brand": "Voltik", "cat": "Energética" },
	{ "id": "hidrafit_isotonica", "name": "HidraFit Bebida Isotónica (237ml)", "brand": "HidraFit", "cat": "Isotónica" },
	{ "id": "equiplus_electrolitos", "name": "EquiPlus Bebida Electrolitos Limón (237ml)", "brand": "EquiPlus", "cat": "Electrolitos" },

	# Row 3:
	{ "id": "cocomax_agua_coco", "name": "CocoMax Agua de Coco (237ml)", "brand": "CocoMax", "cat": "Agua" },
	{ "id": "tomatix_tomate", "name": "Tomatix Jugo de Tomate (237ml)", "brand": "Tomatix", "cat": "Jugo" },
	{ "id": "verdeplus_vegetal", "name": "VerdePlus Jugo Vegetal (237ml)", "brand": "VerdePlus", "cat": "Jugo" },
	{ "id": "aloevita_sabila", "name": "AloeVita Bebida de Sábila (237ml)", "brand": "AloeVita", "cat": "Vegetal" },
	{ "id": "frutiluz_ponche", "name": "FrutiLuz Ponche de Frutas (237ml)", "brand": "FrutiLuz", "cat": "Ponche" },
	{ "id": "nube_malvavisco", "name": "Nube Bebida de Malvavisco (237ml)", "brand": "Nube", "cat": "Bebida" },
	{ "id": "delimoo_cookies_cream", "name": "DeliMoo Leche Cookies & Cream (237ml)", "brand": "DeliMoo", "cat": "Leche" },
	{ "id": "canelalac_canela", "name": "CanelaLac Leche Canela (237ml)", "brand": "CanelaLac", "cat": "Leche" },
	{ "id": "bananik_platano", "name": "Bananik Jugo de Plátano (237ml)", "brand": "Bananik", "cat": "Jugo" },
	{ "id": "berrimix_frutos_rojos", "name": "BerriMix Jugo de Frutos Rojos (237ml)", "brand": "BerriMix", "cat": "Jugo" },

	# Row 4:
	{ "id": "limonfit_limon", "name": "LimónFit Jugo de Limón (237ml)", "brand": "LimónFit", "cat": "Jugo" },
	{ "id": "duraznosol_durazno", "name": "DuraznoSol Jugo de Durazno (237ml)", "brand": "DuraznoSol", "cat": "Jugo" },
	{ "id": "tefrio_negro", "name": "TéFrío Té Negro con Limón (237ml)", "brand": "TéFrío", "cat": "Té" },
	{ "id": "jamaika_jamaica", "name": "Jamaika Té de Jamaica (237ml)", "brand": "Jamaika", "cat": "Té" },
	{ "id": "limonada_limon", "name": "Limonada Limonada (237ml)", "brand": "Limonada", "cat": "Jugo" },
	{ "id": "chocolite_chocolate", "name": "ChocoLite Leche Chocolate Light (237ml)", "brand": "ChocoLite", "cat": "Leche" },
	{ "id": "fresbanana_yogurt", "name": "Fresbanana Yogurt Bebible Fresa-Plátano (237ml)", "brand": "Fresbanana", "cat": "Yogurt" },
	{ "id": "bosquedulce_yogurt", "name": "BosqueDulce Yogurt Bebible Frutos del Bosque (237ml)", "brand": "BosqueDulce", "cat": "Yogurt" },
	{ "id": "promax_proteina", "name": "ProMax Bebida Proteína 20g (237ml)", "brand": "ProMax", "cat": "Proteína" },
	{ "id": "curcuma_curcuma", "name": "Cúrcuma+ Bebida de Cúrcuma (237ml)", "brand": "Cúrcuma+", "cat": "Bebida" }
]

# Standard column spans [fx, fe, sx, se]
# Front is fx..fe, Side is sx..se
const COL_SPANS: Array[Dictionary] = [
	{ "fx": 11, "fe": 66, "sx": 68, "se": 94 },
	{ "fx": 114, "fe": 170, "sx": 172, "se": 199 },
	{ "fx": 218, "fe": 276, "sx": 279, "se": 305 },
	{ "fx": 324, "fe": 383, "sx": 386, "se": 410 },
	{ "fx": 428, "fe": 484, "sx": 487, "se": 511 },
	{ "fx": 528, "fe": 581, "sx": 583, "se": 606 },
	{ "fx": 624, "fe": 680, "sx": 682, "se": 706 },
	{ "fx": 723, "fe": 779, "sx": 781, "se": 806 },
	{ "fx": 823, "fe": 879, "sx": 881, "se": 906 },
	{ "fx": 923, "fe": 980, "sx": 982, "se": 1009 }
]

const ROW_RANGES: Array[Vector2i] = [
	Vector2i(21, 153),
	Vector2i(173, 296),
	Vector2i(316, 435),
	Vector2i(454, 561),
	Vector2i(578, 669)
]

func _init() -> void:
	var src_path := "res://assets/textures/furniture/carton_drinks_237ml_atlas.jpg"
	var img := Image.load_from_file(src_path)
	if not img:
		print("ERROR: Could not load ", src_path)
		quit(1)
		return

	var w := img.get_width()
	var h := img.get_height()
	print("Atlas loaded: %dx%d" % [w, h])

	var out_img: Image = img.duplicate()

	# 1. Build dictionary of all 50 cartons
	var carton_boxes: Array[Dictionary] = []
	for r in range(5):
		var ys: int = ROW_RANGES[r].x
		var ye: int = ROW_RANGES[r].y
		for c in range(10):
			var idx := r * 10 + c
			var col_info: Dictionary = COL_SPANS[c]
			var info: Dictionary = DRINK_INFOS[idx]
			var b := {
				"idx": idx,
				"id": info["id"],
				"name": info["name"],
				"brand": info["brand"],
				"cat": info["cat"],
				"row": r,
				"col": c,
				"fx": col_info["fx"],
				"fe": col_info["fe"],
				"sx": col_info["sx"],
				"se": col_info["se"],
				"ys": ys,
				"ye": ye
			}
			carton_boxes.append(b)

	# 2. Sample dominant branding color for each carton
	# Sample from side face at 15% height below top (clean background area)
	var pack_colors: Array[Color] = []
	for idx in range(carton_boxes.size()):
		var b: Dictionary = carton_boxes[idx]
		var sample_x: int = int((b["sx"] + b["se"]) * 0.5)
		var sample_y: int = b["ys"] + int((b["ye"] - b["ys"]) * 0.18)
		var col: Color = img.get_pixel(sample_x, sample_y)
		pack_colors.append(col)

	# 3. Dedicated color swatches painted at top/bottom margins if needed
	# We can paint 50 swatches in the upper margin Y=2..14 across X columns, or left edge
	# Top margin (Y=2..14) has plenty of room across X=10..1010!
	# 50 swatches, each 16px wide: 50 * 18 = 900px!
	var swatch_rects: Array[Rect2i] = []
	for idx in range(carton_boxes.size()):
		var sw_x: int = 12 + idx * 20
		var sw_y: int = 2
		var sw_w: int = 18
		var sw_h: int = 14
		var c: Color = pack_colors[idx]
		for py in range(sw_y, sw_y + sw_h):
			for px in range(sw_x, sw_x + sw_w):
				if px < w and py < h:
					out_img.set_pixel(px, py, c)
		swatch_rects.append(Rect2i(sw_x, sw_y, sw_w, sw_h))

	# 4. Perform edge dilation for each carton (front + side together)
	# Dilation outwards by 3-4 pixels into black gutters
	for idx in range(carton_boxes.size()):
		var b: Dictionary = carton_boxes[idx]
		var fx: int = b["fx"]
		var fe: int = b["fe"]
		var sx: int = b["sx"]
		var se: int = b["se"]
		var ys: int = b["ys"]
		var ye: int = b["ye"]

		# Top edge dilation (stretch row ys upwards by 3 pixels)
		for d in range(1, 4):
			var target_y := ys - d
			if target_y >= 0:
				for x in range(fx, se + 1):
					out_img.set_pixel(x, target_y, img.get_pixel(x, ys))

		# Bottom edge dilation (stretch row ye downwards by 3 pixels)
		for d in range(1, 4):
			var target_y := ye + d
			if target_y < h:
				for x in range(fx, se + 1):
					out_img.set_pixel(x, target_y, img.get_pixel(x, ye))

		# Left edge dilation (stretch col fx leftwards by 3 pixels)
		for d in range(1, 4):
			var target_x := fx - d
			if target_x >= 0:
				for y in range(ys - 3, ye + 4):
					if y >= 0 and y < h:
						out_img.set_pixel(target_x, y, out_img.get_pixel(fx, y))

		# Right edge dilation (stretch col se rightwards by 3 pixels)
		for d in range(1, 4):
			var target_x := se + d
			if target_x < w:
				for y in range(ys - 3, ye + 4):
					if y >= 0 and y < h:
						out_img.set_pixel(target_x, y, out_img.get_pixel(se, y))

	# 5. Save dilated PNG atlas
	var out_png_path := "res://assets/textures/furniture/carton_drinks_237ml_atlas.png"
	var err := out_img.save_png(ProjectSettings.globalize_path(out_png_path))
	if err == OK:
		print("SUCCESS: Saved dilated atlas to ", out_png_path)
	else:
		print("ERROR saving PNG: ", err)
		quit(1)
		return

	# 6. Generate GDScript data structure code for object_atlas.gd
	var gd_code := ""
	gd_code += "# =========================================================================\n"
	gd_code += "# REGISTRO DE 50 BEBIDAS EN CARTÓN 237ml (JUGOS, LECHES, YOGURT, VEGETAL)\n"
	gd_code += "# =========================================================================\n\n"
	gd_code += "const CARTON_237ML_NAMES: Array[String] = [\n"
	for idx in range(50):
		var b: Dictionary = carton_boxes[idx]
		gd_code += "\t\"%s\",\t# %02d: %s\n" % [b["id"], idx + 1, b["name"]]
	gd_code += "]\n\n"

	gd_code += "const CARTON_237ML_DATA: Array[Dictionary] = [\n"
	var inv_w := 1.0 / float(w)
	var inv_h := 1.0 / float(h)

	for idx in range(50):
		var b: Dictionary = carton_boxes[idx]
		var fx: int = b["fx"]
		var fe: int = b["fe"]
		var sx: int = b["sx"]
		var se: int = b["se"]
		var ys: int = b["ys"]
		var ye: int = b["ye"]
		var sw_rect: Rect2i = swatch_rects[idx]

		var fw := fe - fx + 1
		var sw := se - sx + 1
		var fh := ye - ys + 1

		# Normalized UV rects
		var u_front := Rect2(fx * inv_w, ys * inv_h, fw * inv_w, fh * inv_h)
		var u_side := Rect2(sx * inv_w, ys * inv_h, sw * inv_w, fh * inv_h)
		# Top fold UV: top 18% of front face
		var top_h_px := int(fh * 0.18)
		var u_top := Rect2(fx * inv_w, ys * inv_h, fw * inv_w, top_h_px * inv_h)
		# Swatch UV:
		var u_color := Rect2(sw_rect.position.x * inv_w, sw_rect.position.y * inv_h, sw_rect.size.x * inv_w, sw_rect.size.y * inv_h)

		var c: Color = pack_colors[idx]

		gd_code += "\t{\n"
		gd_code += "\t\t\"index\": %d,\n" % idx
		gd_code += "\t\t\"id\": \"%s\",\n" % b["id"]
		gd_code += "\t\t\"display_name\": \"%s\",\n" % b["name"]
		gd_code += "\t\t\"brand\": \"%s\",\n" % b["brand"]
		gd_code += "\t\t\"category\": \"%s\",\n" % b["cat"]
		gd_code += "\t\t\"color\": Color(%.3f, %.3f, %.3f),\n" % [c.r, c.g, c.b]
		gd_code += "\t\t\"front\": Rect2(%.5f, %.5f, %.5f, %.5f),\n" % [u_front.position.x, u_front.position.y, u_front.size.x, u_front.size.y]
		gd_code += "\t\t\"side\": Rect2(%.5f, %.5f, %.5f, %.5f),\n" % [u_side.position.x, u_side.position.y, u_side.size.x, u_side.size.y]
		gd_code += "\t\t\"top\": Rect2(%.5f, %.5f, %.5f, %.5f),\n" % [u_top.position.x, u_top.position.y, u_top.size.x, u_top.size.y]
		gd_code += "\t\t\"color_swatch\": Rect2(%.5f, %.5f, %.5f, %.5f)\n" % [u_color.position.x, u_color.position.y, u_color.size.x, u_color.size.y]
		gd_code += "\t},\n"

	gd_code += "]\n"

	# Save generated code to file for inspection and integration
	var f := FileAccess.open("res://tests/generated_cartons_237ml_data.gd", FileAccess.WRITE)
	if f:
		f.store_string(gd_code)
		f.close()
		print("SUCCESS: Generated cartons data saved to tests/generated_cartons_237ml_data.gd")

	quit(0)
