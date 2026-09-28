extends SceneTree

func _init() -> void:
	var path = "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96/.user_uploaded/media_1790463527137.png"
	var img = Image.load_from_file(path)
	
	# Sample column x = 100 from y = 220 to y = 270 (across the bark)
	print("Sampling original image x=100:")
	for y in range(220, 270):
		var c = img.get_pixel(100, y)
		var b = (c.r + c.g + c.b) / 3.0
		var max_val = max(c.r, max(c.g, c.b))
		var min_val = min(c.r, min(c.g, c.b))
		var s = (max_val - min_val) / max(max_val, 0.001)
		print("y=%d: rgb=(%.3f, %.3f, %.3f), b=%.3f, s=%.3f, a=%.3f" % [y, c.r, c.g, c.b, b, s, c.a])
	quit(0)
