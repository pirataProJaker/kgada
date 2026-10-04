extends SceneTree

func _init() -> void:
	var mesh: ArrayMesh = WardrobeOak.get_shared_mesh()
	print("WardrobeOak shared mesh AABB: ", mesh.get_aabb())
	var aabb = mesh.get_aabb()
	print("X min: %.4f, max: %.4f, size: %.4f" % [aabb.position.x, aabb.position.x + aabb.size.x, aabb.size.x])
	print("Y min: %.4f, max: %.4f, size: %.4f" % [aabb.position.y, aabb.position.y + aabb.size.y, aabb.size.y])
	print("Z min: %.4f, max: %.4f, size: %.4f" % [aabb.position.z, aabb.position.z + aabb.size.z, aabb.size.z])
	quit(0)
