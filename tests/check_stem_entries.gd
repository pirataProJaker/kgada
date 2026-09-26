@tool
extends SceneTree

func _init() -> void:
	var path = "res://assets/vegetation/alnus/alnus_bough_atlas.png"
	var img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if not img:
		print("Failed to load atlas!")
		quit()
		return
	
	var w = img.get_width()
	var h = img.get_height()
	print("Atlas size: ", w, "x", h)
	
	var q_size = 512
	for q in range(4):
		var col = q % 2
		var row = q / 2
		var ox = col * q_size
		var oy = row * q_size
		
		# Find the pixel where the thick stem begins at the bottom-left edge
		var found_stem := false
		var stem_x := -1
		var stem_y := -1
		
		# Search along the bottom edge (y = 500..511) and left edge (x = 0..30)
		for y in range(oy + q_size - 1, oy + q_size - 40, -1):
			for x in range(ox, ox + 150):
				var c = img.get_pixel(x, y)
				if c.a > 0.5 and (c.r + c.g + c.b) / 3.0 < 0.40:
					stem_x = x - ox
					stem_y = y - oy
					found_stem = true
					break
			if found_stem:
				break
				
		print("Quadrant ", q, ": stem enters at local (", stem_x, ", ", stem_y, ") relative to (0,0)")
	quit()
