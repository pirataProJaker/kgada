extends SceneTree

func _init() -> void:
	print("--- Testing Unit Rounded Box Generation ---")
	var ObjectPrimitivesScript = load("res://world/object_engine/object_primitives.gd")
	var mesh = ObjectPrimitivesScript.get_mesh("rounded_box")
	if mesh != null:
		print("SUCCESS: rounded_box mesh generated!")
		print("Surfaces count: ", mesh.get_surface_count())
		var arrays = mesh.surface_get_arrays(0)
		var verts = arrays[Mesh.ARRAY_VERTEX]
		print("Total vertices: ", verts.size())
	else:
		print("FAIL: rounded_box mesh is null")
	quit()
