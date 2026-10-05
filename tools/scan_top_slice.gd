@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null:
		quit()
		return

	print("--- TOP PROFILE SLICE (y=130) ---")
	for x in range(0, 256, 4):
		var c := img.get_pixel(x, 130)
		var desc := "."
		if c.r > 0.7: desc = "W" # White/Light body
		elif c.r < 0.15: desc = "B" # Black glass
		elif c.r > 0.4: desc = "G" # Grey bumper
		print("x=%3d: (%0.2f, %0.2f, %0.2f) %s" % [x, c.r, c.g, c.b, desc])

	quit()
