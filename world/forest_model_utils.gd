extends RefCounted
class_name ForestModelUtils
## Utilidades para usar los modelos del FBX de la coleccion del bosque
## (assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts.fbx). El FBX
## contiene varios modelos en un solo archivo (roca, hierba, diente de leon,
## lavanda, junco, pina, arboles, tronco). Este helper instancia el FBX y
## extrae un modelo por nombre como un nodo independiente.

const FOREST_FBX_PATH := "res://assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts.fbx"

# Nombres de los modelos disponibles en el FBX
const MODEL_ROCK := "PSX_Rock"
const MODEL_GRASS := "PSX_Grass"
const MODEL_DANDELION := "PSX_Dandelion"
const MODEL_LAVENDER := "PSX_Lavender "
const MODEL_REED := "PSX_Reed"
const MODEL_PINECONE := "PSX_PineConre"
const MODEL_TREE1 := "PSX_Tree1"
const MODEL_TREE2 := "PSX_Tree2"
const MODEL_TREE3 := "PSX_Tree3"
const MODEL_TREE4 := "PSX_Tree4"
const MODEL_TREETRUNK := "PSX_Treetrunk"

var _fbx_scene: PackedScene = null
# Cache de meshes extraidos: model_name -> {mesh, transform}. Se extrae el
# mesh del FBX una sola vez y se reutiliza en cada instancia (optimizacion:
# no re-instanciar el FBX completo en cada llamada del scatter).
var _mesh_cache: Dictionary = {}


func _init() -> void:
	if ResourceLoader.exists(FOREST_FBX_PATH):
		_fbx_scene = load(FOREST_FBX_PATH) as PackedScene


## Devuelve un nodo con un solo modelo del FBX (por nombre), o null si no
## existe. El nodo devuelto es un Node3D con el MeshInstance3D del modelo.
## El modelo se escala para que su altura real sea `target_height` (porque
## el FBX viene con scale=100 y rotacion de 90 grados de Blender).
func get_model(model_name: String, target_height: float = 1.0) -> Node3D:
	if _fbx_scene == null:
		push_warning("[forest] No se pudo cargar el FBX %s" % FOREST_FBX_PATH)
		return null

	# Obtener (o extraer) el mesh del modelo
	var entry: Dictionary = {}
	if _mesh_cache.has(model_name):
		entry = _mesh_cache[model_name]
	else:
		entry = _extract_mesh(model_name)
		if entry.is_empty():
			return null
		_mesh_cache[model_name] = entry

	# Crear un nodo raiz con el mesh del modelo
	var root := Node3D.new()
	root.name = model_name
	var mi := MeshInstance3D.new()
	mi.name = model_name
	mi.mesh = entry["mesh"]
	mi.transform = entry["transform"]
	root.add_child(mi)

	# Normalizar escala: el FBX viene con scale=100 y rotacion de 90 grados
	# en X (Blender Z-up -> Godot Y-up). Se calcula el AABB real y se escala
	# para que la altura sea target_height.
	var aabb := _combined_aabb(root)
	if aabb.size.y > 0.0001:
		var scale_factor := target_height / aabb.size.y
		root.scale = Vector3.ONE * scale_factor
		# Reposicionar para que la base quede en y=0
		root.position.y -= aabb.position.y * scale_factor

	return root


## Extrae el mesh y la transformacion de un modelo del FBX (una sola vez).
func _extract_mesh(model_name: String) -> Dictionary:
	var inst: Node = _fbx_scene.instantiate()
	var source: MeshInstance3D = null
	for child in inst.get_children():
		if child is MeshInstance3D and child.name == model_name:
			source = child
			break

	if source == null:
		push_warning("[forest] No se encontro el modelo '%s' en el FBX" % model_name)
		inst.free()
		return {}

	var result := {
		"mesh": source.mesh,
		"transform": source.transform,
	}
	inst.free()
	return result


## Calcula el AABB combinado de todas las mallas visibles en `node`,
## expresado en el espacio local de `node` (aplicando la transformacion de
## cada MeshInstance3D, que en este FBX incluye scale=100 y rotacion de 90
## grados - sin esto el AABB sale diminuto y la escala normalizada queda
## gigante). Usa `transform` (local) en vez de `global_transform` porque el
## nodo puede no estar en el arbol de escena cuando se calcula.
func _combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for vi in _find_visual(node):
		var xform: Transform3D = (vi as Node3D).transform
		var aabb: AABB = xform * vi.get_aabb()
		if first:
			result = aabb
			first = false
		else:
			result = result.merge(aabb)
	return result


func _find_visual(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found += _find_visual(child)
	return found
