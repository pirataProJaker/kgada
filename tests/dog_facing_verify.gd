extends SceneTree
## Verifica la orientacion real del hocico del perro midiendo la posicion
## global de las orejas (cabeza) vs la pelvis (cola) en el espacio del mundo.
##   godot --headless --path . -s tests/dog_facing_verify.gd

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "Holder"
	root.add_child(holder)

	var dog_scene: PackedScene = load("res://world/mobs/dog.tscn")
	var dog: Node = dog_scene.instantiate()
	holder.add_child(dog)
	await process_frame
	await process_frame

	var model := dog.get_node_or_null("Model")
	if model == null:
		print("[verify] FALLO: no hay Model")
		quit(1)
		return

	var sk := _find_skeleton(model)
	if sk == null:
		print("[verify] FALLO: no hay Skeleton3D")
		quit(1)
		return

	# Posicion global de las orejas (cabeza) y la pelvis (cola)
	var ear_l := _bone_global(sk, "ear.L")
	var ear_r := _bone_global(sk, "ear.R")
	var pelvis := _bone_global(sk, "pelvis.L")
	var head_z := (ear_l.z + ear_r.z) * 0.5
	var tail_z := pelvis.z
	print("[verify] cabeza (orejas) Z global = %.3f" % head_z)
	print("[verify] cola (pelvis) Z global = %.3f" % tail_z)
	print("[verify] rotacion del modelo = %s" % model.rotation)

	# Si la cabeza esta en -Z (menor que la cola), el perro mira hacia -Z
	# (direccion de avance de Godot) = correcto.
	if head_z < tail_z:
		print("[verify] OK: el hocico apunta hacia -Z (correcto)")
		quit(0)
	else:
		print("[verify] FALLO: el hocico apunta hacia +Z (al reves)")
		quit(1)


func _bone_global(sk: Skeleton3D, bone_name: String) -> Vector3:
	var idx := sk.find_bone(bone_name)
	if idx == -1:
		return Vector3.ZERO
	return sk.to_global(sk.get_bone_global_pose(idx).origin)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
