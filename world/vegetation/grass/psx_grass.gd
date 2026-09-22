class_name PSXGrass
extends Node3D

## Césped texturizado PSX extraído del paquete de entorno PSX_Forest_AssetCollection_byStarkCrafts.
## Reutiliza el modelo 'PSX_Grass' optimizado con coordenadas horneadas y centradas (pivote en base y=0).
## Diseñado para usarse tanto como nodo individual como masivamente a través de MultiMeshInstance3D / VegetationScatter.

const FBX_PATH = "res://assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts.fbx"
const TEX_PATH = "res://assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts_1.png"
const SHADER_RES = preload("res://world/vegetation/grass/psx_grass.gdshader")

static var _cached_meshes: Dictionary = {}
static var _cached_material: ShaderMaterial = null

@export var grass_height: float = 0.45

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	if get_child_count() == 0:
		generate()

func generate() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
		
	var mesh = create_mesh(grass_height)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = get_material()
	add_child(_mesh_instance)

## Retorna el material botánico con textura, alpha scissor y viento natural
static func get_material() -> ShaderMaterial:
	if _cached_material == null:
		var mat = ShaderMaterial.new()
		mat.shader = SHADER_RES
		var tex = load(TEX_PATH) as Texture2D
		if tex:
			mat.set_shader_parameter("albedo_texture", tex)
		mat.set_shader_parameter("alpha_scissor_threshold", 0.5)
		mat.set_shader_parameter("wind_strength", 0.16)
		mat.set_shader_parameter("wind_speed", 2.2)
		mat.set_shader_parameter("plant_base_y", 0.0)
		mat.set_shader_parameter("plant_max_height", 0.32)
		mat.set_shader_parameter("tint_color", Color(0.92, 0.96, 0.88, 1.0))
		_cached_material = mat
	return _cached_material

## Extrae, normaliza, centra y hornea la malla de PSX_Grass del FBX
static func create_mesh(target_height: float = 0.32) -> ArrayMesh:
	var key = "h_%.3f" % target_height
	if _cached_meshes.has(key):
		return _cached_meshes[key]
		
	var scene: PackedScene = load(FBX_PATH)
	if not scene:
		push_error("[PSXGrass] No se pudo cargar el FBX %s" % FBX_PATH)
		return null
		
	var inst = scene.instantiate()
	var grass_node: MeshInstance3D = null
	for c in inst.get_children():
		if c.name == "PSX_Grass":
			grass_node = c
			break
			
	if not grass_node or not grass_node.mesh:
		push_error("[PSXGrass] No se encontró el nodo 'PSX_Grass' en %s" % FBX_PATH)
		inst.free()
		return null
		
	var src_mesh: Mesh = grass_node.mesh
	var xform: Transform3D = Transform3D().translated(grass_node.position).scaled(grass_node.scale) * grass_node.transform
	var arrays = src_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	
	# Calcular bounding box transformado
	var transformed_verts: PackedVector3Array = []
	var min_pt := Vector3(INF, INF, INF)
	var max_pt := Vector3(-INF, -INF, -INF)
	for i in range(verts.size()):
		var v = xform * verts[i]
		transformed_verts.append(v)
		min_pt.x = minf(min_pt.x, v.x)
		min_pt.y = minf(min_pt.y, v.y)
		min_pt.z = minf(min_pt.z, v.z)
		max_pt.x = maxf(max_pt.x, v.x)
		max_pt.y = maxf(max_pt.y, v.y)
		max_pt.z = maxf(max_pt.z, v.z)
		
	var center_x = (min_pt.x + max_pt.x) * 0.5
	var center_z = (min_pt.z + max_pt.z) * 0.5
	var base_y = min_pt.y
	var orig_height = max_pt.y - min_pt.y
	var scale_factor = target_height / orig_height if orig_height > 0.0001 else 1.0
	
	# Hornear en ArrayMesh centrado
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(indices.size()):
		var idx = indices[i]
		var v = transformed_verts[idx]
		var centered_v = Vector3(
			(v.x - center_x) * scale_factor,
			(v.y - base_y) * scale_factor,
			(v.z - center_z) * scale_factor
		)
		var uv = uvs[idx] if uvs.size() > idx else Vector2.ZERO
		var n = (xform.basis * normals[idx]).normalized() if normals.size() > idx else Vector3.UP
		
		st.set_normal(n)
		st.set_uv(uv)
		st.add_vertex(centered_v)
		
	var baked_mesh = st.commit()
	baked_mesh.surface_set_material(0, get_material())
	_cached_meshes[key] = baked_mesh
	
	inst.free()
	return baked_mesh
