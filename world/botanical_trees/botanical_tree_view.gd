@tool
extends Node3D
class_name BotanicalTreeView

const AlnusRadialCrownBaker = preload("res://world/botanical_trees/alnus_radial_crown_baker.gd")

## Wrapper de alto nivel para el nodo Rust BotanicalTree (GDExtension).
## Gestiona:
## - Malla procedural generada en Rust
## - Materiales retro PSX con TEXTURE_FILTER_NEAREST y CULL_DISABLED
## - Transición y renderizado de LODs (0, 1, 2, 3)
## - Poda interactiva y crecimiento biológico continuo

signal tree_updated(height: float, total_triangles: int, branch_count: int)

@export var species_id: String = "alnus_acuminata":
	set(v):
		species_id = v
		if _rust_tree:
			_rust_tree.set_species_id(v)
			refresh()

@export_range(0.0, 1.0, 0.01) var age: float = 0.85:
	set(v):
		age = clampf(v, 0.0, 1.0)
		if _rust_tree:
			_rust_tree.set_age(age)
			refresh()

@export var tree_seed: int = 12345:
	set(v):
		tree_seed = v
		if _rust_tree:
			_rust_tree.set_tree_seed(tree_seed)
			refresh()

@export_range(0, 3) var forced_lod: int = -1: # -1 = Automático por distancia
	set(v):
		forced_lod = v
		refresh()

## Modo de Follaje: 0 = BranchTriangles, 1 = RadialCross20, 2 = LushBranchBoughs (Ramas frondosas cruzadas en 3D)
@export_enum("BranchTriangles", "RadialCross20", "LushBranchBoughs") var foliage_mode: int = 2:
	set(v):
		foliage_mode = v
		if _rust_tree:
			_rust_tree.set_foliage_mode(v)
			refresh()

## Transición estacional: 0.0 = Verde verano montañés, 1.0 = Ámbar dorado otoñal
@export_range(0.0, 1.0, 0.01) var autumn_factor: float = 0.0:
	set(v):
		autumn_factor = clampf(v, 0.0, 1.0)
		_update_foliage_color()

# Distancias de cambio de LOD si forced_lod == -1
@export var lod1_distance: float = 30.0
@export var lod2_distance: float = 70.0
@export var lod3_distance: float = 120.0

var _rust_tree: Object = null
var _mesh_instance: MeshInstance3D = null
var _mat_wood: StandardMaterial3D = null
var _mat_leaves: StandardMaterial3D = null
var _mat_lod3_wood: StandardMaterial3D = null
var _mat_lod3_leaves: StandardMaterial3D = null
var _mat_bough_shader: ShaderMaterial = null

var _cached_lod: int = -1
var _last_cam_pos: Vector3 = Vector3.INF

func _init() -> void:
	_init_materials()
	
	if ClassDB.class_exists("BotanicalTree"):
		_rust_tree = ClassDB.instantiate("BotanicalTree")
		_rust_tree.set_species_id(species_id)
		_rust_tree.set_tree_seed(tree_seed)
		_rust_tree.set_age(age)
		_rust_tree.set_foliage_mode(foliage_mode)
		add_child(_rust_tree)
	else:
		push_error("BotanicalTree no está disponible en ClassDB (GDExtension).")
	
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TreeMeshInstance"
	add_child(_mesh_instance)

func _ready() -> void:
	refresh()

func _process(_delta: float) -> void:
	if forced_lod >= 0:
		return
	
	# Cálculo de LOD dinámico por distancia a la cámara activa
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam:
		var dist := global_position.distance_to(cam.global_position)
		var target_lod := 0
		if dist >= lod3_distance:
			target_lod = 3
		elif dist >= lod2_distance:
			target_lod = 2
		elif dist >= lod1_distance:
			target_lod = 1
		
		if target_lod != _cached_lod:
			_cached_lod = target_lod
			_apply_lod(target_lod)

func _init_materials() -> void:
	# 1. Material de Madera (Corteza de Aliso con textura provista por el usuario)
	_mat_wood = StandardMaterial3D.new()
	_mat_wood.resource_name = "Mat_Alnus_Wood"
	var bark_tex := _load_texture("res://assets/vegetation/alnus/alnus_bark.png")
	if bark_tex:
		_mat_wood.albedo_texture = bark_tex
		_mat_wood.albedo_color = Color(0.72, 0.64, 0.54) # Tono cálido de madera natural que resalta las vetas y grietas
	else:
		_mat_wood.albedo_color = Color(0.38, 0.35, 0.32)
	_mat_wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat_wood.texture_repeat = true
	_mat_wood.cull_mode = BaseMaterial3D.CULL_BACK
	_mat_wood.roughness = 1.0
	_mat_wood.metallic_specular = 0.0
	_mat_wood.metallic = 0.0
	_mat_wood.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	# 2. Material de Follaje (Atlas 2x2 de Ramas de Aliso recortadas por el usuario)
	_mat_leaves = StandardMaterial3D.new()
	_mat_leaves.resource_name = "Mat_Alnus_Leaves"
	var leaf_tex := _load_texture("res://assets/vegetation/alnus/alnus_leaf_atlas.png")
	if not leaf_tex:
		leaf_tex = _load_texture("res://assets/vegetation/alnus/alnus_leaf_cluster.png")
	
	if leaf_tex:
		_mat_leaves.albedo_texture = leaf_tex
	
	_mat_leaves.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat_leaves.alpha_scissor_threshold = 0.25
	_mat_leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_leaves.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat_leaves.texture_repeat = true
	_mat_leaves.roughness = 0.82
	
	# 3. Materiales para LOD 3 (Billboard en Y para impostor lejano)
	_mat_lod3_wood = _mat_wood.duplicate()
	_mat_lod3_wood.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_mat_lod3_wood.billboard_keep_scale = true
	
	_mat_lod3_leaves = _mat_leaves.duplicate()
	_mat_lod3_leaves.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_mat_lod3_leaves.billboard_keep_scale = true
	
	# 4. Material de Ramas Frondosas (LushBranchBoughs) con Shader estacional y detección madera/hoja
	var shader_res = load("res://world/botanical_trees/alnus_bough.gdshader")
	if shader_res is Shader:
		_mat_bough_shader = ShaderMaterial.new()
		_mat_bough_shader.shader = shader_res
		var bough_tex := _load_texture("res://assets/vegetation/alnus/alnus_bough_atlas.png")
		if bough_tex:
			_mat_bough_shader.set_shader_parameter("texture_albedo", bough_tex)
		_mat_bough_shader.set_shader_parameter("autumn_factor", autumn_factor)
	
	_update_foliage_color()

func _update_foliage_color() -> void:
	# Modulación estacional de color sobre la textura en escala de grises:
	# 0.0 = Verde bosque templado de montaña (idéntico al de la foto)
	# 1.0 = Ámbar dorado otoñal
	var summer_color := Color(0.38, 0.58, 0.22)
	var autumn_color := Color(0.85, 0.68, 0.16)
	var final_color := summer_color.lerp(autumn_color, autumn_factor)
	
	if _mat_leaves:
		_mat_leaves.albedo_color = final_color
	if _mat_lod3_leaves:
		_mat_lod3_leaves.albedo_color = final_color
	if _mat_bough_shader:
		_mat_bough_shader.set_shader_parameter("autumn_factor", autumn_factor)

func _load_texture(path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return null

func _update_foliage_texture() -> void:
	if not _rust_tree or not _mat_leaves:
		return
	
	if foliage_mode == 1:
		var bounds: Vector3 = _rust_tree.get_canopy_bounds()
		var segs: Array = _rust_tree.get_branch_segments()
		var baked_tex := AlnusRadialCrownBaker.bake_atlas(bounds, segs, tree_seed)
		if baked_tex:
			_mat_leaves.albedo_texture = baked_tex
			_mat_leaves.texture_repeat = false
			_mat_leaves.alpha_scissor_threshold = 0.20
	else:
		var leaf_tex := _load_texture("res://assets/vegetation/alnus/alnus_leaf_atlas.png")
		if not leaf_tex:
			leaf_tex = _load_texture("res://assets/vegetation/alnus/alnus_leaf_cluster.png")
		if leaf_tex:
			_mat_leaves.albedo_texture = leaf_tex
			_mat_leaves.texture_repeat = true
			_mat_leaves.alpha_scissor_threshold = 0.25

func refresh() -> void:
	if not _rust_tree or not _mesh_instance:
		return
	
	_update_foliage_texture()
	
	var lod_to_use := forced_lod if forced_lod >= 0 else 0
	_cached_lod = lod_to_use
	_apply_lod(lod_to_use)
	
	var h: float = _rust_tree.get_height()
	var tris: int = _rust_tree.get_total_triangles(lod_to_use)
	var branches: int = _rust_tree.get_branch_count()
	tree_updated.emit(h, tris, branches)

func _apply_lod(lod: int) -> void:
	if not _rust_tree or not _mesh_instance:
		return
	
	var mesh: ArrayMesh = _rust_tree.get_lod_mesh(lod)
	if not mesh:
		return
	
	_mesh_instance.mesh = mesh
	
	# Asignar materiales según LOD
	if lod == 3:
		_mesh_instance.set_surface_override_material(0, _mat_lod3_wood)
		if mesh.get_surface_count() > 1:
			_mesh_instance.set_surface_override_material(1, _mat_lod3_leaves)
	else:
		_mesh_instance.set_surface_override_material(0, _mat_wood)
		if mesh.get_surface_count() > 1:
			var mat_to_use: Material = _mat_leaves
			if foliage_mode == 2:
				var tree_age: float = _rust_tree.get_age() if _rust_tree else 1.0
				if tree_age >= 0.38 and _mat_bough_shader:
					mat_to_use = _mat_bough_shader
				else:
					mat_to_use = _mat_leaves
			_mesh_instance.set_surface_override_material(1, mat_to_use)

## Poda interactiva: corta una rama primaria y redistribuye la savia botánica.
func prune_random_branch() -> int:
	if not _rust_tree:
		return 0
	var cut: int = _rust_tree.prune_random_branch()
	refresh()
	return cut

## Poda un nodo específico por su ID.
func prune_branch_id(node_id: int) -> int:
	if not _rust_tree:
		return 0
	var cut: int = _rust_tree.prune_branch(node_id)
	refresh()
	return cut

## Restaura todas las podas y regenera el árbol en su estado completo.
func restore_all_branches() -> void:
	if not _rust_tree:
		return
	_rust_tree.restore_all_branches()
	refresh()

func get_height() -> float:
	return _rust_tree.get_height() if _rust_tree else 0.0

func get_total_triangles(lod: int = -1) -> int:
	if not _rust_tree:
		return 0
	var l := lod if lod >= 0 else (_cached_lod if _cached_lod >= 0 else 0)
	return _rust_tree.get_total_triangles(l)

func get_branch_count() -> int:
	return _rust_tree.get_branch_count() if _rust_tree else 0
