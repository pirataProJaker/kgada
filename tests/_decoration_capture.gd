extends SceneTree

func _initialize() -> void:
	var city_scene := preload("res://tests/city_block_test.tscn")
	var instance := city_scene.instantiate()
	root.add_child(instance)

	# Deja pasar varios frames para que _ready()/call_deferred de
	# CityBlockGenerator -> HouseGenerator -> CityDecoration terminen.
	for i in range(10):
		await process_frame

	var city_generator: Node = instance.get_node("CityBlockGenerator")
	# Zoom cercano sobre un solo bloque para ver el detalle de la decoracion.
	var bounds: Rect2 = city_generator.block_rects[0]
	var center := bounds.get_center()
	var view_span := maxf(bounds.size.x, bounds.size.y) * 1.3

	# Camara ortogonal cenital (top-down) para ver toda la ciudad de una vez.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = view_span * 1.15
	cam.far = 2000.0
	instance.add_child(cam)
	cam.global_position = Vector3(center.x, view_span, center.y)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cam.current = true

	await process_frame
	await process_frame

	var image := root.get_viewport().get_texture().get_image()
	image.save_png("res://tests/_decoration_capture.png")
	quit()
