extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada3.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Any pixel with byte < 245
	var fg := []
	fg.resize(w * h)
	fg.fill(false)
	for y in range(h):
		for x in range(w):
			var p = img.get_pixel(x, y)
			var b = int(((p.r + p.g + p.b)/3.0) * 255)
			if b < 245:
				fg[y * w + x] = true
				
	# Connected components of fg
	var visited := []
	visited.resize(w * h)
	visited.fill(false)
	var components := []
	
	for y in range(h):
		for x in range(w):
			var idx = y * w + x
			if fg[idx] and not visited[idx]:
				var comp := []
				var q := [Vector2i(x, y)]
				visited[idx] = true
				var head = 0
				while head < q.size():
					var curr = q[head]
					head += 1
					comp.append(curr)
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
				components.append(comp)
				
	print("Total components with b < 245 in desgastada3: %d" % components.size())
	components.sort_custom(func(a, b): return a.size() > b.size())
	for i in range(mini(15, components.size())):
		print("  Component #%d: size=%d pixels (bbox: %s)" % [i+1, components[i].size(), str(_bbox(components[i]))])
		
	quit(0)

func _bbox(pts: Array) -> Rect2i:
	var min_x = 9999
	var min_y = 9999
	var max_x = -9999
	var max_y = -9999
	for p in pts:
		min_x = mini(min_x, p.x)
		min_y = mini(min_y, p.y)
		max_x = maxi(max_x, p.x)
		max_y = maxi(max_y, p.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
