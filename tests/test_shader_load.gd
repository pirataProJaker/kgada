extends SceneTree

func _init() -> void:
	ProceduralRoadMaterials.clear_cache()
	var mat = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_ASPHALT)
	print("Asphalt mat: ", mat)
	print("Asphalt tex: ", mat.albedo_texture)
	if mat.albedo_texture:
		print("Asphalt tex size: ", mat.albedo_texture.get_size())
		var img = mat.albedo_texture.get_image()
		print("Pixel (0,0): ", img.get_pixel(0, 0))
		print("Pixel (10,10): ", img.get_pixel(10, 10))
		print("Pixel (30,30): ", img.get_pixel(30, 30))
	quit(0)
