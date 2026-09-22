extends SceneTree

var _frames: int = 0
var _scene: Node

func _init() -> void:
	var res = load("res://tests/test_procedural_rose.tscn")
	_scene = res.instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 12:
		var img: Image = root.get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("res://tests/procedural_rose_comparative.png")
			print("Preview saved to res://tests/procedural_rose_comparative.png")
		quit(0)
		return true
	return false
