extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/military/military_tile_32_r3_c7.png")
	if img == null:
		print("Error: Could not load texture")
		quit(1)
		return
		
	var w := img.get_width()
	var h := img.get_height()
	print("Texture size: ", w, "x", h)
	
	# Sample along diagonal or along top edge to find stripe period
	# Let's check brightness along the top row (y = 10) and bottom row (y = h - 10)
	# and along left column (x = 10) and right column (x = w - 10)
	var top_yellows := []
	for x in range(w):
		var c := img.get_pixel(x, 20)
		# Yellow has high R and G, lower B
		var is_yellow := (c.r > 0.4 and c.g > 0.3 and c.b < 0.25)
		if is_yellow:
			top_yellows.append(x)
			
	print("Top row yellow pixel x coordinates count: ", top_yellows.size())
	quit(0)
