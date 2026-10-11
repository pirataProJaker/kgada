@tool
extends SceneTree

const ObjectPrimitivesScript = preload("res://world/object_engine/object_primitives.gd")

func _init() -> void:
	for prim in ["cube", "cylinder", "wedge", "quad", "sphere", "capsule"]:
		var mesh = ObjectPrimitivesScript.get_mesh(prim)
		if mesh:
			var faces = mesh.get_faces()
			print("%-10s: %3d faces, %3d triangles" % [prim, faces.size(), faces.size() / 3])
	quit(0)
