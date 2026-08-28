extends RefCounted
class_name CatModelUtils
## Carga el modelo real del gato (assets/cat/cat.fbx) y lo agrega como hijo
## "Model" del mob.
##
## El gato solo tiene UNA animacion ("walk") en su AnimationPlayer, a
## diferencia del perro que tiene varias. build_model() lo carga, aplica la
## textura catskin.png, lo rota 180 grados (el hocico apunta a +Z, verificado
## via huesos: patas delanteras en Z=+2.25, traseras en Z=-1.13 - hay que
## rotarlo para que mire a -Z, la direccion de avance de Godot), lo escala/
## reposiciona segun su AABB real y lo agrega como hijo "Model".

const CAT_MODEL_PATH := "res://assets/cat/cat.fbx"
const CAT_TEXTURE_PATH := "res://assets/cat/catskin.png"
const CAT_TARGET_HEIGHT := 0.9 # altura aproximada real de un gato, en metros


## Carga el modelo del gato, lo agrega como hijo de `parent` (nombrado
## "Model") y lo normaliza de tamano/posicion segun su AABB real.
static func build_model(parent: Node3D) -> void:
	var model_scene: PackedScene = load(CAT_MODEL_PATH) as PackedScene
	if model_scene == null:
		push_warning("[cat] No se pudo cargar %s." % CAT_MODEL_PATH)
		return

	var instanced: Node = model_scene.instantiate()
	if not (instanced is Node3D):
		push_warning("[cat] La raiz de %s no es un Node3D (es %s)." % [CAT_MODEL_PATH, instanced.get_class()])
		instanced.free()
		return

	var model: Node3D = instanced
	model.name = "Model"
	parent.add_child(model)

	# Se le asigna un material propio (textura catskin.png) a cada superficie,
	# con el culling desactivado por si las normales vinieran invertidas por
	# la conversion de ejes Blender (Z-up) -> Godot (Y-up).
	_apply_material(model)
	_force_visible(model)
	_normalize_scale(model)

	# El hocico del gato apunta a +Z (verificado via huesos). Godot usa -Z
	# como direccion de avance, asi que se rota 180 grados en Y.
	model.rotation.y = PI


## Escala `model` (ya agregado al arbol) para que su altura real (AABB) sea
## CAT_TARGET_HEIGHT, y lo reposiciona en Y para que la parte mas baja quede
## en y=0 (apoyado en el suelo).
static func _normalize_scale(model: Node3D) -> void:
	var aabb := _combined_aabb_local(model)
	print("[cat] AABB local de %s = %s" % [model.name, aabb])
	if aabb.size.y <= 0.0001:
		push_warning("[cat] El modelo no tiene mallas visibles (AABB vacio), no se pudo normalizar escala.")
		return

	var scale_factor: float = CAT_TARGET_HEIGHT / aabb.size.y
	if scale_factor <= 0.0 or not is_finite(scale_factor):
		push_warning("[cat] scale_factor invalido (%s), se deja el modelo sin escalar." % scale_factor)
		return
	print("[cat] scale_factor aplicado = %.5f" % scale_factor)
	model.scale = Vector3.ONE * scale_factor
	model.position.y -= aabb.position.y * scale_factor


## Recorre `node` y le asigna un material propio (con textura catskin.png y
## culling desactivado) a cada superficie de cada MeshInstance3D.
static func _apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				mesh_instance.set_surface_override_material(i, _build_cat_material())
	for child in node.get_children():
		_apply_material(child)


## Construye un StandardMaterial3D nuevo con la textura del gato y el culling
## desactivado.
static func _build_cat_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var texture := load(CAT_TEXTURE_PATH) as Texture2D
	if texture != null:
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # look PSX
	else:
		push_warning("[cat] No se pudo cargar la textura %s." % CAT_TEXTURE_PATH)
		material.albedo_color = Color(0.85, 0.75, 0.6)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Fuerza `visible = true` en todo el arbol - por si el .fbx trae algun nodo
## oculto por error.
static func _force_visible(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_force_visible(child)


## Calcula el AABB combinado de todas las mallas visibles dentro de `model`,
## expresado en el espacio local de `model`.
static func _combined_aabb_local(model: Node3D) -> AABB:
	var inv := model.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	var instances := _find_visual_instances(model)
	print("[cat] %d VisualInstance3D encontrados dentro de %s" % [instances.size(), model.name])
	for vi in instances:
		var xform: Transform3D = inv * vi.global_transform
		var local_aabb: AABB = xform * vi.get_aabb()
		if first:
			result = local_aabb
			first = false
		else:
			result = result.merge(local_aabb)
	return result


static func _find_visual_instances(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found += _find_visual_instances(child)
	return found
