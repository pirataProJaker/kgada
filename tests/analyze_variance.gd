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
	print("=== ANALISIS DE FONDO Y VARIANZA LOCAL ===")
	for path in FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var w = img.get_width()
		var h = img.get_height()
		
		# Compute local variance (or max diff with 4-neighbors)
		# For background pixels vs interior pixels
		var bg_diff_max := 0.0
		# Sample perimeter (first 3 rows/cols)
		for y in range(h):
			for x in range(w):
				if x < 3 or x >= w - 3 or y < 3 or y >= h - 3:
					var p = img.get_pixel(x, y)
					var lum = (p.r + p.g + p.b) / 3.0
					# check diff with neighbors
					for n in [Vector2i(x+1, y), Vector2i(x, y+1)]:
						if n.x < w and n.y < h:
							var np = img.get_pixel(n.x, n.y)
							var nlum = (np.r + np.g + np.b) / 3.0
							bg_diff_max = maxf(bg_diff_max, absf(lum - nlum))
							
		print("%s: bg_diff_max = %.4f (byte %d)" % [path.get_file(), bg_diff_max, int(bg_diff_max * 255.0)])
	quit(0)
