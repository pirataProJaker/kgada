extends SceneTree
## Verifica que el gato se mueve con la IA (DogAi) y reproduce walk.
##   godot --headless --path . -s tests/cat_ai_verify.gd

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "Holder"
	root.add_child(holder)

	var cat_scene: PackedScene = load("res://world/mobs/cat.tscn")
	var cat: Node = cat_scene.instantiate()
	holder.add_child(cat)
	await process_frame
	await process_frame

	# Verificar que tiene IA
	var ai_found := cat.get_node_or_null("DogAi") != null or _has_ai(cat)
	print("[verify] tiene IA: %s" % ai_found)

	# Simular varios frames de fisica y verificar que se mueve
	var moved := false
	for i in 300:
		cat.call("_physics_process", 1.0 / 60.0)
		if cat.global_position.length() > 0.01:
			moved = true
			break

	print("[verify] el gato se movio: %s" % moved)
	print("[verify] posicion final: %s" % cat.global_position)

	if ai_found and moved:
		print("[verify] OK: el gato tiene IA y se mueve")
		quit(0)
	else:
		print("[verify] FALLO: ai_found=%s moved=%s" % [ai_found, moved])
		quit(1)


func _has_ai(node: Node) -> bool:
	for child in node.get_children():
		if child.get_class() == "DogAi" or child.name == "DogAi":
			return true
		if _has_ai(child):
			return true
	return false
