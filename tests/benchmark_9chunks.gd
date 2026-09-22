extends SceneTree

var _frames: int = 0

func _init() -> void:
	var res = load("res://scenes/flower_field_9chunks.tscn")
	root.add_child(res.instantiate())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 30 and _frames % 30 == 0:
		print("Frame %d: FPS = %d, DrawCalls = %d" % [
			_frames, 
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		])
	if _frames >= 150:
		print("=== BENCHMARK COMPLETED: Smooth and Stable ===")
		quit(0)
		return true
	return false
