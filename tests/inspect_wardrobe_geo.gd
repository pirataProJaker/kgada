extends SceneTree

func _init() -> void:
	var m = FurniturePropsBuilder.load_obj_mesh("wardrobe_oak.obj")
	if m:
		var aabb = m.get_aabb()
		print("Wardrobe full mesh AABB: pos=", aabb.position, " size=", aabb.size, " end=", aabb.end)
	var body_m = FurniturePropsBuilder.get_wardrobe_body_mesh()
	if body_m:
		var aabb = body_m.get_aabb()
		print("Wardrobe body mesh AABB: pos=", aabb.position, " size=", aabb.size, " end=", aabb.end)
	quit(0)
