@tool
extends SceneTree

func _init() -> void:
	var tree = BotanicalTreeView.new()
	tree.species_id = "alnus_acuminata"
	tree.tree_seed = 12345
	tree.age = 1.0
	tree.foliage_mode = 2 # LushBranchBoughs
	root.add_child(tree)
	
	print("========================================")
	print("REPORTE DE TRIÁNGULOS BOTANICAL TREE (LushBranchBoughs)")
	print("========================================")
	for lod in range(4):
		var mesh: ArrayMesh = tree._rust_tree.get_lod_mesh(lod)
		var wood_tris := 0
		var leaf_tris := 0
		if mesh:
			if mesh.get_surface_count() > 0:
				wood_tris = mesh.surface_get_array_index_len(0) / 3
			if mesh.get_surface_count() > 1:
				leaf_tris = mesh.surface_get_array_index_len(1) / 3
		var total = wood_tris + leaf_tris
		print("LOD %d: Madera=%d tris, Follaje=%d tris -> TOTAL = %d tris" % [lod, wood_tris, leaf_tris, total])
	print("========================================")
	quit()
