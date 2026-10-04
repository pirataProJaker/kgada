extends SceneTree

func _init() -> void:
	print("--- TEST SOURCER_COLOR EN TEXTURE2DARRAY ---")
	# Create an image with known value, e.g. 128 (0.50196)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	var arr := Texture2DArray.new()
	arr.create_from_images([img])
	
	# Let's inspect the Image and Texture2DArray properties
	print("Array layers: ", arr.get_layers())
	print("Array format: ", arr.get_format())
	quit()
