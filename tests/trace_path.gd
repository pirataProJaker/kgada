extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada6.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	var thresh = 250.0 / 255.0
	var mask := []
	mask.resize(w * h)
	mask.fill(false)
	var parent := []
	parent.resize(w * h)
	parent.fill(-1)
	
	var q := []
	for x in range(w):
		for y in [0, h - 1]:
			var idx = y * w + x
			var l = (img.get_pixel(x, y).r + img.get_pixel(x, y).g + img.get_pixel(x, y).b) / 3.0
			if l >= thresh:
				mask[idx] = true
				q.append(Vector2i(x, y))
	for y in range(1, h - 1):
		for x in [0, w - 1]:
			var idx = y * w + x
			var l = (img.get_pixel(x, y).r + img.get_pixel(x, y).g + img.get_pixel(x, y).b) / 3.0
			if l >= thresh:
				mask[idx] = true
				q.append(Vector2i(x, y))
				
	var head = 0
	while head < q.size():
		var curr = q[head]
		head += 1
		for n in [Vector2i(curr.x+1, curr.y), Vector2i(curr.x-1, curr.y), Vector2i(curr.x, curr.y+1), Vector2i(curr.x, curr.y-1)]:
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
				var idx = n.y * w + n.x
				if not mask[idx]:
					var l = (img.get_pixel(n.x, n.y).r + img.get_pixel(n.x, n.y).g + img.get_pixel(n.x, n.y).b) / 3.0
					if l >= thresh:
						mask[idx] = true
						parent[idx] = curr.y * w + curr.x
						q.append(n)
						
	# Trace back from (60, 60)
	var curr_idx = 60 * w + 60
	print("Tracing back from (60, 60)...")
	var path_coords := []
	while curr_idx != -1:
		var py = curr_idx / w
		var px = curr_idx % w
		path_coords.append(Vector2i(px, py))
		curr_idx = parent[curr_idx]
		
	path_coords.reverse()
	print("Path length: %d" % path_coords.size())
	for i in range(0, path_coords.size(), maxi(1, path_coords.size() / 15)):
		var pt = path_coords[i]
		var p = img.get_pixel(pt.x, pt.y)
		print("  (%d, %d): lum=%.3f, RGB=(%d, %d, %d)" % [pt.x, pt.y, (p.r+p.g+p.b)/3.0, int(p.r*255), int(p.g*255), int(p.b*255)])
	var last = path_coords[-1]
	var lp = img.get_pixel(last.x, last.y)
	print("  End: (%d, %d): lum=%.3f, RGB=(%d, %d, %d)" % [last.x, last.y, (lp.r+lp.g+lp.b)/3.0, int(lp.r*255), int(lp.g*255), int(lp.b*255)])
	
	quit(0)
