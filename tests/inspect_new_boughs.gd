extends SceneTree

func _init() -> void:
	var path1 = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527137.png"
	var path2 = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527145.png"

	for path in [path1, path2]:
		var img = Image.load_from_file(path)
		if not img:
			print("Could not load: ", path)
			continue
		print("=== Image: ", path.get_file(), " ===")
		print("  Size: ", img.get_size(), " format: ", img.get_format())
		
		# Find bounding box of non-transparent pixels
		var min_x = 99999
		var max_x = 0
		var min_y = 99999
		var max_y = 0
		
		var w = img.get_width()
		var h = img.get_height()
		
		# Find stem base (leftmost non-transparent pixels)
		var stem_pts: Array[Vector2] = []
		
		for x in range(w):
			for y in range(h):
				var a = img.get_pixel(x, y).a
				if a > 0.1:
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y
					if x < 40:
						stem_pts.append(Vector2(x, y))
		
		var stem_center = Vector2.ZERO
		for pt in stem_pts:
			stem_center += pt
		if stem_pts.size() > 0:
			stem_center /= stem_pts.size()
			
		print("  BBox: x=[%d..%d] (w=%d), y=[%d..%d] (h=%d)" % [min_x, max_x, max_x - min_x, min_y, max_y, max_y - min_y])
		print("  Stem center near x=0..40: %s (norm: %s)" % [stem_center, Vector2(stem_center.x / w, stem_center.y / h)])
		print("  Aspect ratio (w/h): %.3f" % (float(w) / float(h)))
	quit(0)
