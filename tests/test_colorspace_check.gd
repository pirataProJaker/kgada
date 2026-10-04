extends SceneTree

func _init() -> void:
	var path := "res://assets/textures/furniture/bed_linens_master_atlas.png"
	var res_tex = ResourceLoader.load(path)
	print("ResourceLoader tex type: ", res_tex.get_class() if res_tex else "null")
	if res_tex is Texture2D:
		print("ResourceLoader tex format: ", res_tex.get_image().get_format())
	
	var gpath := ProjectSettings.globalize_path(path)
	var file_img := Image.load_from_file(gpath)
	print("File img format: ", file_img.get_format())
	
	# Check rugs texture array
	var rug_path := "res://assets/textures/furniture/rugs/rug_00.png"
	var rug_res = ResourceLoader.load(rug_path)
	print("Rug ResourceLoader type: ", rug_res.get_class() if rug_res else "null")

	# Check the planar props manager material and shader
	PlanarPropsManager.ensure_initialized()
	var mat := PlanarPropsManager.get_material()
	var shader := mat.shader
	print("Planar shader code snippet:")
	print(shader.code.substr(0, 300))

	quit()
