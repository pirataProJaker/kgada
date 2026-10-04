extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Flood fill from (0,0) with threshold 248
	var visited := []
	visited.resize(w * h)
	visited.fill(false)
	var queue := [Vector2i(0, 0)]
	visited[0] = true
	var head = 0
	while head < queue.size():
		var curr = queue[head]
		head += 1
		for n in [Vector2i(curr.x+1, curr.y), Vector2i(curr.x-1, curr.y), Vector2i(curr.x, curr.y+1), Vector2i(curr.x, curr.y-1)]:
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
				var idx = n.y * w + n.x
				if not visited[idx]:
					var p = img.get_pixel(n.x, n.y)
					if (p.r + p.g + p.b) / 3.0 >= 248.0 / 255.0:
						visited[idx] = true
						queue.append(n)
						
	# Check if (35, 80) is visited (i.e. connected to border)
	print("Es (35, 80) parte del fondo exterior? ", visited[80 * w + 35])
	
	# Let's save a visual mask of visited vs non-visited
	var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			if visited[y * w + x]:
				mask.set_pixel(x, y, Color(1, 0, 0, 1)) # Red = Background
			else:
				var p = img.get_pixel(x, y)
				mask.set_pixel(x, y, p) # Content
	mask.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db/test_mask4.png")
	print("Guardada mascara test_mask4.png")
	quit(0)
