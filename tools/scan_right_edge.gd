@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null:
		quit()
		return
	print("--- FRONT GRILL RIGHT EDGE SCAN (x=50..62) ---")
	for x in range(50, 62):
		var s := "x=%2d: " % x
		for y in [22, 26, 30, 34, 38]:
			var c := img.get_pixel(x, y)
			s += "(%0.2f,%0.2f) " % [c.r, c.g]
		print(s)
	quit()
