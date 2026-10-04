extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	print("=== PROCESAMIENTO PERFECCIONADO DE PARED DESGASTADA ===")
	
	var files = [
		"pared_desgastada2.png",
		"pared_desgastada3.png",
		"pared_desgastada4.png",
		"pared_desgastada5.png",
		"pared_desgastada6.png",
		"pared_desgastada7.png",
		"pintura_desgastada.png"
	]
	
	for file_name in files:
		var path = "res://assets/textures/house/" + file_name
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var w = img.get_width()
		var h = img.get_height()
		
		var result := process_desgastada_image(img, w, h)
		
		# Guardar imagen con transparencia procesada
		var base = file_name.get_basename()
		result.save_png(ARTIFACT_DIR + "/clean_alpha_" + base + ".png")
		
		# Componer sobre fondo amarillo para verificación visual
		var comp_yellow := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var wall_color := Color(0.85, 0.72, 0.40, 1.0) # Amarillo ocre de fachada
		
		for y in range(h):
			for x in range(w):
				var p = result.get_pixel(x, y)
				var blended = wall_color.lerp(Color(p.r, p.g, p.b, 1.0), p.a)
				comp_yellow.set_pixel(x, y, blended)
				
		comp_yellow.save_png(ARTIFACT_DIR + "/perfect_comp_" + base + ".png")
		print("Procesado con éxito: perfect_comp_%s.png" % base)
		
	quit(0)

func process_desgastada_image(img: Image, w: int, h: int) -> Image:
	# 1. Mapa de luminancia y gradiente
	var lum_map := []
	lum_map.resize(w * h)
	var grad_map := []
	grad_map.resize(w * h)
	
	for y in range(h):
		for x in range(w):
			var p = img.get_pixel(x, y)
			var l = (p.r + p.g + p.b) / 3.0
			lum_map[y * w + x] = l
			
			var lx = (img.get_pixel(clampi(x+1, 0, w-1), y).r - img.get_pixel(clampi(x-1, 0, w-1), y).r) * 0.5
			var ly = (img.get_pixel(x, clampi(y+1, 0, h-1)).r - img.get_pixel(x, clampi(y-1, 0, h-1)).r) * 0.5
			grad_map[y * w + x] = sqrt(lx*lx + ly*ly) * 255.0

	# 2. Barrera inicial: píxeles oscuros (grietas/sombras/estuco) o con gradiente marcado
	var raw_barrier := []
	raw_barrier.resize(w * h)
	raw_barrier.fill(false)
	for idx in range(w * h):
		var b = int(lum_map[idx] * 255.0)
		if b < 238 or grad_map[idx] > 10.0:
			raw_barrier[idx] = true
			
	# 3. Filtrar motas aisladas de ruido en el fondo
	# Criterio: componente debe tener al menos 40 px, o al menos 20 px con un núcleo oscuro (b < 120)
	var visited := []
	visited.resize(w * h)
	visited.fill(false)
	var clean_barrier := []
	clean_barrier.resize(w * h)
	clean_barrier.fill(false)
	
	for y in range(h):
		for x in range(w):
			var idx = y * w + x
			if raw_barrier[idx] and not visited[idx]:
				var comp_indices := []
				var q := [Vector2i(x, y)]
				visited[idx] = true
				var min_comp_b = 255
				var head = 0
				while head < q.size():
					var curr = q[head]
					head += 1
					var c_idx = curr.y * w + curr.x
					comp_indices.append(c_idx)
					var b_val = int(lum_map[c_idx] * 255.0)
					if b_val < min_comp_b:
						min_comp_b = b_val
					for dy in [-1, 0, 1]:
						for dx in [-1, 0, 1]:
							if dx == 0 and dy == 0: continue
							var nx = curr.x + dx
							var ny = curr.y + dy
							if nx >= 0 and nx < w and ny >= 0 and ny < h:
								var nidx = ny * w + nx
								if raw_barrier[nidx] and not visited[nidx]:
									visited[nidx] = true
									q.append(Vector2i(nx, ny))
									
				# Un daño genuino tiene tamaño >= 40 px, o >= 20 px si tiene un núcleo oscuro marcado (< 120)
				var is_real_damage = comp_indices.size() >= 40 or (comp_indices.size() >= 20 and min_comp_b < 120)
				if is_real_damage:
					for cidx in comp_indices:
						clean_barrier[cidx] = true

	# 4. Dilatación de la barrera por radio R=2 para sellar micro-grietas
	var dilated_barrier := []
	dilated_barrier.resize(w * h)
	dilated_barrier.fill(false)
	var R = 2
	for y in range(h):
		for x in range(w):
			if clean_barrier[y * w + x]:
				for dy in range(-R, R + 1):
					for dx in range(-R, R + 1):
						if dx*dx + dy*dy <= R*R:
							var nx = x + dx
							var ny = y + dy
							if nx >= 0 and nx < w and ny >= 0 and ny < h:
								dilated_barrier[ny * w + nx] = true
								
	# 5. Flood fill desde los 4 bordes del lienzo exterior
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
					
	# 6. Empujar el fondo exterior hacia el borde exacto del daño
	# Se avanza de forma continua hasta convergencia en todos los píxeles que sean fondo blanco o transición clara (b >= 238)
	var final_bg := exterior_bg.duplicate()
	while true:
		var to_add := []
		for y in range(h):
			for x in range(w):
				var idx = y * w + x
				if not final_bg[idx]:
					var has_bg_neighbor = false
					for n in [Vector2i(x+1, y), Vector2i(x-1, y), Vector2i(x, y+1), Vector2i(x, y-1)]:
						if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
							if final_bg[n.y * w + n.x]:
								has_bg_neighbor = true
								break
					if has_bg_neighbor:
						var b = int(lum_map[idx] * 255.0)
						if b >= 238:
							to_add.append(idx)
		if to_add.is_empty():
			break
		for idx in to_add:
			final_bg[idx] = true
			
	# 7. Construir imagen resultante con anti-aliasing y defringing
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for y in range(h):
		for x in range(w):
			var idx = y * w + x
			var p = img.get_pixel(x, y)
			
			if final_bg[idx]:
				# Fondo transparente puro: color neutro oscuro a alpha 0
				out.set_pixel(x, y, Color(0.15, 0.15, 0.15, 0.0))
			else:
				var is_edge = false
				for n in [Vector2i(x+1, y), Vector2i(x-1, y), Vector2i(x, y+1), Vector2i(x, y-1)]:
					if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
						if final_bg[n.y * w + n.x]:
							is_edge = true
							break
							
				var b = int(lum_map[idx] * 255.0)
				var alpha: float = 1.0
				var out_col: Color = p
				
				# En el borde exterior estricto, si el pixel tiene residuo del blanco original,
				# suavizamos el alfa y atenuamos el blanco hacia el color de la sombra
				if is_edge and b > 225:
					alpha = clampf((245.0 - b) / 25.0, 0.15, 0.85)
					# Defringe: multiplicar por factor de atenuación para eliminar halo blanco
					var edge_darken = alpha
					out_col.r = out_col.r * edge_darken + 0.15 * (1.0 - edge_darken)
					out_col.g = out_col.g * edge_darken + 0.15 * (1.0 - edge_darken)
					out_col.b = out_col.b * edge_darken + 0.15 * (1.0 - edge_darken)
					
				out.set_pixel(x, y, Color(out_col.r, out_col.g, out_col.b, alpha))
				
	return out
