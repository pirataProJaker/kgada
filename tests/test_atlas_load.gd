extends SceneTree

func _init() -> void:
	var tex1 = Image.load_from_file("res://assets/vegetation/alnus/alnus_full_bough_atlas.png")
	print("full_bough_atlas: ", tex1.get_width(), "x", tex1.get_height(), ", format: ", tex1.get_format())
	var tex2 = Image.load_from_file("res://assets/vegetation/alnus/alnus_unified_atlas.png")
	print("unified_atlas: ", tex2.get_width(), "x", tex2.get_height(), ", format: ", tex2.get_format())
	quit(0)
