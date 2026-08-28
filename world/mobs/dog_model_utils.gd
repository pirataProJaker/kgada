extends RefCounted
class_name DogModelUtils
## El .fbx y el .glb del perro (assets/dog/, descargado de
## mcsteeg.itch.io/psx-dog) fallan al importar en Godot 4.7 - el propio
## archivo .import queda con `valid=false` para AMBOS formatos (confirmado
## via consola, no es un problema de escala/configuracion nuestro).
##
## Se reemplazo por un modelo de gato (assets/cat/cat.fbx) que si importa
## correctamente. build_model() lo carga, lo escala/reposiciona con base en
## su AABB real (no sabemos de antemano en que unidades vino exportado) y
## lo agrega como hijo "Model". Si por algun motivo el .fbx del gato tambien
## fallara en cargar, se usa como respaldo el perro de bloques simples
## construido en codigo (build_placeholder_model) para que /summon y
## /give egg:dog nunca se queden sin nada visible.

const BODY_COLOR := Color(0.12, 0.09, 0.07) # cafe muy oscuro/negro, como "BlackDog"
const LEG_SIZE := Vector3(0.09, 0.32, 0.09)

const CAT_MODEL_PATH := "res://assets/cat/cat.fbx"
const CAT_TEXTURE_PATH := "res://assets/cat/catskin.png"
const CAT_TARGET_HEIGHT := 0.32 # altura aproximada real de un gato, en metros


## Carga el modelo del gato, lo agrega como hijo de `parent` (nombrado
## "Model") y lo normaliza de tamano/posicion segun su AABB real. Si el .fbx
## no se puede cargar, agrega el perro de bloques de respaldo en su lugar.
static func build_model(parent: Node3D) -> void:
	var model_scene: PackedScene = load(CAT_MODEL_PATH) as PackedScene
	if model_scene == null:
		push_warning("[mob] No se pudo cargar %s, usando modelo de bloques de respaldo." % CAT_MODEL_PATH)
		parent.add_child(build_placeholder_model())
		return

	var instanced: Node = model_scene.instantiate()
	if not (instanced is Node3D):
		push_warning("[mob] La raiz de %s no es un Node3D (es %s), usando modelo de bloques de respaldo." % [CAT_MODEL_PATH, instanced.get_class()])
		instanced.free()
		parent.add_child(build_placeholder_model())
		return

	var model: Node3D = instanced
	model.name = "Model"
	parent.add_child(model)

	# La consola de Godot mostro errores "material_casts_shadows: Parameter
	# material is null" para cada instancia - la malla del gato viene SIN
	# material asignado (el .fbx no trae uno, o el que trae no se pudo
	# extraer), lo que la deja invisible aunque el AABB/escala esten bien.
	# Se le asigna un material propio (textura catskin.png) a cada superficie,
	# con el culling desactivado por si ademas las normales vinieran
	# invertidas por la conversion de ejes Blender (Z-up) -> Godot (Y-up).
	_apply_material(model)
	_force_visible(model)
	_normalize_scale(model)


## Escala `model` (ya agregado al arbol) para que su altura real (AABB) sea
## CAT_TARGET_HEIGHT, y lo reposiciona en Y para que la parte mas baja
## quede en y=0 (apoyado en el suelo).
static func _normalize_scale(model: Node3D) -> void:
	var aabb := _combined_aabb_local(model)
	print("[mob] AABB local de %s = %s" % [model.name, aabb])
	if aabb.size.y <= 0.0001:
		push_warning("[mob] El modelo no tiene mallas visibles (AABB vacio), no se pudo normalizar escala.")
		return

	var scale_factor: float = CAT_TARGET_HEIGHT / aabb.size.y
	if scale_factor <= 0.0 or not is_finite(scale_factor):
		push_warning("[mob] scale_factor invalido (%s), se deja el modelo sin escalar." % scale_factor)
		return
	print("[mob] scale_factor aplicado = %.5f" % scale_factor)
	model.scale = Vector3.ONE * scale_factor
	model.position.y -= aabb.position.y * scale_factor


## Recorre `node` y le asigna un material propio (con textura catskin.png
## y culling desactivado) a cada superficie de cada MeshInstance3D - no
## depende de que la malla ya traiga un material asignado, que es
## justamente lo que le faltaba (ver comentario en build_model).
static func _apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				mesh_instance.set_surface_override_material(i, _build_cat_material())
	for child in node.get_children():
		_apply_material(child)


## Construye un StandardMaterial3D nuevo con la textura del gato y el
## culling desactivado. Se crea uno nuevo por superficie (en vez de
## compartir una sola instancia) para evitar sorpresas si en el futuro se
## quiere tintar/animar el material de un gato en particular.
static func _build_cat_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var texture := load(CAT_TEXTURE_PATH) as Texture2D
	if texture != null:
		material.albedo_texture = texture
	else:
		push_warning("[mob] No se pudo cargar la textura %s." % CAT_TEXTURE_PATH)
		material.albedo_color = Color(0.85, 0.75, 0.6)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Fuerza `visible = true` en todo el arbol - por si el .fbx trae algun nodo
## oculto por error (algunos exportadores marcan "helper"/proxy meshes como
## invisibles pero Godot los importa igual).
static func _force_visible(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_force_visible(child)


## Calcula el AABB combinado de todas las mallas visibles dentro de `model`,
## expresado en el espacio local de `model` (independiente de donde este
## posicionado en el mundo).
static func _combined_aabb_local(model: Node3D) -> AABB:
	var inv := model.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	var instances := _find_visual_instances(model)
	print("[mob] %d VisualInstance3D encontrados dentro de %s" % [instances.size(), model.name])
	for vi in instances:
		print("[mob]   - %s (%s) visible=%s" % [vi.get_path(), vi.get_class(), vi.visible])
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


## Perro de bloques simples (BoxMesh) usado unicamente como respaldo si el
## modelo real del gato no se pudiera cargar - encaja con el estilo
## PSX/low-poly del resto del juego y no depende de ningun archivo externo.
static func build_placeholder_model() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"

	var material := StandardMaterial3D.new()
	material.albedo_color = BODY_COLOR

	_add_box(root, "Body", Vector3(0.28, 0.22, 0.55), Vector3(0.0, 0.32, 0.0), material)
	_add_box(root, "Head", Vector3(0.22, 0.2, 0.22), Vector3(0.0, 0.42, 0.32), material)
	_add_box(root, "Snout", Vector3(0.12, 0.1, 0.14), Vector3(0.0, 0.38, 0.44), material)
	_add_box(root, "EarL", Vector3(0.05, 0.1, 0.05), Vector3(0.08, 0.53, 0.28), material)
	_add_box(root, "EarR", Vector3(0.05, 0.1, 0.05), Vector3(-0.08, 0.53, 0.28), material)
	_add_box(root, "Tail", Vector3(0.06, 0.06, 0.28), Vector3(0.0, 0.4, -0.32), material)
	_add_box(root, "LegFL", LEG_SIZE, Vector3(0.1, 0.16, 0.2), material)
	_add_box(root, "LegFR", LEG_SIZE, Vector3(-0.1, 0.16, 0.2), material)
	_add_box(root, "LegBL", LEG_SIZE, Vector3(0.1, 0.16, -0.2), material)
	_add_box(root, "LegBR", LEG_SIZE, Vector3(-0.1, 0.16, -0.2), material)

	return root


static func _add_box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)

