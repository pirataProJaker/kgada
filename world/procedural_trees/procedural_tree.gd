extends Node3D
class_name ProceduralTree

const ProceduralTreeProfiles = preload("res://world/procedural_trees/procedural_tree_profiles.gd")
const ProceduralTreeGenerator = preload("res://world/procedural_trees/procedural_tree_generator.gd")
const ProceduralTreeTextures = preload("res://world/procedural_trees/procedural_tree_textures.gd")
const ProceduralTreeMaterials = preload("res://world/procedural_trees/procedural_tree_materials.gd")
## Nodo visual de arbol procedural hiperoptimizado.
## Administra las instancias de MultiMeshInstance3D para ramas y hojas en 3 niveles de LOD.
## Soporta conmutacion automatica de LOD por distancia de Godot (visibility_range)
## o seleccion manual forzada para depuracion y pruebas.

enum FoliageStyle {
	STANDARD = 0,
	LOW_SPEC_TRIANGLE = 1
}

## Interruptor maestro para diagnóstico de rendimiento: si es verdadero, ningún árbol renderiza nada
static var trees_disabled: bool = false

@export var tree_seed: int = 12345
@export var profile_id: String = "pine_boreal"
@export var foliage_style: FoliageStyle = FoliageStyle.STANDARD:
	set(value):
		foliage_style = value
		if is_node_ready() and current_profile != null:
			generate(tree_seed, profile_id)

@export var use_foliage_textures: bool = true:
	set(value):
		use_foliage_textures = value
		_apply_shared_materials()

@export var cast_shadows: bool = true:
	set(value):
		cast_shadows = value
		_update_shadow_settings()

## Desactiva por completo el sistema de LOD: si es verdadero, siempre muestra LOD0.
@export var disable_lod: bool = true:
	set(value):
		disable_lod = value
		if is_node_ready():
			_apply_lod_distance_ranges()

## Modo diagnóstico/rendimiento: desactiva totalmente las hojas, mostrando únicamente troncos.
@export var trunks_only: bool = false:
	set(value):
		trunks_only = value
		if is_node_ready():
			_apply_lod_distance_ranges()

# Distancias de transicion para los niveles de detalle (LOD)
# LOD0 (0-30m): Tronco continuo completo + ramas y follaje 3D cruzado (LushBranchBoughs, ~1,058 tris)
# LOD1 (30-75m): Tronco de 4 lados + aletas y tarjetas al 50% (~438 tris)
# LOD2 (75-160m): Cinta vertical continua + silueta perimetral (~66 tris)
@export var lod0_range_end: float = 30.0
@export var lod1_range_end: float = 75.0
@export var lod2_range_end: float = 160.0

var tree_height: float = 0.0

# -1 = Auto (controlado por distancia de camara), 0 = LOD0, 1 = LOD1, 2 = LOD2
var forced_lod_level: int = -1:
	set(value):
		forced_lod_level = value
		_update_forced_lod_visibility()

# Nodos MultiMeshInstance3D para cada LOD (exactamente 2 llamadas de dibujo activas)
var _mi_branches_lod0: MultiMeshInstance3D
var _mi_leaves_lod0: MultiMeshInstance3D

var _mi_branches_lod1: MultiMeshInstance3D
var _mi_leaves_lod1: MultiMeshInstance3D

var _mi_branches_lod2: MultiMeshInstance3D
var _mi_leaves_lod2: MultiMeshInstance3D

# Nodo MultiMeshInstance3D para la sombra simple volumétrica (Icosaedro GPU Proxy)
var _mi_simple_shadow: MultiMeshInstance3D
static var _icosahedron_mesh: ArrayMesh = null

var current_profile: ProceduralTreeProfiles.TreeProfile = null
var current_generation_result: ProceduralTreeGenerator.TreeGenerationResult = null


func _enter_tree() -> void:
	var sm = _get_settings_manager()
	if sm and not sm.shadow_settings_changed.is_connected(_on_shadow_settings_changed):
		sm.shadow_settings_changed.connect(_on_shadow_settings_changed)
	_update_shadow_settings()


func _ready() -> void:
	_init_nodes_and_materials()
	if current_profile == null:
		generate(tree_seed, profile_id)
	
	var sm = _get_settings_manager()
	if sm and not sm.shadow_settings_changed.is_connected(_on_shadow_settings_changed):
		sm.shadow_settings_changed.connect(_on_shadow_settings_changed)
	_update_shadow_settings()


func _exit_tree() -> void:
	var sm = _get_settings_manager()
	if sm and sm.shadow_settings_changed.is_connected(_on_shadow_settings_changed):
		sm.shadow_settings_changed.disconnect(_on_shadow_settings_changed)


func _get_settings_manager() -> Node:
	if is_inside_tree():
		var st := get_tree()
		if st != null and st.root != null:
			return st.root.get_node_or_null("SettingsManager")
	var p: Node = get_parent()
	while p != null:
		if p.has_node("SettingsManager"):
			return p.get_node_or_null("SettingsManager")
		p = p.get_parent()
	var main_st := Engine.get_main_loop() as SceneTree
	if main_st != null and main_st.root != null:
		return main_st.root.get_node_or_null("SettingsManager")
	return null


func _on_shadow_settings_changed(_mode: int) -> void:
	_update_shadow_settings()


## Inicializa los nodos visuales de MultiMeshInstance3D y asigna los materiales compartidos.
func _init_nodes_and_materials() -> void:
	if _mi_branches_lod0 != null:
		return
	
	_mi_branches_lod0 = _create_mmi("Branches_LOD0")
	_mi_leaves_lod0 = _create_mmi("Leaves_LOD0")
	
	_mi_branches_lod1 = _create_mmi("Branches_LOD1")
	_mi_leaves_lod1 = _create_mmi("Leaves_LOD1")
	
	_mi_branches_lod2 = _create_mmi("Branches_LOD2")
	_mi_leaves_lod2 = _create_mmi("Leaves_LOD2")
	
	_mi_simple_shadow = _create_mmi("SimpleShadowProxy")
	
	_apply_shared_materials()
	_update_shadow_settings()
	_apply_lod_distance_ranges()


## Aplica las configuraciones de sombra selectivas para optimización máxima de GPU.
## - Modo "Sombras detalladas": LOD0 tronco+hojas completos.
## - Modo "Sombras simples" (para PCs cacahuate): Hojas apagadas del cálculo de sombras;
##   se proyecta la sombra mediante un icosaedro 3D (SHADOWS_ONLY) de 20 triángulos sólidos.
func _update_shadow_settings() -> void:
	if _mi_branches_lod0 == null:
		return
	
	if not cast_shadows:
		_mi_branches_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_branches_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_branches_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _mi_simple_shadow != null:
			_mi_simple_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mi_simple_shadow.visible = false
		return
	
	var shadow_mode: int = 0
	var sm = _get_settings_manager()
	if sm and sm.has_method("get_shadow_mode"):
		shadow_mode = sm.get_shadow_mode()
	
	if shadow_mode == 0:
		# SOMBRAS DETALLADAS:
		_mi_branches_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_mi_leaves_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_mi_branches_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_mi_leaves_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_branches_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		if _mi_simple_shadow != null:
			_mi_simple_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mi_simple_shadow.visible = false
	else:
		# SOMBRAS SIMPLES (OPTIMIZADAS PARA PC CACAHUATE):
		_mi_branches_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_mi_branches_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_mi_branches_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		# Hojas transparentes apagadas del cálculo de sombras
		_mi_leaves_lod0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi_leaves_lod2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		if _mi_simple_shadow != null:
			_mi_simple_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			_mi_simple_shadow.visible = true


const PSXPine = preload("res://world/vegetation/trees/psx_pine.gd")

## Asigna los materiales compartidos desde la caché global (batching GPU óptimo).
func _apply_shared_materials() -> void:
	if _mi_branches_lod0 == null:
		return
	var target_pid := profile_id if not profile_id.is_empty() else "classic_oak"
	if target_pid.to_lower().begins_with("pine"):
		_mi_branches_lod0.material_override = PSXPine.get_lod0_trunk_material()
		_mi_leaves_lod0.material_override = PSXPine.get_lod0_crown_material()
		_mi_branches_lod1.material_override = PSXPine.get_lod1_trunk_material()
		_mi_leaves_lod1.material_override = PSXPine.get_lod1_crown_material()
		_mi_branches_lod2.material_override = PSXPine.get_lod1_trunk_material()
		_mi_leaves_lod2.material_override = PSXPine.get_lod1_crown_material()
		return
		
	var bark_mat := ProceduralTreeMaterials.get_bark_material(target_pid, use_foliage_textures)
	var leaf_mat := ProceduralTreeMaterials.get_leaf_material(target_pid, use_foliage_textures)
	
	_mi_branches_lod0.material_override = bark_mat
	_mi_branches_lod1.material_override = bark_mat
	_mi_branches_lod2.material_override = bark_mat
	
	_mi_leaves_lod0.material_override = leaf_mat
	_mi_leaves_lod1.material_override = leaf_mat
	_mi_leaves_lod2.material_override = leaf_mat


## Crea un MultiMeshInstance3D hijo.
func _create_mmi(node_name: String) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	add_child(mmi)
	return mmi


## Configura los rangos de visibilidad nativos de Godot (GeometryInstance3D).
func _apply_lod_distance_ranges() -> void:
	if trees_disabled:
		visible = false
		if _mi_branches_lod0 != null: _mi_branches_lod0.visible = false
		if _mi_leaves_lod0 != null: _mi_leaves_lod0.visible = false
		if _mi_branches_lod1 != null: _mi_branches_lod1.visible = false
		if _mi_leaves_lod1 != null: _mi_leaves_lod1.visible = false
		if _mi_branches_lod2 != null: _mi_branches_lod2.visible = false
		if _mi_leaves_lod2 != null: _mi_leaves_lod2.visible = false
		if _mi_simple_shadow != null: _mi_simple_shadow.visible = false
		return

	if forced_lod_level >= 0:
		_update_forced_lod_visibility()
		return
	
	if disable_lod:
		# Sistema LOD desactivado: siempre renderizar arboles normales completos (LOD0) a cualquier distancia
		_set_visibility_range(_mi_branches_lod0, 0.0, 0.0)
		_set_visibility_range(_mi_leaves_lod0, 0.0, 0.0)
		
		# Apagar por completo niveles de detalle reducidos
		if _mi_branches_lod1 != null:
			_mi_branches_lod1.visible = false
			_mi_branches_lod1.visibility_range_begin = 99999.0
			_mi_branches_lod1.visibility_range_end = 99999.0
		if _mi_leaves_lod1 != null:
			_mi_leaves_lod1.visible = false
			_mi_leaves_lod1.visibility_range_begin = 99999.0
			_mi_leaves_lod1.visibility_range_end = 99999.0
		if _mi_branches_lod2 != null:
			_mi_branches_lod2.visible = false
			_mi_branches_lod2.visibility_range_begin = 99999.0
			_mi_branches_lod2.visibility_range_end = 99999.0
		if _mi_leaves_lod2 != null:
			_mi_leaves_lod2.visible = false
			_mi_leaves_lod2.visibility_range_begin = 99999.0
			_mi_leaves_lod2.visibility_range_end = 99999.0
		if _mi_simple_shadow != null:
			_set_simple_shadow_visibility_range(0.0, 0.0)
		return

	# Pinos PSX: LOD 0 (30 tris) de 0m a 100m, LOD 1 (2 tris en GPU) de 100m a 400m
	var target_pid := profile_id if not profile_id.is_empty() else "classic_oak"
	if target_pid.to_lower().begins_with("pine"):
		_set_visibility_range(_mi_branches_lod0, 0.0, 100.0)
		_set_visibility_range(_mi_leaves_lod0, 0.0, 100.0)
		_set_visibility_range(_mi_branches_lod1, 100.0, 400.0)
		_set_visibility_range(_mi_leaves_lod1, 100.0, 400.0)
		if _mi_branches_lod2 != null:
			_mi_branches_lod2.visible = false
			_mi_branches_lod2.visibility_range_begin = 99999.0
			_mi_branches_lod2.visibility_range_end = 99999.0
		if _mi_leaves_lod2 != null:
			_mi_leaves_lod2.visible = false
			_mi_leaves_lod2.visibility_range_begin = 99999.0
			_mi_leaves_lod2.visibility_range_end = 99999.0
		if _mi_simple_shadow != null:
			_set_simple_shadow_visibility_range(0.0, 100.0)
		return
	
	# LOD 0 (0-15m): visible de 0m a lod0_range_end
	_set_visibility_range(_mi_branches_lod0, 0.0, lod0_range_end)
	if trunks_only:
		_mi_leaves_lod0.visible = false
		_mi_leaves_lod0.visibility_range_begin = 99999.0
		_mi_leaves_lod0.visibility_range_end = 99999.0
	else:
		_set_visibility_range(_mi_leaves_lod0, 0.0, lod0_range_end)
	
	# LOD 1 (15-40m):
	_set_visibility_range(_mi_branches_lod1, lod0_range_end, lod1_range_end)
	if trunks_only:
		if _mi_leaves_lod1 != null:
			_mi_leaves_lod1.visible = false
			_mi_leaves_lod1.visibility_range_begin = 99999.0
			_mi_leaves_lod1.visibility_range_end = 99999.0
	else:
		_set_visibility_range(_mi_leaves_lod1, lod0_range_end, lod1_range_end)
	
	# LOD 2 (40-80m):
	_set_visibility_range(_mi_branches_lod2, lod1_range_end, lod2_range_end)
	if trunks_only:
		if _mi_leaves_lod2 != null:
			_mi_leaves_lod2.visible = false
			_mi_leaves_lod2.visibility_range_begin = 99999.0
			_mi_leaves_lod2.visibility_range_end = 99999.0
	else:
		_set_visibility_range(_mi_leaves_lod2, lod1_range_end, lod2_range_end)

	# Rango de distancia para la sombra simple volumétrica
	if _mi_simple_shadow != null:
		var shadow_end := 100.0 if target_pid.to_lower().begins_with("pine") else lod1_range_end
		_set_simple_shadow_visibility_range(0.0, shadow_end)


func _set_visibility_range(mmi: GeometryInstance3D, range_begin: float, range_end: float) -> void:
	if mmi == null:
		return
	mmi.visible = true
	mmi.visibility_range_begin = range_begin
	mmi.visibility_range_end = range_end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mmi.visibility_range_begin_margin = 0.0
	mmi.visibility_range_end_margin = 0.0


func _set_simple_shadow_visibility_range(range_begin: float, range_end: float) -> void:
	if _mi_simple_shadow == null:
		return
	_mi_simple_shadow.visibility_range_begin = range_begin
	_mi_simple_shadow.visibility_range_end = range_end
	_mi_simple_shadow.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	_mi_simple_shadow.visibility_range_begin_margin = 0.0
	_mi_simple_shadow.visibility_range_end_margin = 0.0
	_mi_simple_shadow.visible = (_mi_simple_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


## Aplica visibilidad forzada manual cuando se depura un nivel especifico.
func _update_forced_lod_visibility() -> void:
	if trees_disabled:
		visible = false
		return
	if _mi_branches_lod0 == null:
		return
	
	if forced_lod_level < 0:
		# Restaurar comportamiento automatico por distancia
		_apply_lod_distance_ranges()
		return
	
	# Desactivar rangos de distancia en modo forzado
	for mmi in [_mi_branches_lod0, _mi_leaves_lod0, _mi_branches_lod1, _mi_leaves_lod1, _mi_branches_lod2, _mi_leaves_lod2, _mi_simple_shadow]:
		if mmi != null:
			mmi.visibility_range_begin = 0.0
			mmi.visibility_range_end = 0.0
	
	_mi_branches_lod0.visible = (forced_lod_level == 0)
	_mi_leaves_lod0.visible = (forced_lod_level == 0)
	
	_mi_branches_lod1.visible = (forced_lod_level == 1)
	_mi_leaves_lod1.visible = (forced_lod_level == 1)
	
	_mi_branches_lod2.visible = (forced_lod_level == 2)
	_mi_leaves_lod2.visible = (forced_lod_level == 2)
	
	if _mi_simple_shadow != null:
		_mi_simple_shadow.visible = (_mi_simple_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


## Genera o regenera el arbol con la semilla y perfil dados.
func generate(new_seed: int = -1, new_profile_id: String = "") -> ProceduralTreeGenerator.TreeGenerationResult:
	_init_nodes_and_materials()
	if trees_disabled:
		visible = false
		return null
	
	if new_seed >= 0:
		tree_seed = new_seed
	if not new_profile_id.is_empty():
		profile_id = new_profile_id
	
	current_profile = ProceduralTreeProfiles.get_profile(profile_id)
	_apply_shared_materials()
	
	# Invocar el generador matematico
	var gen_foliage_mode: int = ProceduralTreeGenerator.FoliageMode.LOW_SPEC_TRIANGLE if foliage_style == FoliageStyle.LOW_SPEC_TRIANGLE else ProceduralTreeGenerator.FoliageMode.STANDARD
	current_generation_result = ProceduralTreeGenerator.generate_tree(current_profile, tree_seed, gen_foliage_mode)
	tree_height = current_generation_result.tree_height
	
	# Asignar los MultiMeshes generados a los nodos visuales
	_mi_branches_lod0.multimesh = current_generation_result.mm_branches_lod0
	_mi_leaves_lod0.multimesh = current_generation_result.mm_leaves_lod0
	
	_mi_branches_lod1.multimesh = current_generation_result.mm_branches_lod1
	_mi_leaves_lod1.multimesh = current_generation_result.mm_leaves_lod1
	
	_mi_branches_lod2.multimesh = current_generation_result.mm_branches_lod2
	_mi_leaves_lod2.multimesh = current_generation_result.mm_leaves_lod2
	
	_update_simple_shadow_proxy()
	_update_shadow_settings()
	_update_forced_lod_visibility()
	return current_generation_result


## Aplica un resultado de generacion precalculado (ej. desde un hilo de fondo WorkerThreadPool).
## Costo en el hilo principal: ~0.005 ms (solo asignacion de referencias de MultiMesh).
func apply_generation_result(result: ProceduralTreeGenerator.TreeGenerationResult) -> void:
	if trees_disabled:
		visible = false
		return
	_init_nodes_and_materials()
	current_generation_result = result
	if result != null:
		tree_height = result.tree_height
		if result.profile != null:
			profile_id = result.profile.id
			current_profile = result.profile
		_apply_shared_materials()
		
		_mi_branches_lod0.multimesh = result.mm_branches_lod0
		_mi_leaves_lod0.multimesh = result.mm_leaves_lod0
		
		_mi_branches_lod1.multimesh = result.mm_branches_lod1
		_mi_leaves_lod1.multimesh = result.mm_leaves_lod1
		
		_mi_branches_lod2.multimesh = result.mm_branches_lod2
		_mi_leaves_lod2.multimesh = result.mm_leaves_lod2
	
	_update_simple_shadow_proxy()
	_update_shadow_settings()
	_update_forced_lod_visibility()


## Retorna o crea la malla unitaria del icosaedro (20 triángulos) compartida en memoria.
static func _get_icosahedron_mesh() -> ArrayMesh:
	if _icosahedron_mesh != null:
		return _icosahedron_mesh
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var phi: float = (1.0 + sqrt(5.0)) / 2.0
	var raw_verts: Array[Vector3] = [
		Vector3(-1.0, phi, 0.0), Vector3(1.0, phi, 0.0),
		Vector3(-1.0, -phi, 0.0), Vector3(1.0, -phi, 0.0),
		Vector3(0.0, -1.0, phi), Vector3(0.0, 1.0, phi),
		Vector3(0.0, -1.0, -phi), Vector3(0.0, 1.0, -phi),
		Vector3(phi, 0.0, -1.0), Vector3(phi, 0.0, 1.0),
		Vector3(-phi, 0.0, -1.0), Vector3(-phi, 0.0, 1.0),
	]
	
	var norm_verts: Array[Vector3] = []
	for v in raw_verts:
		norm_verts.append(v.normalized())
	
	var indices: Array[int] = [
		0, 11, 5,   0, 5, 1,    0, 1, 7,    0, 7, 10,   0, 10, 11,
		1, 5, 9,    5, 11, 4,   11, 10, 2,  10, 7, 6,   7, 1, 8,
		3, 9, 4,    3, 4, 2,    3, 2, 6,    3, 6, 8,    3, 8, 9,
		4, 9, 5,    2, 4, 11,   6, 2, 10,   8, 6, 7,    9, 8, 1
	]
	
	for i in range(0, indices.size(), 3):
		var v0: Vector3 = norm_verts[indices[i]]
		var v1: Vector3 = norm_verts[indices[i + 1]]
		var v2: Vector3 = norm_verts[indices[i + 2]]
		var norm: Vector3 = ((v1 - v0).cross(v2 - v0)).normalized()
		st.set_normal(norm); st.add_vertex(v0)
		st.set_normal(norm); st.add_vertex(v1)
		st.set_normal(norm); st.add_vertex(v2)
	
	_icosahedron_mesh = st.commit()
	return _icosahedron_mesh


## Actualiza la posición y proporciones del icosaedro para la sombra simple:
## - Base: a la altura donde nacen las primeras ramas del tronco.
## - Cúspide: donde termina el tronco / árbol.
## - Ancho: radio horizontal que cubren las ramas.
func _update_simple_shadow_proxy() -> void:
	if _mi_simple_shadow == null:
		return
	
	var y_base: float = 0.0
	var y_top: float = maxf(tree_height, 2.0)
	var horiz_radius: float = maxf(tree_height * 0.45, 1.5)
	
	var is_pine: bool = profile_id.to_lower().begins_with("pine")
	if is_pine:
		y_base = maxf(tree_height * 0.12, 1.0)
		horiz_radius = maxf(tree_height * 0.16, 2.0)
	elif current_profile != null:
		y_base = maxf(current_profile.branch_start_ratio * tree_height, 1.0)
		horiz_radius = maxf(current_profile.branch_length_ratio * tree_height * 0.75, 2.0)
	else:
		y_base = maxf(tree_height * 0.35, 1.0)
	
	if current_generation_result != null and current_generation_result.mm_leaves_lod0 != null:
		var m: Mesh = current_generation_result.mm_leaves_lod0.mesh
		if m != null:
			var aabb: AABB = m.get_aabb()
			if aabb.size.y > 0.5:
				y_base = maxf(aabb.position.y, 0.5)
				y_top = aabb.end.y
				horiz_radius = maxf(aabb.size.x, aabb.size.z) * 0.5
	
	var y_height: float = maxf(y_top - y_base, 1.0)
	var y_center: float = y_base + y_height * 0.5
	var y_radius: float = y_height * 0.5
	
	var t_ico := Transform3D()
	t_ico = t_ico.scaled(Vector3(horiz_radius, y_radius, horiz_radius))
	t_ico.origin = Vector3(0.0, y_center, 0.0)
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _get_icosahedron_mesh()
	mm.instance_count = 1
	mm.set_instance_transform(0, t_ico)
	
	_mi_simple_shadow.multimesh = mm
