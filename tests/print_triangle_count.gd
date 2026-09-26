@tool
extends SceneTree

func _init() -> void:
	var tree = BotanicalTreeView.new()
	tree.species_id = "alnus_acuminata"
	tree.tree_seed = 12345
	tree.age = 1.0
	tree.forced_lod = 0
	root.add_child(tree)
	tree.refresh()
	var mesh = tree._mesh_instance.mesh
	var total_tris = 0
	if mesh:
		for s in range(mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(s)
			var indices = arrays[Mesh.ARRAY_INDEX]
			var tris = indices.size() / 3
			var name = "Madera (Wood)" if s == 0 else "Follaje (Leaves)"
			print("Surface ", s, " [", name, "]: ", tris, " triangulos")
			total_tris += tris
	print(">>> TOTAL TRIANGULOS ARBOL (LOD 0): ", total_tris)
	for lod in [1, 2, 3]:
		print(">>> TOTAL TRIANGULOS LOD ", lod, ": ", tree.get_total_triangles(lod))
	quit()
