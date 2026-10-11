extends Node3D

## Controlador de la escena de paisaje natural al atardecer (Meadow Sunset Showcase).
## Recrea un valle botánico y geográfico completo iluminado por la luz dorada del crepúsculo:
## - Flores: Rosas individuales/únicas (WildRose) en múltiples colores (carmesí, coral, marfil, dorado, pastel),
##   margaritas blancas, espigas de lavanda y amapolas rubí.
## - Árboles procedurales (ProceduralTree): Masa forestal lateral y pino solitario en la cresta lejana.
## - Terreno orgánico con shader PSX, césped adaptativo y niebla atmosférica de atardecer.

const VegetationScatter = preload("res://world/vegetation/common/vegetation_scatter.gd")
const WildDaisy = preload("res://world/vegetation/daisy/wild_daisy.gd")
const WildLavender = preload("res://world/vegetation/lavender/wild_lavender.gd")
const TriangleGrass = preload("res://world/vegetation/grass/triangle_grass.gd")
const PSXGrass = preload("res://world/vegetation/grass/psx_grass.gd")
const WildPoppy = preload("res://world/vegetation/poppy/wild_poppy.gd")
const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")
const FlowerProfiles = preload("res://world/procedural_flora/procedural_flower_profiles.gd")
const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")

enum GrassMode { PSX_TEXTURE, TRIANGLE_PROCEDURAL }
var current_grass_mode: GrassMode = GrassMode.PSX_TEXTURE

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var terrain_mesh: MeshInstance3D = $Terrain
@onready var trees_container: Node3D = $Trees
@onready var vegetation_container: Node3D = $Vegetation
@onready var roses_container: Node3D = $Roses

# Nodos MultiMesh de vegetación
var _scatter_grass: VegetationScatter
var _scatter_lavender: VegetationScatter
var _scatter_daisy: VegetationScatter
var _scatter_poppy: VegetationScatter

# Pool de arquetipos precalculados de ROSAS PROCEDURALES ÚNICAS (ProceduralFlower)
var _rose_archetype_pool: Array[ProceduralFlower.FlowerGenerationPackage] = []

# Material con shader botánico para flores silvestres y césped
var _flower_shader_material: ShaderMaterial

# Control de cámara orbital
var _camera_distance: float = 7.5
var _camera_pitch: float = deg_to_rad(9.0)
var _camera_yaw: float = deg_to_rad(-8.0)
var _is_mouse_dragging := false
var _last_mouse_pos := Vector2.ZERO

var _current_seed: int = 45678
var _viewpoint_index: int = 0 # 0 = Panorámica, 1 = Rosas Macro, 2 = Valle Flores, 3 = Cresta Bosque


func _ready() -> void:
	var vp = get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	
	_init_flower_material()
	_build_scene(_current_seed)
	_apply_camera_viewpoint(0)


## Inicializa el material compartido con shader botánico de viento para flores silvestres y césped
func _init_flower_material() -> void:
	_flower_shader_material = ShaderMaterial.new()
	_flower_shader_material.shader = preload("res://world/vegetation/common/vegetation_shader.gdshader")
	_flower_shader_material.set_shader_parameter("wind_strength", 0.14)
	_flower_shader_material.set_shader_parameter("wind_speed", 2.0)
	_flower_shader_material.set_shader_parameter("backlight_strength", 0.20)
	_flower_shader_material.set_shader_parameter("backlight_tint", Vector3(0.30, 0.45, 0.20))
	_flower_shader_material.set_shader_parameter("roughness", 0.80)


## Función matemática de relieve: Cuenca floral central abierta con laderas suaves y cresta de fondo
static func get_terrain_height(pos2d: Vector2) -> float:
	var x = pos2d.x
	var z = pos2d.y
	
	# Valle / cuenca central (x entre -5 y 5, z entre -4 y 3): suave elevación entre 0.4 y 1.2m
	var bowl = sin(x * 0.12 + 0.1) * 0.65 + cos(z * 0.10) * 0.55
	var micro_waves = sin(x * 0.30 + z * 0.22) * 0.18 + cos(x * 0.18 - z * 0.28) * 0.14
	
	# Ladera izquierda boscosa (x < -5.5): sube progresivamente hasta 3.8m
	var hill_left = 0.0
	if x < -5.0:
		var lx = (-x - 5.0) * 0.08
		hill_left = minf(lx * lx * 2.8, 3.8)
		
	# Ladera derecha (x > 5.5): loma suave hasta 2.6m
	var hill_right = 0.0
	if x > 5.0:
		var rx = (x - 5.0) * 0.075
		hill_right = minf(rx * rx * 2.4, 2.8)
		
	# Cresta del fondo (z < -8.0): asciende hacia la línea del horizonte
	var ridge_back = 0.0
	if z < -7.0:
		var rz = (-z - 7.0) * 0.09
		ridge_back = minf(rz * rz * 2.2, 3.6)
		# En el borde muy lejano (z < -16), suavizar hacia abajo para fundir con la niebla
		if z < -15.0:
			var fade = clampf((-z - 15.0) / 7.0, 0.0, 1.0)
			ridge_back -= fade * 2.0
			
	return bowl + micro_waves + hill_left + hill_right + ridge_back + 0.6


## Normal analítica de la superficie para orientar vegetación con precisión
static func get_terrain_normal(pos2d: Vector2) -> Vector3:
	var eps: float = 0.12
	var h_c = get_terrain_height(pos2d)
	var h_x = get_terrain_height(Vector2(pos2d.x + eps, pos2d.y))
	var h_z = get_terrain_height(Vector2(pos2d.x, pos2d.y + eps))
	var dx = (h_x - h_c) / eps
	var dz = (h_z - h_c) / eps
	return Vector3(-dx, 1.0, -dz).normalized()


## Callbacks para VegetationScatter
func _height_callback(pos2d: Vector2) -> Dictionary:
	return {
		"height": get_terrain_height(pos2d),
		"normal": get_terrain_normal(pos2d)
	}

func _meadow_density_callback(pos2d: Vector2) -> float:
	# Máxima densidad en la cuenca abierta del prado (centro libre de árboles)
	var dist_center = Vector2(pos2d.x * 0.65, pos2d.y + 2.5).length()
	return clampf(1.0 - (dist_center / 14.0) * 0.75, 0.15, 1.0)

func _rose_density_callback(pos2d: Vector2) -> float:
	# Las rosas florecen en la cuenca soleada y en los flancos abiertos del prado
	if absf(pos2d.x) > 13.0 or pos2d.y < -13.0 or pos2d.y > 7.0:
		return 0.0
	var dist = Vector2(pos2d.x * 0.75, pos2d.y + 2.0).length()
	return clampf(1.0 - (dist / 11.5) * 0.8, 0.1, 1.0)


## Construye o regenera todo el escenario botánico
func _build_scene(seed_val: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	_generate_terrain_mesh()
	_populate_trees(rng)
	_populate_single_roses(rng)
	_populate_wildflowers_and_grass(rng)


## Genera la malla del terreno amplio (44m x 44m) con color de suelo y shader PSX
func _generate_terrain_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var grid_res: int = 56
	var size_x: float = 44.0
	var size_z: float = 44.0
	var half_x: float = size_x * 0.5
	var half_z: float = size_z * 0.5
	
	var col_grass := Color(0.14, 0.32, 0.11, 1.0)
	var col_dirt := Color(0.32, 0.22, 0.14, 1.0)
	
	for gz in range(grid_res):
		for gx in range(grid_res):
			var u0 = float(gx) / float(grid_res)
			var u1 = float(gx + 1) / float(grid_res)
			var v0 = float(gz) / float(grid_res)
			var v1 = float(gz + 1) / float(grid_res)
			
			var x0 = lerpf(-half_x, half_x, u0)
			var x1 = lerpf(-half_x, half_x, u1)
			var z0 = lerpf(-half_z, half_z, v0)
			var z1 = lerpf(-half_z, half_z, v1)
			
			var y00 = get_terrain_height(Vector2(x0, z0))
			var y10 = get_terrain_height(Vector2(x1, z0))
			var y01 = get_terrain_height(Vector2(x0, z1))
			var y11 = get_terrain_height(Vector2(x1, z1))
			
			var p00 := Vector3(x0, y00, z0)
			var p10 := Vector3(x1, y10, z0)
			var p01 := Vector3(x0, y01, z1)
			var p11 := Vector3(x1, y11, z1)
			
			# Suelo: pradera fértil en el valle central, mantillo terroso en los bordes altos
			var df00 = clampf((absf(x0) - 6.5) * 0.12 + (-z0 - 7.0) * 0.08, 0.0, 0.85)
			var df10 = clampf((absf(x1) - 6.5) * 0.12 + (-z0 - 7.0) * 0.08, 0.0, 0.85)
			var df01 = clampf((absf(x0) - 6.5) * 0.12 + (-z1 - 7.0) * 0.08, 0.0, 0.85)
			var df11 = clampf((absf(x1) - 6.5) * 0.12 + (-z1 - 7.0) * 0.08, 0.0, 0.85)
			
			var c00 = col_grass.lerp(col_dirt, df00)
			var c10 = col_grass.lerp(col_dirt, df10)
			var c01 = col_grass.lerp(col_dirt, df01)
			var c11 = col_grass.lerp(col_dirt, df11)
			
			st.set_color(c00); st.set_uv(Vector2(u0 * 14.0, v0 * 14.0)); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(Vector2(u1 * 14.0, v0 * 14.0)); st.add_vertex(p10)
			st.set_color(c01); st.set_uv(Vector2(u0 * 14.0, v1 * 14.0)); st.add_vertex(p01)
			
			st.set_color(c10); st.set_uv(Vector2(u1 * 14.0, v0 * 14.0)); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(Vector2(u1 * 14.0, v1 * 14.0)); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(Vector2(u0 * 14.0, v1 * 14.0)); st.add_vertex(p01)
	
	st.generate_normals()
	terrain_mesh.mesh = st.commit()
	
	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = preload("res://shaders/psx_vertex_snap.gdshader")
	terrain_mat.set_shader_parameter("grid_precision", 60)
	terrain_mat.set_shader_parameter("use_pixel_terrain", true)
	terrain_mat.set_shader_parameter("pixel_size", 0.08)
	terrain_mat.set_shader_parameter("grass_g1", Color(0.11, 0.26, 0.09, 1.0))
	terrain_mat.set_shader_parameter("grass_g2", Color(0.15, 0.34, 0.12, 1.0))
	terrain_mat.set_shader_parameter("grass_g3", Color(0.20, 0.44, 0.15, 1.0))
	terrain_mat.set_shader_parameter("grass_g4", Color(0.27, 0.54, 0.19, 1.0))
	terrain_mat.set_shader_parameter("grass_g5", Color(0.34, 0.64, 0.24, 1.0))
	terrain_mat.set_shader_parameter("dirt_d1", Color(0.18, 0.12, 0.08, 1.0))
	terrain_mat.set_shader_parameter("dirt_d2", Color(0.26, 0.18, 0.11, 1.0))
	terrain_mat.set_shader_parameter("dirt_d3", Color(0.34, 0.24, 0.15, 1.0))
	terrain_mat.set_shader_parameter("dirt_d4", Color(0.42, 0.31, 0.19, 1.0))
	terrain_mat.set_shader_parameter("dirt_d5", Color(0.50, 0.38, 0.24, 1.0))
	terrain_mat.set_shader_parameter("slope_cliff_threshold", 0.65)
	terrain_mat.set_shader_parameter("use_psx_color_depth", true)
	terrain_mat.set_shader_parameter("use_vertex_dirt", false)
	terrain_mesh.material_override = terrain_mat


## Genera las agrupaciones ecológicas de árboles con ProceduralTree enmarcando los laterales y el fondo
func _populate_trees(rng: RandomNumberGenerator) -> void:
	for child in trees_container.get_children():
		child.queue_free()
	
	var tree_data: Array[Dictionary] = []
	
	# 1. BOSQUE DENSO LATERAL IZQUIERDO (Enmarca la ladera izquierda, lejos del corredor central)
	var left_positions: Array[Vector2] = [
		Vector2(-9.2, -6.0), Vector2(-10.5, -7.5), Vector2(-8.6, -9.2),
		Vector2(-11.2, -9.8), Vector2(-7.8, -11.0), Vector2(-10.0, -12.5)
	]
	for i in range(left_positions.size()):
		var p = left_positions[i] + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
		tree_data.append({
			"pos": p,
			"profile": "pine_boreal" if i % 2 == 0 else "classic_oak",
			"scale": rng.randf_range(0.90, 1.18),
			"seed": rng.randi()
		})
		
	# 2. ARBOLEDA LATERAL DERECHA (Loma derecha lejana)
	var right_positions: Array[Vector2] = [
		Vector2(8.8, -6.5), Vector2(10.2, -8.2), Vector2(8.2, -9.8), Vector2(9.5, -11.5)
	]
	for i in range(right_positions.size()):
		var p = right_positions[i] + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
		tree_data.append({
			"pos": p,
			"profile": "pine_boreal" if i == 0 else "autumn_birch",
			"scale": rng.randf_range(0.85, 1.12),
			"seed": rng.randi()
		})
		
	# 3. PINO SOLITARIO ICÓNICO EN LA CRESTA DE FONDO (Silueta contra el cielo crepuscular)
	tree_data.append({
		"pos": Vector2(-5.5, -12.5),
		"profile": "pine_boreal",
		"scale": 1.25,
		"seed": 99991
	})
	
	for t in tree_data:
		var p2d: Vector2 = t["pos"]
		var ground_y = get_terrain_height(p2d)
		var tree := ProceduralTree.new()
		tree.profile_id = t["profile"]
		tree.tree_seed = t["seed"]
		tree.cast_shadows = true
		trees_container.add_child(tree)
		tree.position = Vector3(p2d.x, ground_y, p2d.y)
		var s: float = t["scale"]
		tree.scale = Vector3(s, s, s)


## PUEBLA LAS ROSAS PROCEDURALES ÚNICAS DEL PROYECTO (ProceduralFlower con perfil "solitary_rose")
## Cada flor es una rosa individual en su propio tallo leñoso con espinas, hojas serradas y pétalos aterciopelados.
func _ensure_rose_archetype_pool() -> void:
	if not _rose_archetype_pool.is_empty():
		return
	# Precalcula 18 arquetipos (6 paletas de color de FlowerProfiles x 3 variaciones de semilla)
	for c_idx in range(6):
		for s_idx in range(3):
			var s_val = 52000 + c_idx * 211 + s_idx * 79
			var pkg = ProceduralFlower.generate_package("solitary_rose", s_val, 1.0, c_idx)
			_rose_archetype_pool.append(pkg)

func _populate_single_roses(rng: RandomNumberGenerator) -> void:
	for child in roses_container.get_children():
		child.queue_free()
	
	_ensure_rose_archetype_pool()
	var pool_size := _rose_archetype_pool.size()
	
	# 1. ROSAS MACRO EN PRIMER PLANO (Para la vista macro cinematográfica [2])
	# Rosas únicas individuales de corte con máxima calidad LOD0 y variadas tonalidades
	var macro_configs: Array[Dictionary] = [
		{"pos": Vector2(-0.55, -1.45), "color": 0, "scale": 1.45, "rot": 0.25}, # Rojo Carmesí
		{"pos": Vector2(-0.35, -1.25), "color": 1, "scale": 1.40, "rot": -0.40}, # Rosa Coral / Salmón
		{"pos": Vector2(-0.75, -1.30), "color": 3, "scale": 1.32, "rot": 0.85}, # Blanco Marfil
		{"pos": Vector2(-0.48, -1.65), "color": 4, "scale": 1.36, "rot": -0.75}, # Amarillo Dorado
		{"pos": Vector2(-0.80, -1.60), "color": 2, "scale": 1.30, "rot": 1.10}, # Rosa Pastel
		{"pos": Vector2(-0.25, -1.50), "color": 5, "scale": 1.38, "rot": -1.20}, # Naranja Atardecer
		{"pos": Vector2(-0.62, -1.80), "color": 1, "scale": 1.32, "rot": 0.50}, # Coral
		{"pos": Vector2(-0.40, -1.85), "color": 0, "scale": 1.37, "rot": -0.30}, # Carmesí
		{"pos": Vector2(-0.90, -1.40), "color": 4, "scale": 1.28, "rot": 0.70}, # Dorado
		{"pos": Vector2(-0.15, -1.35), "color": 3, "scale": 1.30, "rot": -0.90}, # Blanco
		{"pos": Vector2(-0.70, -2.00), "color": 2, "scale": 1.34, "rot": 0.40}, # Pastel
		{"pos": Vector2(-0.30, -2.05), "color": 5, "scale": 1.32, "rot": -0.60}  # Naranja
	]
	
	for cfg in macro_configs:
		var p2d: Vector2 = cfg["pos"]
		var gy := get_terrain_height(p2d)
		var rose := ProceduralFlower.new()
		rose.name = "MacroSingleRose"
		rose.profile_id = "solitary_rose"
		rose.cast_shadows = true
		rose.wind_enabled = true
		rose.wind_strength = 0.20
		rose.disable_lod = true
		roses_container.add_child(rose)
		
		var c_idx: int = cfg["color"]
		var pkg_idx = (c_idx * 3 + (rng.randi() % 3)) % pool_size
		rose.apply_generation_package(_rose_archetype_pool[pkg_idx])
		rose.position = Vector3(p2d.x, gy, p2d.y)
		rose.rotation.y = cfg["rot"]
		var s: float = cfg["scale"]
		rose.scale = Vector3(s, s, s)

	# 2. PRADO DE ROSAS SOLITARIAS DISPERSAS (80 rosas individuales distribuidas en la cuenca floral)
	var meadow_center := Vector2(0.0, -2.5)
	var rose_count := 80
	var attempts := 0
	var spawned := 0
	while spawned < rose_count and attempts < 450:
		attempts += 1
		var angle = rng.randf_range(0.0, TAU)
		var dist = sqrt(rng.randf()) * 11.8
		var pos = meadow_center + Vector2(cos(angle) * dist * 1.12, sin(angle) * dist * 0.88)
		
		if (pos - Vector2(0.0, 3.5)).length() < 1.0:
			continue
		var d = _rose_density_callback(pos)
		if rng.randf() > d:
			continue
			
		var gy = get_terrain_height(pos)
		var rose := ProceduralFlower.new()
		rose.name = "MeadowSingleRose_%d" % spawned
		rose.profile_id = "solitary_rose"
		rose.cast_shadows = true
		rose.wind_enabled = true
		rose.wind_strength = 0.22
		rose.disable_lod = false
		rose.lod0_range_end = 12.0
		rose.lod1_range_end = 26.0
		rose.lod2_range_end = 65.0
		roses_container.add_child(rose)
		
		var pkg_idx = rng.randi() % pool_size
		rose.apply_generation_package(_rose_archetype_pool[pkg_idx])
		rose.position = Vector3(pos.x, gy, pos.y)
		rose.rotation.y = rng.randf_range(0.0, TAU)
		var s = rng.randf_range(1.15, 1.45)
		rose.scale = Vector3(s, s, s)
		spawned += 1


## Puebla el resto del ecosistema botánico: Césped denso, lavandas, margaritas y amapolas
func _populate_wildflowers_and_grass(rng: RandomNumberGenerator) -> void:
	for child in vegetation_container.get_children():
		child.queue_free()
	
	var height_cb = Callable(self, "_height_callback")
	var meadow_density_cb = Callable(self, "_meadow_density_callback")
	var meadow_center = Vector3(0.0, 0, -2.5)
	
	# 1. CÉSPED PSX: Manto exuberante de pasto verde en toda la cuenca
	_scatter_grass = VegetationScatter.new()
	_scatter_grass.name = "ScatterGrass"
	vegetation_container.add_child(_scatter_grass)
	
	if current_grass_mode == GrassMode.PSX_TEXTURE:
		var grass_mesh = PSXGrass.create_mesh(0.32)
		_scatter_grass.material_override = PSXGrass.get_material()
		_scatter_grass.min_scale = 0.65
		_scatter_grass.max_scale = 1.15
		_scatter_grass.populate_radial(grass_mesh, 1350, 14.5, meadow_center, height_cb, rng.randi(), meadow_density_cb)
	else:
		var grass_mesh = TriangleGrass.create_mesh(rng.randi())
		_scatter_grass.min_scale = 0.90
		_scatter_grass.max_scale = 1.50
		_scatter_grass.populate_radial(grass_mesh, 1200, 14.5, meadow_center, height_cb, rng.randi(), meadow_density_cb)
	
	# 2. ESPIGAS DE LAVANDA SILVESTRE (Laderas soleadas)
	_scatter_lavender = VegetationScatter.new()
	_scatter_lavender.name = "ScatterLavender"
	vegetation_container.add_child(_scatter_lavender)
	var lavender_mesh = WildLavender.create_mesh(rng.randi())
	_scatter_lavender.min_scale = 0.90
	_scatter_lavender.max_scale = 1.35
	_scatter_lavender.populate_radial(lavender_mesh, 240, 11.5, Vector3(1.2, 0, -3.8), height_cb, rng.randi(), meadow_density_cb)
	
	# 3. MARGARITAS BLANCAS SILVESTRES (Salpicadas en pradera abierta)
	_scatter_daisy = VegetationScatter.new()
	_scatter_daisy.name = "ScatterDaisies"
	vegetation_container.add_child(_scatter_daisy)
	var daisy_mesh = WildDaisy.create_mesh(rng.randi())
	_scatter_daisy.min_scale = 0.85
	_scatter_daisy.max_scale = 1.40
	_scatter_daisy.populate_radial(daisy_mesh, 300, 10.0, meadow_center, height_cb, rng.randi(), meadow_density_cb)
	
	# 4. AMAPOLAS SILVESTRES ROJAS (Acento floral vivo)
	_scatter_poppy = VegetationScatter.new()
	_scatter_poppy.name = "ScatterPoppies"
	vegetation_container.add_child(_scatter_poppy)
	var poppy_mesh = WildPoppy.create_mesh(rng.randi())
	_scatter_poppy.min_scale = 0.85
	_scatter_poppy.max_scale = 1.25
	_scatter_poppy.populate_radial(poppy_mesh, 100, 8.5, Vector3(0.5, 0, -2.0), height_cb, rng.randi(), meadow_density_cb)


## Configura los 4 puntos de vista cinematográficos perfeccionados
func _apply_camera_viewpoint(index: int) -> void:
	_viewpoint_index = index % 4
	match _viewpoint_index:
		0:
			# VISTA 0: Panorámica amplia del atardecer sobre el prado de rosas
			var target_2d := Vector2(0.0, -3.5)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 1.10, target_2d.y)
			_camera_distance = 7.6
			_camera_pitch = deg_to_rad(8.5)
			_camera_yaw = deg_to_rad(-6.0)
		1:
			# VISTA 1: Macro cinematográfico enfocado en ROSAS ÚNICAS individuales
			var target_2d := Vector2(-0.55, -1.45)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.38, target_2d.y)
			_camera_distance = 1.35
			_camera_pitch = deg_to_rad(7.0)
			_camera_yaw = deg_to_rad(-14.0)
		2:
			# VISTA 2: Valle floral en plano medio (campo denso de rosas, lavandas y margaritas)
			var target_2d := Vector2(2.5, -4.0)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.75, target_2d.y)
			_camera_distance = 4.2
			_camera_pitch = deg_to_rad(10.0)
			_camera_yaw = deg_to_rad(-32.0)
		3:
			# VISTA 3: Mirador de la loma (Perspectiva elevada del prado dorado y bosque crepuscular)
			var target_2d := Vector2(-1.5, -6.5)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 1.25, target_2d.y)
			_camera_distance = 5.8
			_camera_pitch = deg_to_rad(11.0)
			_camera_yaw = deg_to_rad(-52.0)
	
	_update_camera_transform()


func _update_camera_transform() -> void:
	var rot := Basis()
	rot = rot.rotated(Vector3.UP, _camera_yaw)
	rot = rot.rotated(rot.x, -_camera_pitch)
	camera.transform.basis = rot
	camera.transform.origin = rot * Vector3(0, 0, _camera_distance)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE:
			_current_seed = randi() % 1000000
			_build_scene(_current_seed)
			return
		
		# [1, 2, 3, 4]: Cambiar de vista
		if event.keycode == KEY_1:
			_apply_camera_viewpoint(0)
		elif event.keycode == KEY_2:
			_apply_camera_viewpoint(1)
		elif event.keycode == KEY_3:
			_apply_camera_viewpoint(2)
		elif event.keycode == KEY_4:
			_apply_camera_viewpoint(3)
		elif event.keycode == KEY_V:
			_apply_camera_viewpoint(_viewpoint_index + 1)
		elif event.keycode == KEY_G:
			current_grass_mode = GrassMode.TRIANGLE_PROCEDURAL if current_grass_mode == GrassMode.PSX_TEXTURE else GrassMode.PSX_TEXTURE
			_populate_wildflowers_and_grass(RandomNumberGenerator.new())
			print("[Showcase] Modo de césped cambiado a: ", "PSX_Grass (Textura FBX)" if current_grass_mode == GrassMode.PSX_TEXTURE else "TriangleGrass (Procedural)")
	
	# Control orbital de ratón
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_is_mouse_dragging = event.pressed
			_last_mouse_pos = event.position
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera_distance = maxf(_camera_distance - 0.35, 0.5)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera_distance = minf(_camera_distance + 0.45, 20.0)
			_update_camera_transform()
	
	if event is InputEventMouseMotion and _is_mouse_dragging:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_camera_yaw -= delta.x * 0.005
		_camera_pitch = clampf(_camera_pitch - delta.y * 0.005, deg_to_rad(-25.0), deg_to_rad(65.0))
		_update_camera_transform()
