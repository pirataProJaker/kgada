@tool
extends SceneTree

func _init() -> void:
	var v0 := Vector3(0, 0, 0)
	var v1 := Vector3(1, 0, 0)
	var v2 := Vector3(0, 0, 1)
	
	var godot_calc_norm := (v2 - v0).cross(v1 - v0)
	print("Godot calc norm: ", godot_calc_norm)
	print("Matches UP? ", godot_calc_norm.dot(Vector3.UP) > 0.0)
	quit()
