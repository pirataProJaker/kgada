extends SceneTree

func _init() -> void:
	var ProceduralFlower = load("res://world/procedural_flora/procedural_flower.gd")
	var shrub = ProceduralFlower.new()
	shrub.profile_id = "shrub_rose"
	shrub.growth_progress = 1.0
	shrub.flower_seed = 12345
	shrub.generate()
	var mesh = shrub.get_mesh()
	print("SHRUB SURFACES: ", mesh.get_surface_count())
	var total_shrub = 0
	for s in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(s)
		var verts: int = arrays[Mesh.ARRAY_VERTEX].size()
		var tris: int = 0
		if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
			tris = arrays[Mesh.ARRAY_INDEX].size() / 3
		else:
			tris = verts / 3
		print("  Surface %d: verts=%d, tris=%d" % [s, verts, tris])
		total_shrub += tris
	print("TOTAL SHRUB TRIS: ", total_shrub)

	var sol = ProceduralFlower.new()
	sol.profile_id = "solitary_rose"
	sol.growth_progress = 1.0
	sol.flower_seed = 12345
	sol.generate()
	var m_sol = sol.get_mesh()
	var total_sol = 0
	for s in range(m_sol.get_surface_count()):
		var arrays = m_sol.surface_get_arrays(s)
		var verts: int = arrays[Mesh.ARRAY_VERTEX].size()
		var tris: int = 0
		if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
			tris = arrays[Mesh.ARRAY_INDEX].size() / 3
		else:
			tris = verts / 3
		print("  Solitary Surface %d: verts=%d, tris=%d" % [s, verts, tris])
		total_sol += tris
	print("TOTAL SOLITARY TRIS: ", total_sol)
	quit(0)
