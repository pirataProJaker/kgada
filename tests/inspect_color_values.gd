extends SceneTree

func _init() -> void:
	print("--- INSPECCIÓN DE TEXTURAS DE CAMA Y ALFOMBRA ---")
	var bed_tex_path := "res://assets/textures/furniture/bed_linens_master_atlas.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(bed_tex_path))
	if img:
		print("Bed linens atlas loaded: %dx%d, format: %d" % [img.get_width(), img.get_height(), img.get_format()])
		# Sample some pixels around wolf blanket (row 3, col 4 or so, around cell 12)
		# Bed atlas has 8 cols x 5 rows.
		# Row 0: sheets 0..7
		# Row 1: sheets 8..15
		# Row 2: blankets 0..7
		# Row 3: blankets 8..15. Wolf is pattern 12, so row 3, col 4.
		var cell_w := img.get_width() / 8
		var cell_h := img.get_height() / 5
		var cx := int(4.5 * cell_w)
		var cy := int(3.5 * cell_h)
		var col := img.get_pixel(cx, cy)
		print("Wolf blanket sample pixel at (%d, %d): R=%.3f, G=%.3f, B=%.3f" % [cx, cy, col.r, col.g, col.b])
	else:
		print("Could not load bed linens atlas!")

	# Check rug_05 or rug_10
	for rug_id in ["rug_05", "rug_10", "rug_00", "rug_01"]:
		var rug_path := "res://assets/textures/furniture/rugs/%s.png" % rug_id
		var rug_img := Image.load_from_file(ProjectSettings.globalize_path(rug_path))
		if rug_img:
			var center_col := rug_img.get_pixel(rug_img.get_width() / 2, rug_img.get_height() / 2)
			print("%s center pixel: R=%.3f, G=%.3f, B=%.3f" % [rug_id, center_col.r, center_col.g, center_col.b])
		else:
			print("Could not load %s" % rug_path)

	quit()
