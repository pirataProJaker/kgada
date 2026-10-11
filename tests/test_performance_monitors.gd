@tool
extends SceneTree

func _init() -> void:
	print("--- TEST PERFORMANCE MONITORS ---")
	print("FPS: ", Performance.get_monitor(Performance.TIME_FPS))
	print("Draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("Primitives (triangles): ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("Objects: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("Video RAM: ", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	quit(0)
