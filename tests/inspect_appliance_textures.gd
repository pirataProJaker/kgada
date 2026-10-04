extends SceneTree

func _init() -> void:
	var refri_path := "res://assets/textures/furniture/refrigerador.png"
	var estufa_path := "res://assets/textures/furniture/estufa.png"

	var img_r := Image.load_from_file(ProjectSettings.globalize_path(refri_path))
	var img_e := Image.load_from_file(ProjectSettings.globalize_path(estufa_path))

	print("Refrigerador tamaño: ", img_r.get_width(), "x", img_r.get_height(), " formato: ", img_r.get_format())
	print("Estufa tamaño: ", img_e.get_width(), "x", img_e.get_height(), " formato: ", img_e.get_format())
	quit(0)
