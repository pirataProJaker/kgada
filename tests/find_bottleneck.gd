extends SceneTree

func _init() -> void:
	var path = "res://assets/textures/house/pared_desgastada6.png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var w = img.get_width()
	var h = img.get_height()
	
	# Let's inspect a pixel in the center that turned yellow, say (x=60, y=60)
	# What is its luminance?
	print("Pixel (60, 60): lum=%.3f (RGB: %s)" % [(img.get_pixel(60, 60).r + img.get_pixel(60, 60).g + img.get_pixel(60, 60).b)/3.0, str(img.get_pixel(60, 60))])
	print("Pixel (65, 30): lum=%.3f (RGB: %s)" % [(img.get_pixel(65, 30).r + img.get_pixel(65, 30).g + img.get_pixel(65, 30).b)/3.0, str(img.get_pixel(65, 30))])
	print("Pixel (100, 20): lum=%.3f (RGB: %s)" % [(img.get_pixel(100, 20).r + img.get_pixel(100, 20).g + img.get_pixel(100, 20).b)/3.0, str(img.get_pixel(100, 20))])
	
	# Let's find min bottleneck luminance on the flood fill path from perimeter to (60, 60)
	# Using Dijkstra / BFS to find the max-min-capacity path from perimeter
	var max_bottleneck := []
	max_bottleneck.resize(w * h)
	max_bottleneck.fill(-1.0)
	
	# Priority queue or sorted search: find for each pixel the maximum threshold under which it is connected to perimeter
	# That is, the minimum luminance on the path from perimeter to pixel (we want to maximize this bottleneck)
	# Standard Dijkstra:
	var dist := []
	dist.resize(w * h)
	dist.fill(-1.0) # will store highest bottleneck
	
	# We can use simple threshold stepping from 1.0 down to 0.0 in steps of 0.005
	# to see at what threshold (60, 60) gets reached!
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
		if mask[60 * w + 60]:
			print("Center pixel (60, 60) was reached at threshold t = %d/255 (%.4f)!" % [t_int, thresh])
			break

	quit(0)
