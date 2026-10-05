@tool
extends SceneTree

func _init() -> void:
	var euler := Vector3(deg_to_rad(-35.0), deg_to_rad(135.0), 0.0)
	var basis := Basis.from_euler(euler)
	var forward := -basis.z
	print("Light shining towards: ", forward)
	print("Hits left side (+X)? ", forward.dot(Vector3.RIGHT) < 0.0)
	print("Hits front (-Z)? ", forward.dot(Vector3.FORWARD) > 0.0)
	print("Hits hood (+Y)? ", forward.dot(Vector3.UP) < 0.0)
	quit()
