extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada4.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Pixel at x=115, y=95 (bottom right part of desgastada4 that became yellow)
	print("Desgastada4 (115, 95): lum=%.3f, byte=%d" % [
		(img.get_pixel(115, 95).r + img.get_pixel(115, 95).g + img.get_pixel(115, 95).b)/3.0,
		int(((img.get_pixel(115, 95).r + img.get_pixel(115, 95).g + img.get_pixel(115, 95).b)/3.0)*255)
	])
	
	# Let's see at what threshold it gets reached from perimeter
	for t_int in range(255, 150, -1):
		var thresh = t_int / 255.0
		var mask := []
		mask.resize(w * h)
		mask.fill(false)
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
							q.append(n)
		if mask[95 * w + 115]:
			print("Pixel (115, 95) reached at threshold %d/255 (%.4f)" % [t_int, thresh])
			break

	quit(0)
