extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	for file_name in ["pared_desgastada4.png", "pared_desgastada6.png", "pared_desgastada2.png", "pared_desgastada3.png"]:
		var path = "res://assets/textures/house/" + file_name
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var w = img.get_width()
		var h = img.get_height()
		
		# Paso 1: Crear máscara de barrera (píxeles con daño o borde)
		# Un píxel es barrera si tiene textura oscura (b < 235) o alto gradiente
		var barrier := []
		barrier.resize(w * h)
		barrier.fill(false)
		
		for y in range(h):
			for x in range(w):
				var p = img.get_pixel(x, y)
				var b = int(((p.r + p.g + p.b)/3.0) * 255.0)
				
				# Gradiente
				var lx = (img.get_pixel(clampi(x+1, 0, w-1), y).r - img.get_pixel(clampi(x-1, 0, w-1), y).r) * 0.5
				var ly = (img.get_pixel(x, clampi(y+1, 0, h-1)).r - img.get_pixel(x, clampi(y-1, 0, h-1)).r) * 0.5
				var grad = sqrt(lx*lx + ly*ly) * 255.0
				
				# Es barrera si es más oscuro que el fondo o si tiene gradiente
				if b < 240 or grad > 12.0:
					barrier[y * w + x] = true
					
		# Paso 2: Dilatación morfológica de la barrera para cerrar micro-grietas
		var dilated_barrier := []
		dilated_barrier.resize(w * h)
		dilated_barrier.fill(false)
		var radius = 2
		for y in range(h):
			for x in range(w):
				if barrier[y * w + x]:
					for dy in range(-radius, radius + 1):
						for dx in range(-radius, radius + 1):
							if dx*dx + dy*dy <= radius*radius:
								var nx = x + dx
								var ny = y + dy
								if nx >= 0 and nx < w and ny >= 0 and ny < h:
									dilated_barrier[ny * w + nx] = true
									
		# Paso 3: Flood fill desde el perímetro exterior donde NO hay barrera dilatada
		var exterior_bg := []
		exterior_bg.resize(w * h)
		exterior_bg.fill(false)
		var q := []
		
		for x in range(w):
			for y in [0, h - 1]:
				var idx = y * w + x
				if not dilated_barrier[idx]:
					exterior_bg[idx] = true
					q.append(Vector2i(x, y))
		for y in range(1, h - 1):
			for x in [0, w - 1]:
				var idx = y * w + x
				if not dilated_barrier[idx]:
					exterior_bg[idx] = true
					q.append(Vector2i(x, y))
					
		var head = 0
		while head < q.size():
			var curr = q[head]
			head += 1
			for n in [Vector2i(curr.x+1, curr.y), Vector2i(curr.x-1, curr.y), Vector2i(curr.x, curr.y+1), Vector2i(curr.x, curr.y-1)]:
				if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
					var idx = n.y * w + n.x
					if not exterior_bg[idx] and not dilated_barrier[idx]:
						exterior_bg[idx] = true
						q.append(n)
						
		# Ahora dilatamos exterior_bg hacia la barrera pero solo en píxeles que sean fondo blanco plano (b >= 246 y gradiente bajo)
		# para que el fondo llegue justo hasta el borde real del daño
		var final_bg := exterior_bg.duplicate()
		for pass_idx in range(radius + 2):
			var to_add := []
			for y in range(h):
				for x in range(w):
					var idx = y * w + x
					if not final_bg[idx]:
						# Check if neighbor is final_bg
						var has_bg_neighbor = false
						for n in [Vector2i(x+1, y), Vector2i(x-1, y), Vector2i(x, y+1), Vector2i(x, y-1)]:
							if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
								if final_bg[n.y * w + n.x]:
									has_bg_neighbor = true
									break
						if has_bg_neighbor:
							var p = img.get_pixel(x, y)
							var b = int(((p.r + p.g + p.b)/3.0) * 255.0)
							# Si es casi blanco puro y sin textura, es fondo
							if b >= 248:
								to_add.append(idx)
			for idx in to_add:
				final_bg[idx] = true
				
		# Componer sobre amarillo
		var comp := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var wall_color := Color(0.85, 0.72, 0.40, 1.0)
		for y in range(h):
			for x in range(w):
				var p = img.get_pixel(x, y)
				var is_bg = final_bg[y * w + x]
				var alpha = 0.0 if is_bg else 1.0
				var blended = wall_color.lerp(Color(p.r, p.g, p.b, 1.0), alpha)
				comp.set_pixel(x, y, blended)
				
		var base = file_name.get_basename()
		comp.save_png(ARTIFACT_DIR + "/comp_barrier_" + base + ".png")
		print("Saved comp_barrier_%s.png" % base)
		
	quit(0)
