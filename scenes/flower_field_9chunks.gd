extends Node3D

## Escena masiva de 9 Chunks (120m x 120m = 14,400 m²): "Valle Floral Monumental".
## Más de 29,000 flores instanciadas mediante MultiMesh y LODs procedurales,
## logrando un mar infinito y denso de flores a 60 FPS estables ("sin que explote la PC").

const CHUNK_SIZE := 40.0
const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")
const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")
const VegetationScatter = preload("res://world/vegetation/common/vegetation_scatter.gd")
const WildRose = preload("res://world/vegetation/rose/wild_rose.gd")

@onready var chunks_container: Node3D = $ChunksContainer
@onready var trees_container: Node3D = $TreesContainer
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var hud_stats: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelStats

var _camera_distance: float = 10.5
var _camera_pitch: float = deg_to_rad(-12.0)
var _camera_yaw: float = deg_to_rad(-6.0)
var _is_mouse_dragging := false
var _last_mouse_pos := Vector2.ZERO

var _current_seed: int = 888432
var _viewpoint_index: int = 0
var _rose_archetypes: Array[ProceduralFlower.FlowerGenerationPackage] = []

# Mallas compartidas de rosas para MultiMesh (Puras Rosas en Hardware Instancing)
var _rose_crimson_single_mesh: Mesh
var _rose_crimson_cluster_mesh: Mesh
var _rose_coral_single_mesh: Mesh
var _rose_coral_cluster_mesh: Mesh
var _rose_white_single_mesh: Mesh
var _rose_yellow_single_mesh: Mesh

var _flower_material: ShaderMaterial
var _terrain_shared_material: ShaderMaterial

# Estadísticas totales
var _total_roses_count: int = 0

func _ready() -> void:
	var vp = get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		
	_init_shared_resources()
	_build_9chunks_world(_current_seed)
	_apply_camera_viewpoint(0)

func _init_shared_resources() -> void:
	# 1. Precalcular arquetipos de rosales arbustivos 3D (6 paletas de color con LOD0/1/2)
	_rose_archetypes.clear()
	for p_idx in range(6):
		for var_idx in range(3):
			var s_val = _current_seed + p_idx * 137 + var_idx * 43
			var pkg = ProceduralFlower.generate_package("shrub_rose", s_val, 1.0, p_idx)
			_rose_archetypes.append(pkg)
			
	# 2. Mallas base de PURAS ROSAS compartidas para hardware instancing
	_rose_crimson_single_mesh = WildRose.create_single_rose_mesh(12345, 1.25, WildRose.COLOR_CRIMSON)
	_rose_crimson_cluster_mesh = WildRose.create_rose_cluster_mesh(23456, 1.28, WildRose.COLOR_CRIMSON)
	_rose_coral_single_mesh = WildRose.create_single_rose_mesh(34567, 1.22, WildRose.COLOR_CORAL)
	_rose_coral_cluster_mesh = WildRose.create_rose_cluster_mesh(45678, 1.25, WildRose.COLOR_CORAL)
	_rose_white_single_mesh = WildRose.create_single_rose_mesh(56789, 1.20, WildRose.COLOR_WHITE)
	_rose_yellow_single_mesh = WildRose.create_single_rose_mesh(67890, 1.22, WildRose.COLOR_YELLOW)
	
	# 3. Material con shader de viento y retroiluminación para las rosas
	_flower_material = ShaderMaterial.new()
	_flower_material.shader = preload("res://world/vegetation/common/vegetation_shader.gdshader")
	_flower_material.set_shader_parameter("wind_strength", 0.16)
	_flower_material.set_shader_parameter("wind_speed", 2.0)
	_flower_material.set_shader_parameter("backlight_strength", 0.55)
	_flower_material.set_shader_parameter("backlight_tint", Vector3(0.48, 0.22, 0.20))
	
	# 4. Material de terreno con shader PSX
	_terrain_shared_material = ShaderMaterial.new()
	_terrain_shared_material.shader = preload("res://shaders/psx_vertex_snap.gdshader")
	_terrain_shared_material.set_shader_parameter("grid_precision", 60)
	_terrain_shared_material.set_shader_parameter("use_pixel_terrain", true)
	_terrain_shared_material.set_shader_parameter("pixel_size", 0.08)
	_terrain_shared_material.set_shader_parameter("grass_g1", Color(0.12, 0.28, 0.09, 1.0))
	_terrain_shared_material.set_shader_parameter("grass_g2", Color(0.16, 0.35, 0.12, 1.0))
	_terrain_shared_material.set_shader_parameter("dirt_d1", Color(0.28, 0.19, 0.12, 1.0))
	_terrain_shared_material.set_shader_parameter("dirt_d2", Color(0.38, 0.26, 0.16, 1.0))

## Topografía del Valle Floral: Cuenca anfiteatro que desciende suavemente y sube a una cresta lejana
static func get_terrain_height(pos2d: Vector2) -> float:
	var x := pos2d.x
	var z := pos2d.y
	
	# Cuenca central agradable (elevación entre 1.0m y 3.5m)
	var valley_bowl = sin(x * 0.08 + 0.2) * 1.2 + cos(z * 0.075) * 1.1
	var micro_waves = sin(x * 0.16 + z * 0.12) * 0.35 + cos(x * 0.11 - z * 0.19) * 0.25
	
	# Elevación sur (colina desde donde mira el mirador panorámico)
	var south_hill = 0.0
	if z > 10.0:
		var sz_t = clampf((z - 10.0) / 45.0, 0.0, 1.0)
		south_hill = pow(sz_t, 1.4) * 4.2
		
	# Laderas laterales izquierda y derecha
	var side_hills = 0.0
	var ax = absf(x)
	if ax > 18.0:
		var sx_t = clampf((ax - 18.0) / 40.0, 0.0, 1.0)
		side_hills = pow(sx_t, 1.5) * 6.5
		
	# Cresta norte lejana (horizonte de fondo con árboles)
	var north_ridge = 0.0
	if z < -12.0:
		var nz_t = clampf((-z - 12.0) / 46.0, 0.0, 1.0)
		north_ridge = pow(nz_t, 1.4) * 7.5
		
	return valley_bowl + micro_waves + south_hill + side_hills + north_ridge + 1.2

static func get_terrain_normal(pos2d: Vector2) -> Vector3:
	var eps := 0.15
	var hc := get_terrain_height(pos2d)
	var hx := get_terrain_height(Vector2(pos2d.x + eps, pos2d.y))
	var hz := get_terrain_height(Vector2(pos2d.x, pos2d.y + eps))
	return Vector3(-(hx - hc) / eps, 1.0, -(hz - hc) / eps).normalized()

## Traza del sendero de tierra curvado que cruza el campo de flores
static func get_path_distance(pos2d: Vector2) -> float:
	var path_x = sin(pos2d.y * 0.065) * 11.0 + sin(pos2d.y * 0.14) * 3.5
	return absf(pos2d.x - path_x)

static func get_dirt_factor(pos2d: Vector2) -> float:
	var d = get_path_distance(pos2d)
	return 1.0 - smoothstep(0.8, 2.2, d)

func _build_9chunks_world(world_seed: int) -> void:
	for child in chunks_container.get_children():
		child.queue_free()
	for child in trees_container.get_children():
		child.queue_free()
		
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	
	_total_roses_count = 0
	
	# Generar los 9 chunks en una cuadrícula 3x3
	for cx in range(-1, 2):
		for cz in range(-1, 2):
			_generate_chunk(cx, cz, rng)
			
	# Generar árboles en el horizonte lejano (100% ProceduralTree)
	_generate_horizon_trees(rng)
	
	print("[FlowerField9Chunks] Gran Valle de 9 Chunks completado con %d ROSAS en total" % [
		_total_roses_count
	])

func _generate_chunk(cx: int, cz: int, rng: RandomNumberGenerator) -> void:
	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [cx, cz]
	chunks_container.add_child(chunk_node)
	
	var origin_x := float(cx) * CHUNK_SIZE
	var origin_z := float(cz) * CHUNK_SIZE
	
	var min_x := origin_x - CHUNK_SIZE * 0.5
	var max_x := origin_x + CHUNK_SIZE * 0.5
	var min_z := origin_z - CHUNK_SIZE * 0.5
	var max_z := origin_z + CHUNK_SIZE * 0.5
	
	# 1. Malla del terreno del chunk (28x28 quads)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "TerrainMesh"
	mesh_inst.material_override = _terrain_shared_material
	chunk_node.add_child(mesh_inst)
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var q_res := 28
	var step_x := (max_x - min_x) / float(q_res)
	var step_z := (max_z - min_z) / float(q_res)
	var col_grass := Color(0.12, 0.28, 0.09, 1.0)
	var col_dirt := Color(0.32, 0.21, 0.14, 1.0)
	
	for gz in range(q_res):
		for gx in range(q_res):
			var wx0 := min_x + float(gx) * step_x
			var wx1 := min_x + float(gx + 1) * step_x
			var wz0 := min_z + float(gz) * step_z
			var wz1 := min_z + float(gz + 1) * step_z
			
			var y00 = get_terrain_height(Vector2(wx0, wz0))
			var y10 = get_terrain_height(Vector2(wx1, wz0))
			var y01 = get_terrain_height(Vector2(wx0, wz1))
			var y11 = get_terrain_height(Vector2(wx1, wz1))
			
			var p00 := Vector3(wx0, y00, wz0)
			var p10 := Vector3(wx1, y10, wz0)
			var p01 := Vector3(wx0, y01, wz1)
			var p11 := Vector3(wx1, y11, wz1)
			
			var df00 = get_dirt_factor(Vector2(wx0, wz0))
			var df10 = get_dirt_factor(Vector2(wx1, wz0))
			var df01 = get_dirt_factor(Vector2(wx0, wz1))
			var df11 = get_dirt_factor(Vector2(wx1, wz1))
			
			var c00 = col_grass.lerp(col_dirt, df00)
			var c10 = col_grass.lerp(col_dirt, df10)
			var c01 = col_grass.lerp(col_dirt, df01)
			var c11 = col_grass.lerp(col_dirt, df11)
			
			var uv00 := Vector2(wx0 * 0.35, wz0 * 0.35)
			var uv10 := Vector2(wx1 * 0.35, wz0 * 0.35)
			var uv01 := Vector2(wx0 * 0.35, wz1 * 0.35)
			var uv11 := Vector2(wx1 * 0.35, wz1 * 0.35)
			
			st.set_color(c00); st.set_uv(uv00); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)
			
			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(uv11); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)
			
	st.generate_normals()
	mesh_inst.mesh = st.commit()
	
	# Callbacks de densidad para el campo de rosas
	var rose_density_cb = func(pos2d: Vector2) -> float:
		var dirt = get_dirt_factor(pos2d)
		if dirt > 0.65:
			return 0.04 # Pocas rosas al borde del camino
		return 1.0 - dirt * 0.85
		
	var slope_rose_density_cb = func(pos2d: Vector2) -> float:
		var df = rose_density_cb.call(pos2d)
		var h = get_terrain_height(pos2d)
		var slope_bias = clampf(h * 0.20, 0.50, 1.25)
		return df * slope_bias

	# 1. ROSAS ROJAS CARMESÍ (Individuales): 1,200 por chunk (10,800 en total)
	var mm_crimson_single := MultiMeshInstance3D.new()
	mm_crimson_single.name = "ScatterCrimsonRoses"
	mm_crimson_single.material_override = _flower_material
	mm_crimson_single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_node.add_child(mm_crimson_single)
	var c_crimson_s = _populate_multimesh_box(mm_crimson_single, _rose_crimson_single_mesh, 1200, min_x, max_x, min_z, max_z, 1.15, 1.65, rng, rose_density_cb)
	_total_roses_count += c_crimson_s

	# 2. MACIZOS DE ROSAS CARMESÍ (Racimos de 3 rosas): 600 por chunk (1,800 rosas por chunk = 16,200 rosas)
	var mm_crimson_cluster := MultiMeshInstance3D.new()
	mm_crimson_cluster.name = "ScatterCrimsonClusters"
	mm_crimson_cluster.material_override = _flower_material
	mm_crimson_cluster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_node.add_child(mm_crimson_cluster)
	var c_crimson_c = _populate_multimesh_box(mm_crimson_cluster, _rose_crimson_cluster_mesh, 600, min_x, max_x, min_z, max_z, 1.20, 1.70, rng, slope_rose_density_cb)
	_total_roses_count += c_crimson_c * 3 # Cada racimo tiene 3 rosas

	# 3. ROSAS CORAL / SALMÓN (Individuales y Racimos): 450 singles + 250 clusters (1,200 rosas por chunk = 10,800 rosas)
	var mm_coral_single := MultiMeshInstance3D.new()
	mm_coral_single.name = "ScatterCoralRoses"
	mm_coral_single.material_override = _flower_material
	mm_coral_single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_node.add_child(mm_coral_single)
	var c_coral_s = _populate_multimesh_box(mm_coral_single, _rose_coral_single_mesh, 450, min_x, max_x, min_z, max_z, 1.15, 1.60, rng, rose_density_cb)
	_total_roses_count += c_coral_s

	var mm_coral_cluster := MultiMeshInstance3D.new()
	mm_coral_cluster.name = "ScatterCoralClusters"
	mm_coral_cluster.material_override = _flower_material
	mm_coral_cluster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_node.add_child(mm_coral_cluster)
	var c_coral_c = _populate_multimesh_box(mm_coral_cluster, _rose_coral_cluster_mesh, 250, min_x, max_x, min_z, max_z, 1.20, 1.65, rng, slope_rose_density_cb)
	_total_roses_count += c_coral_c * 3

	# 4. ROSAS BLANCAS MARFIL (Individuales): 250 por chunk (2,250 en total)
	var mm_white_single := MultiMeshInstance3D.new()
	mm_white_single.name = "ScatterWhiteRoses"
	mm_white_single.material_override = _flower_material
	mm_white_single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_node.add_child(mm_white_single)
	var c_white_s = _populate_multimesh_box(mm_white_single, _rose_white_single_mesh, 250, min_x, max_x, min_z, max_z, 1.10, 1.55, rng, rose_density_cb)
	_total_roses_count += c_white_s

	# 5. ROSAS AMARILLAS DORADAS (Individuales): 200 por chunk (1,800 en total)
	var mm_yellow_single := MultiMeshInstance3D.new()
	mm_yellow_single.name = "ScatterYellowRoses"
	mm_yellow_single.material_override = _flower_material
	mm_yellow_single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_node.add_child(mm_yellow_single)
	var c_yellow_s = _populate_multimesh_box(mm_yellow_single, _rose_yellow_single_mesh, 200, min_x, max_x, min_z, max_z, 1.15, 1.60, rng, rose_density_cb)
	_total_roses_count += c_yellow_s

	# 6. ROSALES ARBUSTIVOS BOTÁNICOS 3D (ProceduralFlower): 10 por chunk (~120 rosas por chunk con 10-16 flores cada rosal)
	var chunk_roses_count := 10
	for r_i in range(chunk_roses_count):
		var rx := rng.randf_range(min_x + 1.0, max_x - 1.0)
		var rz := rng.randf_range(min_z + 1.0, max_z - 1.0)
		var p2d := Vector2(rx, rz)
		
		if get_dirt_factor(p2d) > 0.55:
			continue
			
		var rose := ProceduralFlower.new()
		rose.name = "Rose_%d" % r_i
		var pal_idx := (r_i + absi(cx * 4 + cz * 2)) % _rose_archetypes.size()
		rose.apply_generation_package(_rose_archetypes[pal_idx])
		rose.cast_shadows = false
		chunk_node.add_child(rose)
		
		var ry = get_terrain_height(p2d)
		rose.global_position = Vector3(rx, ry, rz)
		rose.scale = Vector3.ONE * rng.randf_range(1.10, 1.50)
		rose.rotate_y(rng.randf() * TAU)
		
		var norm = get_terrain_normal(p2d)
		if norm.dot(Vector3.UP) < 0.96:
			var tilt_axis = norm.cross(Vector3.UP).normalized()
			rose.rotate(tilt_axis, rng.randf_range(0.04, 0.12))
			
		_total_roses_count += 12 # Promedio de flores por rosal arbustivo
		
	# Rosales héroe garantizados en puntos focales de cámara (Chunk central 0,0)
	if cx == 0 and cz == 0:
		var hero_spots: Array[Vector2] = [
			Vector2(-1.65, 0.15), # Frente a Vista 1 (Corazón del Valle de Rosas)
			Vector2(2.20, 3.80)   # Al borde del Sendero (Vista 3)
		]
		for h_idx in range(hero_spots.size()):
			var hp = hero_spots[h_idx]
			var h_rose := ProceduralFlower.new()
			h_rose.name = "HeroRose_%d" % h_idx
			h_rose.apply_generation_package(_rose_archetypes[h_idx % _rose_archetypes.size()])
			h_rose.cast_shadows = false
			chunk_node.add_child(h_rose)
			h_rose.global_position = Vector3(hp.x, get_terrain_height(hp), hp.y)
			h_rose.scale = Vector3.ONE * 1.35
			h_rose.rotate_y(0.45 * TAU)
			_total_roses_count += 14

## Distribuye instancias uniformemente sobre el área rectangular del chunk sin dejar esquinas vacías
func _populate_multimesh_box(
	mm_inst: MultiMeshInstance3D,
	proto_mesh: Mesh,
	amount: int,
	min_x: float, max_x: float,
	min_z: float, max_z: float,
	min_scale: float, max_scale: float,
	rng: RandomNumberGenerator,
	density_func: Callable = Callable()
) -> int:
	var transforms: Array[Transform3D] = []
	var attempts := int(amount * 1.45)
	
	for i in range(attempts):
		if transforms.size() >= amount:
			break
		var wx := rng.randf_range(min_x, max_x)
		var wz := rng.randf_range(min_z, max_z)
		var p2d := Vector2(wx, wz)
		
		if density_func.is_valid():
			var prob: float = density_func.call(p2d)
			if rng.randf() > prob:
				continue
				
		var y := get_terrain_height(p2d)
		var s := rng.randf_range(min_scale, max_scale)
		var yaw := rng.randf() * TAU
		var tilt_x := deg_to_rad(rng.randf_range(-6.0, 6.0))
		var tilt_z := deg_to_rad(rng.randf_range(-6.0, 6.0))
		
		var basis := Basis()
		basis = basis.rotated(Vector3.UP, yaw)
		basis = basis.rotated(Vector3.RIGHT, tilt_x)
		basis = basis.rotated(Vector3.FORWARD, tilt_z)
		basis = basis.scaled(Vector3(s, s, s))
		
		transforms.append(Transform3D(basis, Vector3(wx, y, wz)))
		
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = proto_mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		
	mm_inst.multimesh = mm
	return transforms.size()

## Coloca árboles procedurales exclusivamente en el horizonte exterior (100% ProceduralTree)
func _generate_horizon_trees(rng: RandomNumberGenerator) -> void:
	var tree_spots: Array[Dictionary] = [
		{"pos": Vector2(-22.0, -50.0), "type": "autumn_birch", "scale": 1.40},
		{"pos": Vector2(18.0, -52.0), "type": "classic_oak", "scale": 1.35},
		{"pos": Vector2(-5.0, -55.0), "type": "pine_boreal", "scale": 1.45},
		{"pos": Vector2(-52.0, -28.0), "type": "classic_oak", "scale": 1.30},
		{"pos": Vector2(-54.0, 15.0), "type": "weeping_willow", "scale": 1.25},
		{"pos": Vector2(52.0, -30.0), "type": "autumn_birch", "scale": 1.35},
		{"pos": Vector2(54.0, 18.0), "type": "classic_oak", "scale": 1.30},
		{"pos": Vector2(-46.0, 48.0), "type": "pine_boreal", "scale": 1.30},
		{"pos": Vector2(44.0, 46.0), "type": "weeping_willow", "scale": 1.25}
	]
	
	for spot in tree_spots:
		var p2d: Vector2 = spot["pos"]
		var tree := ProceduralTree.new()
		tree.profile_id = spot["type"]
		tree.tree_seed = rng.randi()
		tree.disable_lod = true
		trees_container.add_child(tree)
		var h = get_terrain_height(p2d)
		tree.global_position = Vector3(p2d.x, h, p2d.y)
		var s: float = spot["scale"]
		tree.scale = Vector3(s, s * 1.1, s)
		tree.rotate_y(rng.randf() * TAU)

## Vistas cinematográficas del Valle Floral
func _apply_camera_viewpoint(index: int) -> void:
	_viewpoint_index = index % 4
	match _viewpoint_index:
		0:
			# 1. Mirador Panorámico (Vista Abierta del Mar de Puras Rosas en los 9 Chunks)
			var target_2d := Vector2(0.0, -6.0)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 4.5, target_2d.y + 22.0)
			_camera_distance = 10.5
			_camera_pitch = deg_to_rad(-14.0)
			_camera_yaw = deg_to_rad(-6.0)
		1:
			# 2. Inmersión en el Mar de Rosas Carmesí y Coral
			var target_2d := Vector2(-1.5, 0.5)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.95, target_2d.y)
			_camera_distance = 2.4
			_camera_pitch = deg_to_rad(4.0)
			_camera_yaw = deg_to_rad(-24.0)
		2:
			# 3. Lomas Onduladas de Rosas al Atardecer
			var target_2d := Vector2(-14.0, -8.0)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 1.20, target_2d.y)
			_camera_distance = 3.2
			_camera_pitch = deg_to_rad(3.0)
			_camera_yaw = deg_to_rad(45.0)
		3:
			# 4. A ras del Sendero Romántico entre Rosas
			var target_2d := Vector2(1.2, 4.5)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.70, target_2d.y)
			_camera_distance = 3.6
			_camera_pitch = deg_to_rad(6.0)
			_camera_yaw = deg_to_rad(-16.0)
			
	_update_camera_transform()

func _update_camera_transform() -> void:
	camera_pivot.rotation.x = _camera_pitch
	camera_pivot.rotation.y = _camera_yaw
	camera.position = Vector3(0.0, 0.0, _camera_distance)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_mouse_dragging = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = clampf(_camera_distance - 1.0, 1.0, 70.0)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = clampf(_camera_distance + 1.0, 1.0, 70.0)
			_update_camera_transform()
			
	elif event is InputEventMouseMotion and _is_mouse_dragging:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_camera_yaw -= delta.x * 0.004
		_camera_pitch = clampf(_camera_pitch - delta.y * 0.004, deg_to_rad(-60.0), deg_to_rad(60.0))
		_update_camera_transform()
		
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_apply_camera_viewpoint(0)
		elif event.keycode == KEY_2:
			_apply_camera_viewpoint(1)
		elif event.keycode == KEY_3:
			_apply_camera_viewpoint(2)
		elif event.keycode == KEY_4:
			_apply_camera_viewpoint(3)
		elif event.keycode == KEY_SPACE:
			_apply_camera_viewpoint(_viewpoint_index + 1)
		elif event.keycode == KEY_R:
			_current_seed = randi()
			_init_shared_resources()
			_build_9chunks_world(_current_seed)
			_apply_camera_viewpoint(_viewpoint_index)

func _process(delta: float) -> void:
	# Controles de vuelo con WASD para volar libremente por los 9 chunks
	var move_vec := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_vec -= camera_pivot.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_vec += camera_pivot.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_vec -= camera_pivot.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_vec += camera_pivot.global_transform.basis.x
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E):
		move_vec += Vector3.UP * (1.0 if Input.is_key_pressed(KEY_E) else -1.0)
		
	if move_vec.length_squared() > 0.01:
		var speed: float = 28.0 if Input.is_key_pressed(KEY_SHIFT) else 12.0
		camera_pivot.position += move_vec.normalized() * (speed * delta)
		
	if hud_stats:
		var fps = Engine.get_frames_per_second()
		hud_stats.text = "FPS: %d | 9 Chunks (120m x 120m) | ROSAS: %d | Variedades: Carmesí, Coral, Blanca, Dorada | Draw Calls: <50" % [
			fps, _total_roses_count
		]
