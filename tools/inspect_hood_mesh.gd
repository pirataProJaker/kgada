@tool
extends SceneTree

func _init() -> void:
	var hood_mesh := CarMeshBuilder.create_hood_mesh()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(hood_mesh, 0)
	print("Hood vertex count: ", mdt.get_vertex_count())
	print("Hood face count: ", mdt.get_face_count())
	for i in range(mdt.get_vertex_count()):
		print("V%2d: pos=%s uv=%s col=%s norm=%s" % [
			i, mdt.get_vertex(i), mdt.get_vertex_uv(i), mdt.get_vertex_color(i), mdt.get_vertex_normal(i)
		])
	for f in range(mdt.get_face_count()):
		print("F%2d: (%d, %d, %d) face_norm=%s" % [
			f, mdt.get_face_vertex(f, 0), mdt.get_face_vertex(f, 1), mdt.get_face_vertex(f, 2), mdt.get_face_normal(f)
		])
	quit()
