extends Node3D

@onready var city_generator: CityLayoutGenerator = $CityLayoutGenerator
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	await get_tree().process_frame
	if city_generator.block_rects.is_empty():
		return

	var bounds := city_generator.block_rects[0]
	for rect in city_generator.block_rects.slice(1):
		bounds = bounds.merge(rect)
	var center := bounds.get_center()
	var view_span := maxf(bounds.size.x, bounds.size.y)

	camera.global_position = Vector3(
		center.x - view_span * 0.72,
		view_span * 0.82,
		center.y + view_span * 0.72
	)
	camera.look_at(Vector3(center.x, 0.0, center.y), Vector3.UP)
	camera.current = true