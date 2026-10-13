extends SceneTree

const COOKIE_NAMES: Array[String] = [
	# Row 0: 01 to 10
	"clasicas",       # 01: Rizko Clásicas (Azul)
	"chocolate",      # 02: Rizko Chocolate (Marrón chocolate)
	"vainilla",       # 03: Rizko Vainilla (Crema vainilla)
	"fresa",          # 04: Rizko Fresa (Rojo fresa)
	"crema",          # 05: Rizko Crema (Negro sandwich crema)
	"limon",          # 06: Rizko Limón (Verde limón)
	"arandano",       # 07: Rizko Arándano (Morado arándano)
	"naranja",        # 09: Rizko Naranja (Naranja cítrico)
	"frutos_rojos",   # 10: Rizko Frutos Rojos (Rosa frambuesa)
	"platano",        # 11: Rizko Plátano (Amarillo plátano)

	# Row 1: 11 to 20
	"chispas",        # 12: Rizko Chispas (Cian chispas chocolate)
	"integrales",     # 13: Rizko Integrales (Azul marino trigo)
	"doble_choco",    # 14: Rizko Doble Chocolate (Blanco y chocolate)
	"menta",          # 15: Rizko Menta (Verde menta turquesa)
	"canela",         # 16: Rizko Canela (Rojo canela)
	"avena",          # 17: Rizko Avena (Lavanda avena)
	"festival",       # 18: Rizko Festival (Negro confeti multicolor)
	"cookies_cream",  # 20: Rizko Cookies & Cream (Azul claro sándwich)
	# Wait, let's verify if Row 0 has 10 items and Row 1 has 10 items!
]

func _init() -> void:
	var path: String = "res://assets/textures/furniture/cookie_packs_atlas.jpg"
	var img: Image = Image.load_from_file(path)
	var w: int = img.get_width()
	var h: int = img.get_height()

	# In the image there are 2 rows:
	# Row 0 has numbers 01, 02, 03, 04, 05, 06, 07, 09, 10... Wait!
	# Let's count how many packages are in row 0 and row 1!
	# Let's inspect the labels / headers above each package!
	print("Atlas dimensions: ", w, "x", h)

	# Row 0: Y=35..275.
	# Row 1: Y=350..595.
	# Let's find each pack's start_x and end_x
	for r in [0, 1]:
		var y_min: int = 40 if r == 0 else 355
		var y_max: int = 270 if r == 0 else 590

		# Profile of X columns that have content
		var col_has_content: Array[bool] = []
		for x in range(w):
			var has_c := false
			for y in range(y_min, y_max):
				var c: Color = img.get_pixel(x, y)
				if c.r > 0.04 or c.g > 0.04 or c.b > 0.04:
					has_c = true
					break
			col_has_content.append(has_c)

		# Packages are separated by black gaps of at least 8 pixels
		var packs := []
		var in_pack := false
		var p_start := 0
		var black_count := 0

		for x in range(w):
			if col_has_content[x]:
				if not in_pack:
					in_pack = true
					p_start = x
				black_count = 0
			else:
				if in_pack:
					black_count += 1
					if black_count >= 6 or x == w - 1:
						in_pack = false
						packs.append(Vector2i(p_start, x - black_count))

		print("Row ", r, " has ", packs.size(), " distinct packages:")
		for i in range(packs.size()):
			var p: Vector2i = packs[i]
			print("  Pack #", i, ": X=[", p.x, "..", p.y, "] (w=", p.y - p.x + 1, ")")

	quit(0)
