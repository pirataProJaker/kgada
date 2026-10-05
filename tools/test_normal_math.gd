@tool
extends SceneTree

func _init() -> void:
	# Quad facing +X (Right)
	# p0 = (1, 0, 0), p1 = (1, 1, 0), p2 = (1, 1, 1), p3 = (1, 0, 1)
	var p0 := Vector3(1, 0, 0)
	var p1 := Vector3(1, 1, 0)
	var p2 := Vector3(1, 1, 1)
	var p3 := Vector3(1, 0, 1)
	
	# Normal calculation
	var n1 := (p1 - p0).cross(p2 - p0)
	print("p0->p1->p2 cross: ", n1, " dot(RIGHT): ", n1.dot(Vector3.RIGHT))
	
	# If negative, reversed: p0, p3, p2, p1
	var n_rev := (p3 - p0).cross(p2 - p0)
	print("Reversed p0->p3->p2 cross: ", n_rev, " dot(RIGHT): ", n_rev.dot(Vector3.RIGHT))
	quit()
