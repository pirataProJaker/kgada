extends SceneTree

func _initialize() -> void:
	var city_scene := preload("res://tests/city_block_test.tscn")
	root.add_child(city_scene.instantiate())
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("res://tests/city_light_capture.png")
	quit()
