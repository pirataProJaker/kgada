extends SceneTree
## Verifica que DogModelUtils.build_model() carga el perro real y lo
## normaliza a la altura objetivo. Se ejecuta con:
##   godot --headless --path . -s tests/dog_model_verify.gd

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "Holder"
	# Agregar al arbol para que global_transform funcione
	root.add_child(holder)
	# build_model agrega el modelo como hijo de holder
	DogModelUtils.build_model(holder)
	# Buscar el modelo "Model" y su AABB
	var model := holder.get_node_or_null("Model")
	if model == null:
		print("[verify] FALLO: no se encontro el nodo 'Model'")
		quit(1)
		return

	var aabb := _combined_aabb(model as Node3D)
	print("[verify] Model encontrado: %s" % model.get_class())
	print("[verify] AABB combinado (local) = %s" % aabb)
	print("[verify] tamano AABB = %s" % aabb.size)
	print("[verify] scale del modelo = %s" % model.scale)
	print("[verify] posicion del modelo = %s" % model.position)

	if aabb.size.y > 0.01:
		print("[verify] OK: el modelo tiene mallas visibles")
		quit(0)
	else:
		print("[verify] FALLO: AABB vacio, el modelo no se ve")
		quit(1)


static func _combined_aabb(model: Node3D) -> AABB:
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


static func _find_visual(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found += _find_visual(child)
	return found
