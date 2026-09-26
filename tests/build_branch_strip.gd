@tool
extends SceneTree

func _init() -> void:
	var out_dir = "res://assets/vegetation/alnus/"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var files = [
		{"name": "hojaAlnus1", "path": "res://assets/vegetation/alnus/hoja_alnus_1.png", "anchor": Vector2i(610, 1023)},
		{"name": "hojaAlnus2", "path": "res://assets/vegetation/alnus/hoja_alnus_2.png", "anchor": Vector2i(511, 755)},
		{"name": "hojaAlnus3", "path": "res://assets/vegetation/alnus/hoja_alnus_3.png", "anchor": Vector2i(544, 730)},
		{"name": "hojaAlnus4", "path": "res://assets/vegetation/alnus/hoja_alnus_4.png", "anchor": Vector2i(498, 509)}
	]

	for f in files:
		var img = Image.load_from_file(ProjectSettings.globalize_path(f.path))
		if img:
			# Find non-transparent bounding box
			var min_x = 1024
			var max_x = 0
			var min_y = 1024
			var max_y = 0
			for y in range(1024):
				for x in range(1024):
					if img.get_pixel(x, y).a > 0.05:
						min_x = mini(min_x, x)
						max_x = maxi(max_x, x)
						min_y = mini(min_y, y)
						max_y = maxi(max_y, y)
			print(f.name, " bbox: x=[", min_x, ", ", max_x, "] y=[", min_y, ", ", max_y, "] anchor=", f.anchor)

	quit()
