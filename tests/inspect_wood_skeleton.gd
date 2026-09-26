@tool
extends SceneTree

func _init() -> void:
	var tree = BotanicalTreeView.new()
	tree.species_id = "alnus_acuminata"
	tree.tree_seed = 12345
	tree.age = 1.0
	tree.foliage_mode = 2
	
	# Let's count active segments by depth in the graph
	var d0 := 0
	var d1 := 0
	var d2 := 0
	
	var nodes_count = 0
	# We can check by inspecting how many segments get added
	print("Checking procedural segments...")
	
	# Let's inspect LOD 0 mesh
	var mesh: ArrayMesh = tree._rust_tree.get_lod_mesh(0)
	print("Surfaces: ", mesh.get_surface_count())
	print("Surface 0 tris (wood): ", mesh.surface_get_array_index_len(0) / 3)
	print("Surface 1 tris (leaves): ", mesh.surface_get_array_index_len(1) / 3)
	quit()
