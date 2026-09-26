extends SceneTree

func _init() -> void:
	var fbx_scene: PackedScene = load("res://PSX_Forest_AssetCollection_byStarkCrafts.fbx")
	var fbx = fbx_scene.instantiate()
	
	for name in ["PSX_Tree1", "PSX_Tree2", "PSX_Tree3", "PSX_Tree4"]:
		var node = fbx.get_node(name) as MeshInstance3D
		var m = node.mesh
		print("=== %s ===" % name)
		for s in range(m.get_surface_count()):
			var mat = m.surface_get_material(s)
			var arr = m.surface_get_arrays(s)
			var indices = arr[Mesh.ARRAY_INDEX]
			var verts = arr[Mesh.ARRAY_VERTEX]
			var tris = indices.size() / 3 if indices != null else verts.size() / 3
			var tex_name = mat.albedo_texture.resource_path.get_file() if (mat and mat.albedo_texture) else "none"
			print("  Surf %d: tris=%d, verts=%d, mat=%s, tex=%s, cull=%s" % [
				s, tris, verts.size(),
				mat.resource_name if mat else "none",
				tex_name,
				mat.cull_mode if mat else -1
			])
	fbx.free()
	quit(0)
