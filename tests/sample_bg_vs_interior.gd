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
	print("=== DETECCION DE VALORES BLANCO VS GRIS CASI BLANCO ===")
	for path in FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if not img:
			continue
		var w = img.get_width()
		var h = img.get_height()
		
		# Sample perimeter pixels (background)
		var bg_min_lum := 1.0
		var bg_max_lum := 0.0
		var bg_min_r := 1.0
		var bg_min_g := 1.0
		var bg_min_b := 1.0
		
		# Top and bottom row
		for x in range(w):
			for y in [0, 1, h - 2, h - 1]:
				var p := img.get_pixel(x, y)
				var lum := (p.r + p.g + p.b) / 3.0
				bg_min_lum = minf(bg_min_lum, lum)
				bg_max_lum = maxf(bg_max_lum, lum)
				bg_min_r = minf(bg_min_r, p.r)
				bg_min_g = minf(bg_min_g, p.g)
				bg_min_b = minf(bg_min_b, p.b)
				
		# Left and right columns
		for y in range(h):
			for x in [0, 1, w - 2, w - 1]:
				var p := img.get_pixel(x, y)
				var lum := (p.r + p.g + p.b) / 3.0
				bg_min_lum = minf(bg_min_lum, lum)
				bg_max_lum = maxf(bg_max_lum, lum)
				bg_min_r = minf(bg_min_r, p.r)
				bg_min_g = minf(bg_min_g, p.g)
				bg_min_b = minf(bg_min_b, p.b)
				
		print("\n%s:" % path.get_file())
		print("  Borde (perimetro): lum min=%.4f (byte %d), max=%.4f (byte %d)" % [
			bg_min_lum, int(round(bg_min_lum * 255.0)),
			bg_max_lum, int(round(bg_max_lum * 255.0))
		])
		print("  Borde min RGB: R=%d, G=%d, B=%d" % [
			int(round(bg_min_r * 255.0)),
			int(round(bg_min_g * 255.0)),
			int(round(bg_min_b * 255.0))
		])
		
		# Now check interior non-perimeter pixels that have high luminance
		# Let's count how many pixels have byte value 255, 254, 253, 252, 251, 250, 245..249, 240..244, etc.
		var byte_counts := {}
		for b in range(230, 256):
			byte_counts[b] = 0
			
		for y in range(h):
			for x in range(w):
				var p := img.get_pixel(x, y)
				var b_val = int(round(((p.r + p.g + p.b) / 3.0) * 255.0))
				if b_val in byte_counts:
					byte_counts[b_val] += 1
					
		print("  Conteo de bytes de 240 a 255:")
		var line_str := "    "
		for b in range(240, 256):
			line_str += "%d:%d  " % [b, byte_counts[b]]
		print(line_str)
		
	quit(0)
