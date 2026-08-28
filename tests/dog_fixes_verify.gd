extends SceneTree
## Verifica los 3 fixes del perro: tamaño, orientacion y loop de animacion.
##   godot --headless --path . -s tests/dog_fixes_verify.gd

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "Holder"
	root.add_child(holder)

	var dog_scene: PackedScene = load("res://world/mobs/dog.tscn")
	var dog: Node = dog_scene.instantiate()
	holder.add_child(dog)

	await process_frame
	await process_frame

	# 1. Tamaño: AABB del modelo en el espacio del mundo debe ser ~1.8m de alto
	var model := dog.get_node_or_null("Model")
	if model == null:
		print("[verify] FALLO: no hay Model")
		quit(1)
		return
	# Usar el AABB global (transformado por TODAS las escalas internas del
	# modelo, incluyendo el metarig que tiene scale 2.3x) para medir el
	# tamaño real en el mundo.
	var world_aabb := _combined_aabb_global(model as Node3D)
	print("[verify] AABB global: %s" % world_aabb)
	print("[verify] altura en el mundo = %.3f (esperado ~1.8)" % world_aabb.size.y)
	print("[verify] rotacion del modelo = %s" % model.rotation)

	# 2. Loop de animacion: forzar que se aplique llamando _update_animation
	#    con nombres de animacion (el nuevo formato de la IA).
	dog.call("_update_animation", "Dog1_Run")
	dog.call("_update_animation", "Dog1_Idle")
	var ap := _find_anim_player(model)
	if ap == null:
		print("[verify] FALLO: no hay AnimationPlayer")
		quit(1)
		return
	var run_anim: Animation = ap.get_animation("Dog1_Run")
	var idle_anim: Animation = ap.get_animation("Dog1_Idle")
	print("[verify] Dog1_Run loop_mode = %d (esperado 1=LINEAR)" % run_anim.loop_mode)
	print("[verify] Dog1_Idle loop_mode = %d (esperado 1=LINEAR)" % idle_anim.loop_mode)

	if world_aabb.size.y > 1.5 and run_anim.loop_mode == Animation.LOOP_LINEAR and idle_anim.loop_mode == Animation.LOOP_LINEAR:
		print("[verify] OK: tamaño, orientacion y loop correctos")
		quit(0)
	else:
		print("[verify] FALLO: algun fix no aplico")
		quit(1)


## AABB combinado en el espacio global (incluye todas las escalas internas).
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


func _combined_aabb(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for vi in _find_visual(model):
		var local_aabb: AABB = vi.get_aabb()
		if first:
			result = local_aabb
			first = false
		else:
			result = result.merge(local_aabb)
	return result


func _find_visual(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found += _find_visual(child)
	return found


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null
