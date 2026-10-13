extends SceneTree

func _init() -> void:
	print("--- Testing Box-Projected Side Wall UVs on Rounded Box ---")
	var ObjectPrimitivesScript = load("res://world/object_engine/object_primitives.gd")
	var mesh = ObjectPrimitivesScript.get_mesh("rounded_box")
	var arrays = mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	
	# Find vertices near front face (z > 0.45) on side walls
	for i in range(verts.size()):
		var v = verts[i]
		if abs(v.y) < 0.49 and v.z > 0.48:
			print("Front side vertex: pos=", v, " uv=", uvs[i])
	quit()
