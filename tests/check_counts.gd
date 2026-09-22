extends SceneTree

func _init() -> void:
	var gen = load("res://world/procedural_flora/procedural_flower_generator.gd")
	var res = gen.generate_flower("shrub_rose", 12345, 1.0, 1)
	var m = res.mesh
	print("Surfaces: ", m.get_surface_count())
	for s in range(m.get_surface_count()):
		var arr = m.surface_get_arrays(s)
		var v_count = arr[Mesh.ARRAY_VERTEX].size()
		var i_count = arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else 0
		print("Surf %d: %d verts, %d indices, %d tris" % [s, v_count, i_count, (i_count / 3 if i_count > 0 else v_count / 3)])
	quit(0)
