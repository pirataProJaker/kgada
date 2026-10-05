@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null:
		quit()
		return

	print("--- VERTICAL SLICE AT HOOD (x=25) ---")
	for y in range(100, 160, 2):
		var c := img.get_pixel(25, y)
		print("y=%3d: (%0.2f, %0.2f, %0.2f, %0.2f)" % [y, c.r, c.g, c.b, c.a])

	quit()
