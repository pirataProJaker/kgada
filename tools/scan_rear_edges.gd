@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://assets/textures/vehicles/sedan_80s/sedan_atlas.png")
	if img == null:
		quit()
		return
	print("--- REAR LEFT EDGE SCAN (x=180..190) ---")
	for x in range(180, 190):
		var c := img.get_pixel(x, 25)
		print("x=%3d: (%0.2f, %0.2f, %0.2f)" % [x, c.r, c.g, c.b])

	print("--- REAR RIGHT/CENTER SCAN (x=240..250) ---")
	for x in range(240, 250):
		var c := img.get_pixel(x, 25)
		print("x=%3d: (%0.2f, %0.2f, %0.2f)" % [x, c.r, c.g, c.b])

	quit()
