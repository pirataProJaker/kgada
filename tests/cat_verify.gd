extends SceneTree
## Verifica que el gato se carga, tiene el tamaño correcto, la orientacion
## correcta y la animacion walk.
##   godot --headless --path . -s tests/cat_verify.gd

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "Holder"
	root.add_child(holder)

	var cat_scene: PackedScene = load("res://world/mobs/cat.tscn")
	if cat_scene == null:
		print("[verify] FALLO: no se pudo cargar cat.tscn")
		quit(1)
		return
	var cat: Node = cat_scene.instantiate()
	holder.add_child(cat)
	await process_frame
	await process_frame

	var model := cat.get_node_or_null("Model")
	if model == null:
		print("[verify] FALLO: no hay Model")
		quit(1)
		return

	# Tamaño (AABB global)
	var world_aabb := _combined_aabb_global(model as Node3D)
	print("[verify] AABB global: %s" % world_aabb)
	print("[verify] altura en el mundo = %.3f (esperado ~0.9)" % world_aabb.size.y)
	print("[verify] rotacion del modelo = %s (esperado y=PI)" % model.rotation)

	# Orientacion: hocico debe apuntar a -Z
	var sk := _find_skeleton(model)
	var front_z := 0.0
	var back_z := 0.0
	if sk != null:
		front_z = (_bone_global(sk, "Bone.007.L").z + _bone_global(sk, "Bone.007.R").z) * 0.5
		back_z = (_bone_global(sk, "Bone.010.L").z + _bone_global(sk, "Bone.010.R").z) * 0.5
	print("[verify] patas delanteras Z = %.3f, traseras Z = %.3f" % [front_z, back_z])

	# Animacion walk
	var ap := _find_anim_player(model)
	var has_walk := false
	if ap != null:
		has_walk = ap.has_animation("walk")
		print("[verify] animaciones: %s" % ap.get_animation_list())
	print("[verify] tiene animacion walk: %s" % has_walk)

	var facing_ok := front_z < back_z
	if world_aabb.size.y > 0.5 and facing_ok and has_walk:
		print("[verify] OK: gato cargado, tamaño, orientacion y animacion correctos")
		quit(0)
	else:
		print("[verify] FALLO: tamaño=%.2f facing_ok=%s has_walk=%s" % [world_aabb.size.y, facing_ok, has_walk])
		quit(1)


func _combined_aabb_global(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for vi in _find_visual(model):
		var global_aabb: AABB = vi.global_transform * vi.get_aabb()
		if first:
			result = global_aabb
			first = false
		else:
			result = result.merge(global_aabb)
	return result


func _find_visual(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found += _find_visual(child)
	return found


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null


func _bone_global(sk: Skeleton3D, bone_name: String) -> Vector3:
	var idx := sk.find_bone(bone_name)
	if idx == -1:
		return Vector3.ZERO
	return sk.to_global(sk.get_bone_global_pose(idx).origin)
