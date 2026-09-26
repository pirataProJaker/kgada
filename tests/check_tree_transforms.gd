@tool
extends SceneTree

func _init() -> void:
	var path := "res://PSX_Forest_AssetCollection_byStarkCrafts.fbx"
	var scene: PackedScene = load(path)
	var inst: Node = scene.instantiate()
	for child in inst.get_children():
		if child is Node3D:
			print("Node: %s | Pos: %s | Rot: %s | Scale: %s" % [
				child.name, child.position, child.rotation_degrees, child.scale
			])
			if child is MeshInstance3D and child.mesh:
				var aabb = child.mesh.get_aabb()
				print("    Mesh AABB: size=%s, min=%s, max=%s" % [aabb.size, aabb.position, aabb.end])
	inst.free()
	quit(0)
