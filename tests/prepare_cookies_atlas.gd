extends SceneTree

const COOKIE_NAMES: Array[String] = [
	# Row 0 (9 packs):
	"clasicas",       # 01: Azul clásico
	"chocolate",      # 02: Marrón chocolate
	"vainilla",       # 03: Crema vainilla
	"fresa",          # 04: Rojo fresa
	"crema",          # 05: Negro crema
	"limon",          # 06: Verde limón
	"arandano",       # 07: Morado arándano
	"naranja",        # 09: Naranja cítrico
	"frutos_rojos",   # 10: Rosa frutos rojos
	# Row 1 (9 packs):
	"platano",        # 11: Amarillo plátano
	"chispas",        # 12: Cian chispas chocolate
	"integrales",     # 13: Azul marino integral
	"doble_choco",    # 14: Blanco doble chocolate
	"menta",          # 15: Menta pastel
	"canela",         # 16: Rojo canela
	"avena",          # 17: Lavanda avena
	"festival",       # 18: Negro festival confeti
	"cookies_cream"   # 20: Azul claro cookies & cream
]

const COOKIE_DISPLAY_NAMES: Array[String] = [
	"Rizko Clásicas (120g)",
	"Rizko Chocolate (120g)",
	"Rizko Vainilla (120g)",
	"Rizko Fresa (120g)",
	"Rizko Crema (120g)",
	"Rizko Limón (120g)",
	"Rizko Arándano (120g)",
	"Rizko Naranja (120g)",
	"Rizko Frutos Rojos (120g)",
	"Rizko Plátano (120g)",
	"Rizko Chispas (120g)",
	"Rizko Integrales (120g)",
	"Rizko Doble Chocolate (120g)",
	"Rizko Menta (120g)",
	"Rizko Canela (120g)",
	"Rizko Avena (120g)",
	"Rizko Festival (120g)",
	"Rizko Cookies & Cream (120g)"
]

# Raw bounding boxes [fx_start, fx_end, bx_start, bx_end, sx_start, sx_end, y_start, y_end]
const PACK_BOXES: Array[Dictionary] = [
	# Row 0: y_start=35, y_end=273
	{ "id": "clasicas", "fx": 11, "fe": 49, "bx": 55, "be": 83, "sx": 90, "se": 106, "ys": 35, "ye": 273 },
	{ "id": "chocolate", "fx": 123, "fe": 162, "bx": 169, "be": 196, "sx": 203, "se": 217, "ys": 35, "ye": 273 },
	{ "id": "vainilla", "fx": 235, "fe": 273, "bx": 278, "be": 306, "sx": 313, "se": 328, "ys": 35, "ye": 273 },
	{ "id": "fresa", "fx": 343, "fe": 383, "bx": 388, "be": 418, "sx": 426, "se": 442, "ys": 35, "ye": 273 },
	{ "id": "crema", "fx": 462, "fe": 498, "bx": 506, "be": 533, "sx": 541, "se": 555, "ys": 35, "ye": 273 },
	{ "id": "limon", "fx": 573, "fe": 612, "bx": 618, "be": 644, "sx": 651, "se": 666, "ys": 35, "ye": 273 },
	{ "id": "arandano", "fx": 686, "fe": 725, "bx": 732, "be": 762, "sx": 768, "se": 784, "ys": 35, "ye": 273 },
	{ "id": "naranja", "fx": 803, "fe": 841, "bx": 846, "be": 875, "sx": 880, "se": 896, "ys": 35, "ye": 273 },
	{ "id": "frutos_rojos", "fx": 918, "fe": 957, "bx": 962, "be": 989, "sx": 994, "se": 1010, "ys": 35, "ye": 273 },

	# Row 1: y_start=345, y_end=588
	{ "id": "platano", "fx": 12, "fe": 50, "bx": 55, "be": 85, "sx": 90, "se": 106, "ys": 345, "ye": 588 },
	{ "id": "chispas", "fx": 127, "fe": 164, "bx": 169, "be": 197, "sx": 202, "se": 218, "ys": 345, "ye": 588 },
	{ "id": "integrales", "fx": 235, "fe": 272, "bx": 279, "be": 307, "sx": 314, "se": 328, "ys": 345, "ye": 588 },
	{ "id": "doble_choco", "fx": 346, "fe": 383, "bx": 388, "be": 419, "sx": 424, "se": 440, "ys": 345, "ye": 588 },
	{ "id": "menta", "fx": 459, "fe": 497, "bx": 502, "be": 531, "sx": 537, "se": 552, "ys": 345, "ye": 588 },
	{ "id": "canela", "fx": 572, "fe": 609, "bx": 615, "be": 644, "sx": 650, "se": 666, "ys": 345, "ye": 588 },
	{ "id": "avena", "fx": 684, "fe": 723, "bx": 729, "be": 759, "sx": 765, "se": 781, "ys": 345, "ye": 588 },
	{ "id": "festival", "fx": 802, "fe": 838, "bx": 845, "be": 873, "sx": 880, "se": 894, "ys": 345, "ye": 588 },
	{ "id": "cookies_cream", "fx": 915, "fe": 953, "bx": 959, "be": 987, "sx": 992, "se": 1008, "ys": 345, "ye": 588 }
]

func _init() -> void:
	var src_path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(src_path)
	if not img:
		print("ERROR: could not load ", src_path)
		quit(1)
		return

	var w: int = img.get_width()
	var h: int = img.get_height()
	print("Atlas dimensions: %dx%d" % [w, h])

	# Create a copy image to modify
	var out_img: Image = img.duplicate()

	# 1. Compute solid branding color for each pack by sampling Lateral strip background
	var pack_colors: Array[Color] = []
	for p_idx in range(PACK_BOXES.size()):
		var b: Dictionary = PACK_BOXES[p_idx]
		# Sample lateral strip at Y = ys + 30 (clean background area)
		var sample_y: int = b["ys"] + 30
		var sample_x: int = int((b["sx"] + b["se"]) * 0.5)
		var c: Color = img.get_pixel(sample_x, sample_y)
		pack_colors.append(c)

	# 2. Paint color swatches in the bottom black gutter (Y = 635..667)
	# There are 18 packs. We place 18 swatches of size 32x24 at Y=640..664
	var swatch_rects: Array[Rect2i] = []
	for p_idx in range(PACK_BOXES.size()):
		var sx_pos: int = 14 + p_idx * 56
		var sy_pos: int = 640
		var sw_w: int = 40
		var sw_h: int = 24
		var c: Color = pack_colors[p_idx]
		for py in range(sy_pos, sy_pos + sw_h):
			for px in range(sx_pos, sx_pos + sw_w):
				if px < w and py < h:
					out_img.set_pixel(px, py, c)
		swatch_rects.append(Rect2i(sx_pos, sy_pos, sw_w, sw_h))

	# 3. Perform edge dilation for each strip to eradicate black gutters & MIP seams
	# For each pack and each strip, expand edge pixels 3 pixels outward into black pixels
	for p_idx in range(PACK_BOXES.size()):
		var b: Dictionary = PACK_BOXES[p_idx]
		var strips: Array[Vector2i] = [
			Vector2i(b["fx"], b["fe"]),
			Vector2i(b["bx"], b["be"]),
			Vector2i(b["sx"], b["se"])
		]
		var ys: int = b["ys"]
		var ye: int = b["ye"]

		# Top edge dilation (stretch row ys upwards by 4 pixels)
		for d in range(1, 5):
			var target_y: int = ys - d
			if target_y >= 0:
				for s in strips:
					for x in range(s.x, s.y + 1):
						out_img.set_pixel(x, target_y, img.get_pixel(x, ys))

		# Bottom edge dilation (stretch row ye downwards by 4 pixels)
		for d in range(1, 5):
			var target_y: int = ye + d
			if target_y < h:
				for s in strips:
					for x in range(s.x, s.y + 1):
						out_img.set_pixel(x, target_y, img.get_pixel(x, ye))

		# Left/Right edge dilation for each strip (stretch edge column outwards by 3 pixels)
		for s in strips:
			# Left
			for d in range(1, 4):
				var target_x: int = s.x - d
				if target_x >= 0:
					for y in range(ys - 4, ye + 5):
						if y >= 0 and y < h:
							out_img.set_pixel(target_x, y, out_img.get_pixel(s.x, y))
			# Right
			for d in range(1, 4):
				var target_x: int = s.y + d
				if target_x < w:
					for y in range(ys - 4, ye + 5):
						if y >= 0 and y < h:
							out_img.set_pixel(target_x, y, out_img.get_pixel(s.y, y))

	# 4. Save dilated image as PNG
	var out_png_path: String = "res://assets/textures/furniture/cookie_packs_atlas.png"
	var err: Error = out_img.save_png(ProjectSettings.globalize_path(out_png_path))
	if err == OK:
		print("✓ Dilated atlas saved successfully to: ", out_png_path)
	else:
		print("ERROR saving PNG: ", err)

	# 5. Build metadata JSON and dictionary
	var meta_dict := {}
	var items_array: Array[Dictionary] = []

	var fw_float := float(w)
	var fh_float := float(h)

	for p_idx in range(PACK_BOXES.size()):
		var b: Dictionary = PACK_BOXES[p_idx]
		var pid: String = b["id"]
		var pname: String = COOKIE_DISPLAY_NAMES[p_idx]
		var col_r: Color = pack_colors[p_idx]
		var sw: Rect2i = swatch_rects[p_idx]

		var fx: float = float(b["fx"])
		var fe: float = float(b["fe"])
		var bx: float = float(b["bx"])
		var be: float = float(b["be"])
		var sx: float = float(b["sx"])
		var se: float = float(b["se"])
		var ys: float = float(b["ys"])
		var ye: float = float(b["ye"])

		var f_rect := Rect2(fx / fw_float, ys / fh_float, (fe - fx + 1.0) / fw_float, (ye - ys + 1.0) / fh_float)
		var b_rect := Rect2(bx / fw_float, ys / fh_float, (be - bx + 1.0) / fw_float, (ye - ys + 1.0) / fh_float)
		var s_rect := Rect2(sx / fw_float, ys / fh_float, (se - sx + 1.0) / fw_float, (ye - ys + 1.0) / fh_float)
		var c_rect := Rect2((float(sw.position.x) + 2.0) / fw_float, (float(sw.position.y) + 2.0) / fh_float, (float(sw.size.x) - 4.0) / fw_float, (float(sw.size.y) - 4.0) / fh_float)
		var full_rect := Rect2(fx / fw_float, ys / fh_float, (se - fx + 1.0) / fw_float, (ye - ys + 1.0) / fh_float)

		var item_info := {
			"index": p_idx,
			"id": pid,
			"name": pname,
			"color_hex": col_r.to_html(false),
			"front_rect": [f_rect.position.x, f_rect.position.y, f_rect.size.x, f_rect.size.y],
			"back_rect": [b_rect.position.x, b_rect.position.y, b_rect.size.x, b_rect.size.y],
			"side_rect": [s_rect.position.x, s_rect.position.y, s_rect.size.x, s_rect.size.y],
			"color_rect": [c_rect.position.x, c_rect.position.y, c_rect.size.x, c_rect.size.y],
			"full_rect": [full_rect.position.x, full_rect.position.y, full_rect.size.x, full_rect.size.y]
		}
		items_array.append(item_info)

	var json_file := FileAccess.open("res://assets/textures/furniture/cookie_packs_atlas.json", FileAccess.WRITE)
	if json_file:
		json_file.store_string(JSON.stringify(items_array, "\t"))
		json_file.close()
		print("✓ Metadata JSON saved to: res://assets/textures/furniture/cookie_packs_atlas.json")

	print("✓ Cookie atlas preparation complete! Total packs: %d" % items_array.size())
	quit(0)
