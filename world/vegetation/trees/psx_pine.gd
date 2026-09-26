extends Node3D
class_name PSXPine

## Modelo de pino PSX ultra-optimizado con sistema de LOD a 100m.
## - LOD 0 (0-100m): Modelo 3D de 30 triángulos (26 de tronco + 4 de copa en cruz).
## - LOD 1 (100-400m): EXACTAMENTE 2 triángulos (1 triángulo para el tronco + 1 triángulo para la copa).
##   Usa las mismas texturas, alineación UV diagonal y modo BILLBOARD_FIXED_Y para coincidencia visual idéntica.
##   Compatible con GPU Instancing (MultiMeshInstance3D) para dibujar miles de árboles en 2 draw calls.

const FBX_PATH_1 := "res://assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts.fbx"
const FBX_PATH_2 := "res://PSX_Forest_AssetCollection_byStarkCrafts.fbx"

const TEX_CROWN_PATH_1 := "res://assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts_10.png"
const TEX_CROWN_PATH_2 := "res://PSX_Forest_AssetCollection_byStarkCrafts_10.png"

const TEX_TRUNK_PATH_1 := "res://assets/entorno/PSX_Forest_AssetCollection_byStarkCrafts_11.png"
const TEX_TRUNK_PATH_2 := "res://PSX_Forest_AssetCollection_byStarkCrafts_11.png"

const TEX_LOD1_CROWN_PATH_1 := "res://assets/entorno/psx_pine_lod1_crown.png"
const TEX_LOD1_CROWN_PATH_2 := "res://psx_pine_lod1_crown.png"

# Caché de recursos VRAM
static var _lod0_mesh: ArrayMesh = null
static var _lod1_mesh: ArrayMesh = null

static var _lod0_trunk_mesh: ArrayMesh = null
static var _lod0_crown_mesh: ArrayMesh = null
static var _lod1_trunk_mesh: ArrayMesh = null
static var _lod1_crown_mesh: ArrayMesh = null

static var _lod0_crown_mat: StandardMaterial3D = null
static var _lod0_trunk_mat: StandardMaterial3D = null
static var _lod1_crown_mat: StandardMaterial3D = null
static var _lod1_trunk_mat: StandardMaterial3D = null

@export var lod_switch_distance: float = 100.0:
	set(v):
		lod_switch_distance = v
		if is_node_ready():
			_update_ranges()

@export var max_view_distance: float = 400.0:
	set(v):
		max_view_distance = v
		if is_node_ready():
			_update_ranges()

var _inst_lod0: MeshInstance3D
var _inst_lod1: MeshInstance3D


func _init() -> void:
	_init_lod_meshes()
	
	# LOD 0 (0-100m)
	_inst_lod0 = MeshInstance3D.new()
	_inst_lod0.name = "Pine_LOD0_3D"
	_inst_lod0.mesh = _lod0_mesh
	add_child(_inst_lod0)
	
	# LOD 1 (100-400m, 2 triángulos en GPU)
	_inst_lod1 = MeshInstance3D.new()
	_inst_lod1.name = "Pine_LOD1_2Tris"
	_inst_lod1.mesh = _lod1_mesh
	add_child(_inst_lod1)
	
	_update_ranges()


func _ready() -> void:
	_update_ranges()


func _update_ranges() -> void:
	if _inst_lod0 != null:
		_inst_lod0.visibility_range_begin = 0.0
		_inst_lod0.visibility_range_end = lod_switch_distance
		_inst_lod0.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if _inst_lod1 != null:
		_inst_lod1.visibility_range_begin = lod_switch_distance
		_inst_lod1.visibility_range_end = max_view_distance
		_inst_lod1.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


static func _get_lod1_crown_texture() -> Texture2D:
	var path1 := TEX_LOD1_CROWN_PATH_1
	var path2 := TEX_LOD1_CROWN_PATH_2
	var final_path := path1 if FileAccess.file_exists(path1) else path2
	if FileAccess.file_exists(final_path):
		var img := Image.load_from_file(final_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
		if ResourceLoader.exists(final_path):
			var res = load(final_path)
			if res is Texture2D:
				return res
	return null


## Inicializa y almacena en caché las mallas de LOD0 y LOD1.
static func _init_lod_meshes() -> void:
	if _lod0_mesh != null and _lod1_mesh != null:
		return
	
	var fbx_path := FBX_PATH_1 if ResourceLoader.exists(FBX_PATH_1) else FBX_PATH_2
	var fbx_scene: PackedScene = load(fbx_path) as PackedScene
	if fbx_scene == null:
		push_error("[PSXPine] No se pudo encontrar el FBX en %s" % fbx_path)
		return
		
	var fbx = fbx_scene.instantiate()
	var tree4: MeshInstance3D = fbx.get_node_or_null("PSX_Tree4") as MeshInstance3D
	if tree4 == null:
		push_error("[PSXPine] Nodo PSX_Tree4 no encontrado en el FBX.")
		fbx.free()
		return
		
	var orig_mesh: Mesh = tree4.mesh
	var node_t: Transform3D = tree4.transform
	var center_offset := Vector3(tree4.position.x, 0.0, tree4.position.z)
	var local_t := Transform3D(node_t.basis, node_t.origin - center_offset)
	
	# 1. Extraer materiales originales de LOD 0 (con CULL_DISABLED para que la cruz sea visible por ambas caras en 360°)
	_lod0_crown_mat = orig_mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	_lod0_crown_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lod0_crown_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	_lod0_trunk_mat = orig_mesh.surface_get_material(1).duplicate() as StandardMaterial3D
	_lod0_trunk_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_lod0_trunk_mat.roughness = 1.0
	_lod0_trunk_mat.metallic_specular = 0.0
	_lod0_trunk_mat.metallic = 0.0
	_lod0_trunk_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_lod0_trunk_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# 2. Materiales para LOD 1 con BILLBOARD_FIXED_Y
	var lod1_crown_tex: Texture2D = _get_lod1_crown_texture()
	_lod1_crown_mat = StandardMaterial3D.new()
	if lod1_crown_tex != null:
		_lod1_crown_mat.albedo_texture = lod1_crown_tex
	else:
		_lod1_crown_mat.albedo_texture = _lod0_crown_mat.albedo_texture
	_lod1_crown_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_lod1_crown_mat.alpha_scissor_threshold = 0.5
	_lod1_crown_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_lod1_crown_mat.billboard_keep_scale = true
	_lod1_crown_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lod1_crown_mat.texture_repeat = false
	_lod1_crown_mat.roughness = 1.0
	_lod1_crown_mat.metallic_specular = 0.0
	_lod1_crown_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_lod1_crown_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	_lod1_trunk_mat = _lod0_trunk_mat.duplicate() as StandardMaterial3D
	_lod1_trunk_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_lod1_trunk_mat.billboard_keep_scale = true
	_lod1_trunk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lod1_trunk_mat.albedo_color = Color(0.85, 0.80, 0.78)
	_lod1_trunk_mat.roughness = 1.0
	_lod1_trunk_mat.metallic_specular = 0.0
	_lod1_trunk_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_lod1_trunk_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# 3. Construir LOD 0 (Malla normalizada en Y=0)
	_lod0_mesh = ArrayMesh.new()
	_lod0_crown_mesh = ArrayMesh.new()
	_lod0_trunk_mesh = ArrayMesh.new()
	
	# Superficie 0: Copa en Cruz 3D Perfecta (Exactamente 90° entre planos, simétrica y centrada)
	var hw := 11.0
	var base_y := 12.8
	var top_y := 33.5
	var mid_y := 22.36
	var d := hw * 0.70710678 # 45 grados para una cruz perpendicular simétrica a 90°
	
	var crown0_st = SurfaceTool.new()
	crown0_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Cuadrilátero 1: (-d, mid_y, -d) a (+d, mid_y, +d)
	crown0_st.set_uv(Vector2(1, 0)); crown0_st.add_vertex(Vector3(d, mid_y, d))
	crown0_st.set_uv(Vector2(1, 1)); crown0_st.add_vertex(Vector3(0, base_y, 0))
	crown0_st.set_uv(Vector2(0, 1)); crown0_st.add_vertex(Vector3(-d, mid_y, -d))
	
	crown0_st.set_uv(Vector2(0, 1)); crown0_st.add_vertex(Vector3(-d, mid_y, -d))
	crown0_st.set_uv(Vector2(0, 0)); crown0_st.add_vertex(Vector3(0, top_y, 0))
	crown0_st.set_uv(Vector2(1, 0)); crown0_st.add_vertex(Vector3(d, mid_y, d))
	
	# Cuadrilátero 2: (-d, mid_y, +d) a (+d, mid_y, -d) -- EXACTAMENTE 90.0° PERPENDICULAR
	crown0_st.set_uv(Vector2(1, 0)); crown0_st.add_vertex(Vector3(d, mid_y, -d))
	crown0_st.set_uv(Vector2(1, 1)); crown0_st.add_vertex(Vector3(0, base_y, 0))
	crown0_st.set_uv(Vector2(0, 1)); crown0_st.add_vertex(Vector3(-d, mid_y, d))
	
	crown0_st.set_uv(Vector2(0, 1)); crown0_st.add_vertex(Vector3(-d, mid_y, d))
	crown0_st.set_uv(Vector2(0, 0)); crown0_st.add_vertex(Vector3(0, top_y, 0))
	crown0_st.set_uv(Vector2(1, 0)); crown0_st.add_vertex(Vector3(d, mid_y, -d))
	
	crown0_st.generate_normals()
	var crown0_arr = crown0_st.commit_to_arrays()
	
	_lod0_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown0_arr)
	_lod0_mesh.surface_set_material(0, _lod0_crown_mat)
	_lod0_crown_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown0_arr)
	_lod0_crown_mesh.surface_set_material(0, _lod0_crown_mat)
	
	# Superficie 1: Tronco del FBX
	var trunk_arr = orig_mesh.surface_get_arrays(1)
	var trunk_verts: PackedVector3Array = trunk_arr[Mesh.ARRAY_VERTEX]
	var new_t_verts = PackedVector3Array()
	for v in trunk_verts:
		new_t_verts.append(local_t * v)
	trunk_arr[Mesh.ARRAY_VERTEX] = new_t_verts
	
	_lod0_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_arr)
	_lod0_mesh.surface_set_material(1, _lod0_trunk_mat)
	_lod0_trunk_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_arr)
	_lod0_trunk_mesh.surface_set_material(0, _lod0_trunk_mat)
	
	# 4. Construir LOD 1 (Exactamente 2 triángulos: 1 tronco + 1 copa)
	_lod1_mesh = ArrayMesh.new()
	_lod1_trunk_mesh = ArrayMesh.new()
	_lod1_crown_mesh = ArrayMesh.new()
	
	# Superficie 0: Tronco (1 triángulo estiradísimo)
	var trunk_st = SurfaceTool.new()
	trunk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t_w = 1.80 * 0.50
	var t_y_base = -0.26
	var t_y_top = 28.50
	
	trunk_st.set_uv(Vector2(0.0, 4.0)); trunk_st.add_vertex(Vector3(-t_w, t_y_base, -0.05))
	trunk_st.set_uv(Vector2(1.0, 4.0)); trunk_st.add_vertex(Vector3(t_w, t_y_base, -0.05))
	trunk_st.set_uv(Vector2(0.5, 0.0)); trunk_st.add_vertex(Vector3(0.0, t_y_top, -0.05))
	trunk_st.generate_normals()
	
	var trunk1_arr = trunk_st.commit_to_arrays()
	_lod1_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk1_arr)
	_lod1_mesh.surface_set_material(0, _lod1_trunk_mat)
	
	_lod1_trunk_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk1_arr)
	_lod1_trunk_mesh.surface_set_material(0, _lod1_trunk_mat)
	
	# Superficie 1: Copa (1 triángulo con proporciones idénticas a la nueva cruz 3D a 90°)
	var crown1_st = SurfaceTool.new()
	crown1_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri_w = 28.5
	var tri_y_base = 12.0
	var tri_y_top = 35.5
	
	crown1_st.set_uv(Vector2(-0.5, 1.0)); crown1_st.add_vertex(Vector3(-tri_w, tri_y_base, 0.05))
	crown1_st.set_uv(Vector2(1.5, 1.0));  crown1_st.add_vertex(Vector3(tri_w, tri_y_base, 0.05))
	crown1_st.set_uv(Vector2(0.5, 0.0));  crown1_st.add_vertex(Vector3(0.0, tri_y_top, 0.05))
	crown1_st.generate_normals()
	
	var crown1_arr = crown1_st.commit_to_arrays()
	_lod1_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown1_arr)
	_lod1_mesh.surface_set_material(1, _lod1_crown_mat)
	
	_lod1_crown_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown1_arr)
	_lod1_crown_mesh.surface_set_material(0, _lod1_crown_mat)
	
	fbx.free()


static func get_lod0_mesh() -> ArrayMesh:
	_init_lod_meshes()
	return _lod0_mesh


static func get_lod1_mesh() -> ArrayMesh:
	_init_lod_meshes()
	return _lod1_mesh


static func get_lod0_trunk_mesh() -> ArrayMesh:
	_init_lod_meshes()
	return _lod0_trunk_mesh


static func get_lod0_crown_mesh() -> ArrayMesh:
	_init_lod_meshes()
	return _lod0_crown_mesh


static func get_lod1_trunk_mesh() -> ArrayMesh:
	_init_lod_meshes()
	return _lod1_trunk_mesh


static func get_lod1_crown_mesh() -> ArrayMesh:
	_init_lod_meshes()
	return _lod1_crown_mesh


static func get_lod0_crown_material() -> StandardMaterial3D:
	_init_lod_meshes()
	return _lod0_crown_mat


static func get_lod0_trunk_material() -> StandardMaterial3D:
	_init_lod_meshes()
	return _lod0_trunk_mat


static func get_lod1_crown_material() -> StandardMaterial3D:
	_init_lod_meshes()
	return _lod1_crown_mat


static func get_lod1_trunk_material() -> StandardMaterial3D:
	_init_lod_meshes()
	return _lod1_trunk_mat


## Genera un bosque completo optimizado en GPU Instancing mediante MultiMeshInstance3D.
## Utiliza 2 draw calls para LOD0 (0-100m) y 2 draw calls para LOD1 (100-400m).
static func create_gpu_instanced_forest(
	transforms: Array[Transform3D],
	lod_switch_dist: float = 100.0,
	max_dist: float = 400.0
) -> Node3D:
	_init_lod_meshes()
	var root_node := Node3D.new()
	root_node.name = "PSXPineForest_GPU"
	
	var count := transforms.size()
	if count == 0:
		return root_node
		
	# 1. MultiMesh LOD 0 (30 triángulos)
	var mm_lod0 := MultiMesh.new()
	mm_lod0.transform_format = MultiMesh.TRANSFORM_3D
	mm_lod0.mesh = _lod0_mesh
	mm_lod0.instance_count = count
	for i in range(count):
		mm_lod0.set_instance_transform(i, transforms[i])
		
	var mmi_lod0 := MultiMeshInstance3D.new()
	mmi_lod0.name = "PineForest_LOD0"
	mmi_lod0.multimesh = mm_lod0
	mmi_lod0.visibility_range_begin = 0.0
	mmi_lod0.visibility_range_end = lod_switch_dist
	mmi_lod0.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	root_node.add_child(mmi_lod0)
	
	# 2. MultiMesh LOD 1 (2 triángulos)
	var mm_lod1 := MultiMesh.new()
	mm_lod1.transform_format = MultiMesh.TRANSFORM_3D
	mm_lod1.mesh = _lod1_mesh
	mm_lod1.instance_count = count
	for i in range(count):
		mm_lod1.set_instance_transform(i, transforms[i])
		
	var mmi_lod1 := MultiMeshInstance3D.new()
	mmi_lod1.name = "PineForest_LOD1"
	mmi_lod1.multimesh = mm_lod1
	mmi_lod1.visibility_range_begin = lod_switch_dist
	mmi_lod1.visibility_range_end = max_dist
	mmi_lod1.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	root_node.add_child(mmi_lod1)
	
	return root_node
