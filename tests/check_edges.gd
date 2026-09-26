@tool
extends SceneTree

func _init() -> void:
	var paths = [
		"res://assets/vegetation/alnus/hoja_alnus_1.png",
		"res://assets/vegetation/alnus/hoja_alnus_2.png",
		"res://assets/vegetation/alnus/hoja_alnus_3.png",
		"res://assets/vegetation/alnus/hoja_alnus_4.png"
	]

	for p in paths:
		var img = Image.load_from_file(ProjectSettings.globalize_path(p))
		# check pixels where alpha is low (> 0.0 and < 0.5) to see if they are white or dark
		var semi_white = 0
		var semi_dark = 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var px = img.get_pixel(x, y)
				if px.a > 0.05 and px.a < 0.6:
					if px.r > 0.7:
						semi_white += 1
					else:
						semi_dark += 1
		print(p.get_file(), ": semi_white=", semi_white, " semi_dark=", semi_dark)

	quit()
