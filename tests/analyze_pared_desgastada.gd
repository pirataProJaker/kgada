extends SceneTree

const FILES = [
	"res://assets/textures/house/pared_desgastada2.png",
	"res://assets/textures/house/pared_desgastada3.png",
	"res://assets/textures/house/pared_desgastada4.png",
	"res://assets/textures/house/pared_desgastada5.png",
	"res://assets/textures/house/pared_desgastada6.png",
	"res://assets/textures/house/pared_desgastada7.png",
	"res://assets/textures/house/pintura_desgastada.png"
]

func _init() -> void:
	print("=== ANALISIS DE TEXTURAS PARED DESGASTADA ===")
	for path in FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if not img:
			print("Error al cargar: ", path)
			continue
		var w = img.get_width()
		var h = img.get_height()
		var fmt = img.get_format()
		
		# Analizar esquinas y bordes
		var corners = [
			img.get_pixel(0, 0),
			img.get_pixel(w - 1, 0),
			img.get_pixel(0, h - 1),
			img.get_pixel(w - 1, h - 1)
		]
		
		# Min y Max luminancia
		var min_lum := 1.0
		var max_lum := 0.0
		var pure_white_count := 0
		var near_white_count := 0 # lum > 0.95 and not pure white
		var grey_count := 0 # lum between 0.70 and 0.95
		var dark_count := 0 # lum < 0.70
		
		# Histograma de luminancias altas
		var lum_bins := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] # 0.90 to 1.00 in 0.01 steps
		
		for y in range(h):
			for x in range(w):
				var p := img.get_pixel(x, y)
				var lum := (p.r + p.g + p.b) / 3.0
				min_lum = minf(min_lum, lum)
				max_lum = maxf(max_lum, lum)
				
				if p.r >= 0.999 and p.g >= 0.999 and p.b >= 0.999:
					pure_white_count += 1
				elif lum >= 0.95:
					near_white_count += 1
				elif lum >= 0.70:
					grey_count += 1
				else:
					dark_count += 1
					
				if lum >= 0.90:
					var bin_idx = clamp(int((lum - 0.90) * 100.0), 0, 9)
					lum_bins[bin_idx] += 1
		
		var total_px = float(w * h)
		var base_name = path.get_file()
		print("\n--- %s (%dx%d, fmt=%d) ---" % [base_name, w, h, fmt])
		print("  Esquinas: (0,0)=%s, (w-1,0)=%s" % [corners[0], corners[1]])
		print("  Lum min=%.3f, max=%.3f" % [min_lum, max_lum])
		print("  Pure white (>=0.999): %d (%.1f%%)" % [pure_white_count, pure_white_count / total_px * 100.0])
		print("  Near white (0.95..0.999): %d (%.1f%%)" % [near_white_count, near_white_count / total_px * 100.0])
		print("  Light grey (0.70..0.95): %d (%.1f%%)" % [grey_count, grey_count / total_px * 100.0])
		print("  Dark content (<0.70): %d (%.1f%%)" % [dark_count, dark_count / total_px * 100.0])
		print("  High lum bins [0.90..1.00]: ", lum_bins)
		
	quit(0)
