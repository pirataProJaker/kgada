extends SceneTree

func _init() -> void:
	var img_m := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/microondas.png"))
	var img_c := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/furniture/cabinets.png"))

	print("Microondas: ", img_m.get_width(), "x", img_m.get_height(), " format: ", img_m.get_format())
	print("Cabinets: ", img_c.get_width(), "x", img_c.get_height(), " format: ", img_c.get_format())

	quit(0)
