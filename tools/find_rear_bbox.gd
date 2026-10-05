@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null: quit(); return
	var min_x := 999; var max_x := -1; var min_y := 999; var max_y := -1
	for y in range(0, 50):
		for x in range(160, 256):
			var c := img.get_pixel(x, y)
			# Find red or amber or black pixels
			if (c.r > 0.4 and c.g < 0.3) or (c.r < 0.2 and c.g < 0.2 and c.b < 0.2):
				min_x = min(min_x, x); max_x = max(max_x, x)
				min_y = min(min_y, y); max_y = max(max_y, y)
	print("True rear bbox: x=[", min_x, "..", max_x, "], y=[", min_y, "..", max_y, "]")
	quit()
