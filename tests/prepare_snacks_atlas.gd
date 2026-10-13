extends SceneTree

const SNACK_NAMES: Array[String] = [
	# Row 0:
	"tostiks",       # 0: Tostik's Original (Totopos de maíz rojo)
	"crujitos",      # 1: Crujitos Queso (Churritos de queso amarillo)
	"rizitas",       # 2: Rizitas Crema y Cebolla (Papas onduladas verde)
	"chispas",       # 3: Chispas Picante (Totopos triangulares naranja picante)
	"puffys",        # 4: Puffys BBQ (Aros crujientes morado barbecue)
	# Row 1:
	"krachitos",     # 5: Krachitos Sal Marina (Papas onduladas azul)
	"fuegorix",      # 6: FuegoRix Extra Picante (Rollitos de maíz negro con fuego)
	"maizmax",       # 7: MaízMax Natural (Totopos de maíz beige crema con elote)
	"bolitas",       # 8: Bolitas Queso (Esferas crujientes de queso rojo)
	"ondulin",       # 9: Ondulín Vinagreta (Papas onduladas cian vinagreta)
	# Row 2:
	"crokis",        # 10: Crokis Barbacoa (Aros crujientes naranja BBQ)
	"papasol",       # 11: Papasol Limón y Sal (Papas fritas verde lima limón y sal)
	"rinrin",        # 12: RinRin Jamón (Botanas crujientes morado jamón ahumado)
	"crujix",        # 13: Crujix Carnitas (Chicharrones crujientes azul carnitas)
	"megapik",       # 14: MegaPik Queso Intenso (Totopos negro con rayo queso)
	# Row 3:
	"saladitas",     # 15: Saladitas Clásicas (Galletas saladas azul rey)
	"paprizas",      # 16: Paprizas Jalapeño (Totopos rojo con jalapeño)
	"chipan",        # 17: Chipán Tocino (Tiras crujientes beige tocino)
	"gomitas",       # 18: Gomitas Frutas (Panditas / gomitas rosa frutas)
	"verdix"         # 19: Verdix Vegetales (Palitos verde vegetales)
]

const SNACK_DISPLAY_NAMES: Array[String] = [
	"Tostik's Original (60g)",
	"Crujitos Queso (60g)",
	"Rizitas Crema y Cebolla (60g)",
	"Chispas Picante (60g)",
	"Puffys BBQ (60g)",
	"Krachitos Sal Marina (60g)",
	"FuegoRix Extra Picante (60g)",
	"MaízMax Natural (60g)",
	"Bolitas Queso (60g)",
	"Ondulín Vinagreta (60g)",
	"Crokis Barbacoa (60g)",
	"Papasol Limón y Sal (60g)",
	"RinRin Jamón (60g)",
	"Crujix Carnitas (60g)",
	"MegaPik Queso Intenso (60g)",
	"Saladitas Clásicas (60g)",
	"Paprizas Jalapeño (60g)",
	"Chipán Tocino (60g)",
	"Gomitas Frutas (60g)",
	"Verdix Vegetales (60g)"
]

const SNACK_BOXES: Array[Dictionary] = [
	# Row 0: ys=12, ye=173
	{ "id": "tostiks",   "row": 0, "col": 0, "fx": 19, "fe": 168, "sx": 169, "se": 200, "ys": 12, "ye": 173 },
	{ "id": "crujitos",  "row": 0, "col": 1, "fx": 224, "fe": 369, "sx": 370, "se": 397, "ys": 12, "ye": 173 },
	{ "id": "rizitas",   "row": 0, "col": 2, "fx": 424, "fe": 569, "sx": 570, "se": 598, "ys": 12, "ye": 173 },
	{ "id": "chispas",   "row": 0, "col": 3, "fx": 625, "fe": 768, "sx": 769, "se": 800, "ys": 12, "ye": 173 },
	{ "id": "puffys",    "row": 0, "col": 4, "fx": 825, "fe": 972, "sx": 973, "se": 1004, "ys": 12, "ye": 173 },

	# Row 1: ys=183, ye=338
	{ "id": "krachitos", "row": 1, "col": 0, "fx": 19, "fe": 168, "sx": 169, "se": 199, "ys": 183, "ye": 338 },
	{ "id": "fuegorix",  "row": 1, "col": 1, "fx": 225, "fe": 370, "sx": 371, "se": 397, "ys": 183, "ye": 338 },
	{ "id": "maizmax",   "row": 1, "col": 2, "fx": 425, "fe": 568, "sx": 569, "se": 597, "ys": 183, "ye": 338 },
	{ "id": "bolitas",   "row": 1, "col": 3, "fx": 625, "fe": 768, "sx": 769, "se": 800, "ys": 183, "ye": 338 },
	{ "id": "ondulin",   "row": 1, "col": 4, "fx": 825, "fe": 971, "sx": 972, "se": 1004, "ys": 183, "ye": 338 },

	# Row 2: ys=347, ye=504
	{ "id": "crokis",    "row": 2, "col": 0, "fx": 19, "fe": 167, "sx": 168, "se": 200, "ys": 347, "ye": 504 },
	{ "id": "papasol",   "row": 2, "col": 1, "fx": 225, "fe": 368, "sx": 369, "se": 398, "ys": 347, "ye": 504 },
	{ "id": "rinrin",    "row": 2, "col": 2, "fx": 425, "fe": 569, "sx": 570, "se": 599, "ys": 347, "ye": 504 },
	{ "id": "crujix",    "row": 2, "col": 3, "fx": 625, "fe": 768, "sx": 769, "se": 800, "ys": 347, "ye": 504 },
	{ "id": "megapik",   "row": 2, "col": 4, "fx": 826, "fe": 971, "sx": 972, "se": 1003, "ys": 347, "ye": 504 },

	# Row 3: ys=515, ye=668
	{ "id": "saladitas", "row": 3, "col": 0, "fx": 19, "fe": 168, "sx": 169, "se": 199, "ys": 515, "ye": 668 },
	{ "id": "paprizas",  "row": 3, "col": 1, "fx": 224, "fe": 368, "sx": 369, "se": 398, "ys": 515, "ye": 668 },
	{ "id": "chipan",    "row": 3, "col": 2, "fx": 426, "fe": 568, "sx": 569, "se": 599, "ys": 515, "ye": 668 },
	{ "id": "gomitas",   "row": 3, "col": 3, "fx": 626, "fe": 768, "sx": 769, "se": 800, "ys": 515, "ye": 668 },
	{ "id": "verdix",    "row": 3, "col": 4, "fx": 826, "fe": 970, "sx": 971, "se": 1001, "ys": 515, "ye": 668 }
]

func _init() -> void:
	var src_path: String = "res://assets/textures/furniture/snack_bags_atlas.jpg"
	var img: Image = Image.load_from_file(src_path)
	if not img:
		print("ERROR: could not load ", src_path)
		quit(1)
		return

	var w: int = img.get_width()
	var h: int = img.get_height()
	print("Atlas dimensions: %dx%d" % [w, h])

	var out_img: Image = img.duplicate()

	# 1. Sample dominant branding color from lateral strip background (below icon, above text)
	var pack_colors: Array[Color] = []
	for p_idx in range(SNACK_BOXES.size()):
		var b: Dictionary = SNACK_BOXES[p_idx]
		var sample_x: int = int((b["sx"] + b["se"]) * 0.5)
		var sample_y: int = b["ys"] + 36 # Clean colored background area
		var c: Color = img.get_pixel(sample_x, sample_y)
		pack_colors.append(c)

	# 2. Paint dedicated color swatches at X=2..16, Y=24 + idx * 31 (size 15x22)
	var swatch_rects: Array[Rect2i] = []
	for p_idx in range(SNACK_BOXES.size()):
		var sx_pos: int = 2
		var sy_pos: int = 24 + p_idx * 31
		var sw_w: int = 15
		var sw_h: int = 22
		var c: Color = pack_colors[p_idx]
		for py in range(sy_pos, sy_pos + sw_h):
			for px in range(sx_pos, sx_pos + sw_w):
				if px < w and py < h:
					out_img.set_pixel(px, py, c)
		swatch_rects.append(Rect2i(sx_pos, sy_pos, sw_w, sw_h))

	# 3. Perform edge dilation for each bag (front + lateral) into surrounding black gutters
	for p_idx in range(SNACK_BOXES.size()):
		var b: Dictionary = SNACK_BOXES[p_idx]
		var fx: int = b["fx"]
		var se: int = b["se"]
		var ys: int = b["ys"]
		var ye: int = b["ye"]

		# Top edge dilation (stretch row ys upwards by 4 pixels)
		for d in range(1, 5):
			var target_y: int = ys - d
			if target_y >= 0:
				for x in range(fx, se + 1):
					out_img.set_pixel(x, target_y, img.get_pixel(x, ys))

		# Bottom edge dilation (stretch row ye downwards by 4 pixels)
		for d in range(1, 5):
			var target_y: int = ye + d
			if target_y < h:
				for x in range(fx, se + 1):
					out_img.set_pixel(x, target_y, img.get_pixel(x, ye))

		# Left edge dilation (stretch col fx leftwards by 4 pixels)
		for d in range(1, 5):
			var target_x: int = fx - d
			if target_x >= 0:
				for y in range(ys - 4, ye + 5):
					if y >= 0 and y < h:
						out_img.set_pixel(target_x, y, out_img.get_pixel(fx, y))

		# Right edge dilation (stretch col se rightwards by 4 pixels)
		for d in range(1, 5):
			var target_x: int = se + d
			if target_x < w:
				for y in range(ys - 4, ye + 5):
					if y >= 0 and y < h:
						out_img.set_pixel(target_x, y, out_img.get_pixel(se, y))

	# 4. Save dilated image as PNG
	var out_png_path: String = "res://assets/textures/furniture/snack_bags_atlas.png"
	var err: Error = out_img.save_png(ProjectSettings.globalize_path(out_png_path))
	if err == OK:
		print("✓ Dilated atlas saved successfully to: ", out_png_path)
	else:
		print("ERROR saving PNG: ", err)

	# 5. Build metadata JSON
	var items_array: Array[Dictionary] = []
	var fw_float := float(w)
	var fh_float := float(h)

	for p_idx in range(SNACK_BOXES.size()):
		var b: Dictionary = SNACK_BOXES[p_idx]
		var pid: String = b["id"]
		var pname: String = SNACK_DISPLAY_NAMES[p_idx]
		var col_r: Color = pack_colors[p_idx]
		var sw: Rect2i = swatch_rects[p_idx]

		var fx: float = float(b["fx"])
		var fe: float = float(b["fe"])
		var sx: float = float(b["sx"])
		var se: float = float(b["se"])
		var ys: float = float(b["ys"])
		var ye: float = float(b["ye"])

		var f_rect := Rect2(fx / fw_float, ys / fh_float, (fe - fx + 1.0) / fw_float, (ye - ys + 1.0) / fh_float)
		var s_rect := Rect2(sx / fw_float, ys / fh_float, (se - sx + 1.0) / fw_float, (ye - ys + 1.0) / fh_float)
		var c_rect := Rect2((float(sw.position.x) + 1.0) / fw_float, (float(sw.position.y) + 1.0) / fh_float, (float(sw.size.x) - 2.0) / fw_float, (float(sw.size.y) - 2.0) / fh_float)
		var full_rect := Rect2(fx / fw_float, ys / fh_float, (se - fx + 1.0) / fw_float, (ye - ys + 1.0) / fh_float)

		var item_info := {
			"index": p_idx,
			"id": pid,
			"name": pname,
			"color_hex": col_r.to_html(false),
			"front_rect": [f_rect.position.x, f_rect.position.y, f_rect.size.x, f_rect.size.y],
			"side_rect": [s_rect.position.x, s_rect.position.y, s_rect.size.x, s_rect.size.y],
			"color_rect": [c_rect.position.x, c_rect.position.y, c_rect.size.x, c_rect.size.y],
			"full_rect": [full_rect.position.x, full_rect.position.y, full_rect.size.x, full_rect.size.y]
		}
		items_array.append(item_info)

	var json_file := FileAccess.open("res://assets/textures/furniture/snack_bags_atlas.json", FileAccess.WRITE)
	if json_file:
		json_file.store_string(JSON.stringify(items_array, "\t"))
		json_file.close()
		print("✓ Metadata JSON saved to: res://assets/textures/furniture/snack_bags_atlas.json")

	print("✓ Snack atlas preparation complete! Total bags: %d" % items_array.size())
	quit(0)
