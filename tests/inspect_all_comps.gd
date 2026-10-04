extends SceneTree

func _init() -> void:
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
		
		# Let's test a couple thresholds: 245, 248, 250
		for thresh_byte in [245, 248]:
			var fg := []
			fg.resize(w * h)
			fg.fill(false)
			for y in range(h):
				for x in range(w):
					var p = img.get_pixel(x, y)
					var b = int(((p.r + p.g + p.b)/3.0) * 255)
					if b < thresh_byte:
						fg[y * w + x] = true
						
			var visited := []
			visited.resize(w * h)
			visited.fill(false)
			var comps := []
			
			for y in range(h):
				for x in range(w):
					var idx = y * w + x
					if fg[idx] and not visited[idx]:
						var comp_size = 0
						var q := [Vector2i(x, y)]
						visited[idx] = true
						var head = 0
						while head < q.size():
							var curr = q[head]
							head += 1
							comp_size += 1
							for dy in [-1, 0, 1]:
								for dx in [-1, 0, 1]:
									if dx == 0 and dy == 0: continue
									var nx = curr.x + dx
									var ny = curr.y + dy
									if nx >= 0 and nx < w and ny >= 0 and ny < h:
										var nidx = ny * w + nx
										if fg[nidx] and not visited[nidx]:
											visited[nidx] = true
											q.append(Vector2i(nx, ny))
						comps.append(comp_size)
			comps.sort()
			comps.reverse()
			var top_str = ""
			for i in range(mini(6, comps.size())):
				top_str += "%d " % comps[i]
			print("%s (thresh=%d): total_comps=%d, top sizes: [%s]" % [file_name, thresh_byte, comps.size(), top_str])

	quit(0)
