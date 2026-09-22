extends SceneTree

const WildRose = preload("res://world/vegetation/rose/wild_rose.gd")

func _init() -> void:
	var single_mesh = WildRose.create_single_rose_mesh(12345, 1.0, WildRose.COLOR_CRIMSON)
	var cluster_mesh = WildRose.create_rose_cluster_mesh(54321, 1.0, WildRose.COLOR_CRIMSON)
	
	var single_faces = single_mesh.get_faces().size() / 3
	var cluster_faces = cluster_mesh.get_faces().size() / 3
	
	print("✓ Single Rose Triangles: %d" % single_faces)
	print("✓ Rose Cluster Triangles: %d" % cluster_faces)
	quit(0)
