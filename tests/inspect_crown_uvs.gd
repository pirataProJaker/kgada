@tool
extends SceneTree

func _init() -> void:
	var fbx_scene: PackedScene = load("res://PSX_Forest_AssetCollection_byStarkCrafts.fbx")
	var fbx = fbx_scene.instantiate()
	var tree4: MeshInstance3D = fbx.get_node("PSX_Tree4") as MeshInstance3D
	var orig_mesh: Mesh = tree4.mesh
	var node_t: Transform3D = tree4.transform
	var center_offset = Vector3(tree4.position.x, 0.0, tree4.position.z)
	var local_t = Transform3D(node_t.basis, node_t.origin - center_offset)
	
	var arr = orig_mesh.surface_get_arrays(0) # Surface 0: Crown
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	
	print("--- ORIGINAL CROWN (Surface 0) VERTICES & UVS ---")
	print("Vertex count: %d, Index count: %d" % [verts.size(), indices.size()])
	for i in range(verts.size()):
		var world_v = local_t * verts[i]
		print("V[%d]: pos=(%.3f, %.3f, %.3f), uv=(%.3f, %.3f)" % [i, world_v.x, world_v.y, world_v.z, uvs[i].x, uvs[i].y])
		
	print("\nTriangles (Indices):")
	for t in range(indices.size() / 3):
		var i0 = indices[t * 3 + 0]
		var i1 = indices[t * 3 + 1]
		var i2 = indices[t * 3 + 2]
		print("Tri %d: [%d, %d, %d]" % [t, i0, i1, i2])
		
	fbx.free()
	quit(0)
