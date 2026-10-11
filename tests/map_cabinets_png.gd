extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/furniture/cabinets.png")
	if img == null:
		quit(1)
		return
	
	var w := img.get_width()
	var h := img.get_height()
	print("cabinets.png: %dx%d" % [w, h])
	
	# Let's print ASCII grid of 32x32 blocks to see what each block is:
	# W: white, G: granite (grey/speckled), Wd: wood (warm orange/brown), D: door, K: kick/metal, etc.
	for y in range(0, h, 8):
		var line := ""
		for x in range(0, w, 8):
			var col: Color = img.get_pixel(x, y)
			if col.r > 0.95 and col.g > 0.95 and col.b > 0.95:
				line += ".." # white/blank
			elif col.r > 0.8 and col.g > 0.65 and col.b < 0.6:
				line += "WW" # wood (yellowish orange)
			elif abs(col.r - col.g) < 0.08 and abs(col.g - col.b) < 0.15:
				if col.r > 0.6:
					line += "GG" # granite
				elif col.r > 0.4:
					line += "gg" # darker granite / metal
				else:
					line += "##" # dark
			else:
				line += "xx"
		print("%3d: %s" % [y, line])
	
	quit(0)
