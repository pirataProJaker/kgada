extends SceneTree

func _init() -> void:
	var bm := BoxMesh.new()
	var arr := bm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	
	print("Total vertices in BoxMesh: ", verts.size())
	for i in range(verts.size()):
		# Look for top face vertices where normal.y > 0.9
		if normals[i].y > 0.9:
			print("Top face vert: pos=(%0.2f, %0.2f, %0.2f) -> UV=(%0.2f, %0.2f)" % [
				verts[i].x, verts[i].y, verts[i].z, uvs[i].x, uvs[i].y
			])
	quit(0)
