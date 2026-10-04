extends SceneTree

func _init() -> void:
	print("=== ANÁLISIS DE BRILLO Y SATURACIÓN ===")
	
	# Analizar alfombras
	print("\n--- ALFOMBRAS ---")
	for i in range(20):
		var id := "rug_%02d" % i
		var path := "res://assets/textures/furniture/rugs/%s.png" % id
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			var avg_r := 0.0
			var avg_g := 0.0
			var avg_b := 0.0
			var count := 0
			for y in range(0, img.get_height(), 16):
				for x in range(0, img.get_width(), 16):
					var c := img.get_pixel(x, y)
					avg_r += c.r
					avg_g += c.g
					avg_b += c.b
					count += 1
			avg_r /= count
			avg_g /= count
			avg_b /= count
			var lum := 0.2126 * avg_r + 0.7152 * avg_g + 0.0722 * avg_b
			var max_c := maxf(avg_r, maxf(avg_g, avg_b))
			var min_c := minf(avg_r, minf(avg_g, avg_b))
			var sat := (max_c - min_c) / max_c if max_c > 0.001 else 0.0
			print("%s: Lum=%.2f, Sat=%.2f (R=%.2f, G=%.2f, B=%.2f)" % [id, lum, sat, avg_r, avg_g, avg_b])

	# Analizar cobertor del lobo (blanket 12)
	print("\n--- COBERTOR DEL LOBO ---")
	var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/bed_linens_master_atlas.png"))
	if atlas:
		# Wolf blanket is at row 3, col 4 (index 12 in blankets, which start at row 2)
		var cw := atlas.get_width() / 8
		var ch := atlas.get_height() / 5
		var start_x := 4 * cw
		var start_y := 3 * ch
		var avg_r := 0.0
		var avg_g := 0.0
		var avg_b := 0.0
		var count := 0
		for y in range(start_y, start_y + ch, 8):
			for x in range(start_x, start_x + cw, 8):
				var c := atlas.get_pixel(x, y)
				avg_r += c.r
				avg_g += c.g
				avg_b += c.b
				count += 1
		avg_r /= count
		avg_g /= count
		avg_b /= count
		var lum := 0.2126 * avg_r + 0.7152 * avg_g + 0.0722 * avg_b
		var max_c := maxf(avg_r, maxf(avg_g, avg_b))
		var min_c := minf(avg_r, minf(avg_g, avg_b))
		var sat := (max_c - min_c) / max_c if max_c > 0.001 else 0.0
		print("Cobertor Lobo: Lum=%.2f, Sat=%.2f (R=%.2f, G=%.2f, B=%.2f)" % [lum, sat, avg_r, avg_g, avg_b])

	quit()
