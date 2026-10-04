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
	print("=== PRUEBA DE FLOOD FILL DESDE BORDES ===")
	for path in FILES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if not img:
			continue
		var w = img.get_width()
		var h = img.get_height()
		
		# Probar diferentes umbrales de flood fill (ej. 248, 250, 252)
		for thresh_byte in [245, 248, 250, 252]:
			var thresh = float(thresh_byte) / 255.0
			var visited := []
			visited.resize(w * h)
			visited.fill(false)
			
			var queue := []
			# Agregar todos los píxeles de los 4 bordes si superan el umbral
			for x in range(w):
				for y in [0, h - 1]:
					var idx = y * w + x
					var p = img.get_pixel(x, y)
					if (p.r + p.g + p.b) / 3.0 >= thresh:
						visited[idx] = true
						queue.append(Vector2i(x, y))
			for y in range(1, h - 1):
				for x in [0, w - 1]:
					var idx = y * w + x
					var p = img.get_pixel(x, y)
					if (p.r + p.g + p.b) / 3.0 >= thresh:
						visited[idx] = true
						queue.append(Vector2i(x, y))
						
			# BFS flood fill
			var q_head = 0
			while q_head < queue.size():
				var curr: Vector2i = queue[q_head]
				q_head += 1
				
				for n in [Vector2i(curr.x + 1, curr.y), Vector2i(curr.x - 1, curr.y),
						  Vector2i(curr.x, curr.y + 1), Vector2i(curr.x, curr.y - 1)]:
					if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
						var n_idx = n.y * w + n.x
						if not visited[n_idx]:
							var p = img.get_pixel(n.x, n.y)
							if (p.r + p.g + p.b) / 3.0 >= thresh:
								visited[n_idx] = true
								queue.append(n)
								
			var bg_count = queue.size()
			var interior_light_count = 0
			# Contar píxeles NO visitados (interior) que son casi blancos (lum >= 0.92)
			for y in range(h):
				for x in range(w):
					var idx = y * w + x
					if not visited[idx]:
						var p = img.get_pixel(x, y)
						if (p.r + p.g + p.b) / 3.0 >= 0.90:
							interior_light_count += 1
							
			print("%s (thresh=%d): BG pixels=%d (%.1f%%), Interior claro (>=0.90) PROTEGIDO=%d" % [
				path.get_file(), thresh_byte, bg_count, float(bg_count) / float(w * h) * 100.0, interior_light_count
			])
		print("")
	quit(0)
