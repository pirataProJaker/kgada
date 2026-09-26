@tool
extends SceneTree

func _init() -> void:
	var tree = BotanicalTreeView.new()
	tree.species_id = "alnus_acuminata"
	tree.tree_seed = 12345
	tree.age = 1.0
	tree.foliage_mode = 2
	root.add_child(tree)
	
	# Let's inspect the graph
	var node_count = tree._rust_tree.get_node_count()
	print("Total nodes in graph: ", node_count)
	
	# Let's inspect LOD 0 mesh surface info
	var mesh: ArrayMesh = tree._rust_tree.get_lod_mesh(0)
	if mesh:
		print("Surfaces: ", mesh.get_surface_count())
		for s in range(mesh.get_surface_count()):
			print("Surface ", s, ": ", mesh.surface_get_array_index_len(s) / 3, " triangles, ", mesh.surface_get_array_len(s), " vertices")
	quit()
