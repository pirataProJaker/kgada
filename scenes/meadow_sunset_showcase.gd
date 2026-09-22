extends Node3D

## Controlador de la escena de paisaje natural al atardecer (Meadow Sunset Showcase).
## Recrea un ecosistema botánico y geográfico completo con ecología procedural:
## - Agrupaciones de árboles (bosque denso, arboleda pequeña, árbol solitario en cresta)
## - Tipos de suelo diferenciados (césped fértil vs. tierra/mantillo forestal y senderos)
## - Vegetación ecológica: pasto FBX adaptativo (ralo en tierra, denso en pradera) y flores solares en claros.

const VegetationScatter = preload("res://world/vegetation/common/vegetation_scatter.gd")
const WildDaisy = preload("res://world/vegetation/daisy/wild_daisy.gd")
const WildLavender = preload("res://world/vegetation/lavender/wild_lavender.gd")
const TriangleGrass = preload("res://world/vegetation/grass/triangle_grass.gd")
const PSXGrass = preload("res://world/vegetation/grass/psx_grass.gd")
const WildPoppy = preload("res://world/vegetation/poppy/wild_poppy.gd")
const TerrainEcology = preload("res://world/vegetation/common/terrain_ecology.gd")
const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")

enum GrassMode { PSX_TEXTURE, TRIANGLE_PROCEDURAL }
var current_grass_mode: GrassMode = GrassMode.PSX_TEXTURE

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var terrain_mesh: MeshInstance3D = $Terrain
@onready var trees_container: Node3D = $Trees
@onready var vegetation_container: Node3D = $Vegetation

var _rocks_container: Node3D

# Nodos MultiMesh de vegetación
var _scatter_grass: VegetationScatter
var _scatter_lavender: VegetationScatter
var _scatter_daisy: VegetationScatter
var _scatter_poppy: VegetationScatter

# Administrador ecológico de suelos y árboles
var _ecology: TerrainEcology

# Control de cámara orbital
var _camera_distance: float = 7.5
var _camera_pitch: float = deg_to_rad(8.0)
var _camera_yaw: float = deg_to_rad(-18.0)
var _is_mouse_dragging := false
var _last_mouse_pos := Vector2.ZERO

var _current_seed: int = 45678
var _viewpoint_index: int = 0 # 0 = Panorámica, 1 = Bosque/Tierra, 2 = Lavandas, 3 = Margaritas

func _ready() -> void:
	# Configurar antialiasing para vegetación fina
	var vp = get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	
	_rocks_container = Node3D.new()
	_rocks_container.name = "Rocks"
	add_child(_rocks_container)
	
	_build_scene(_current_seed)
	_apply_camera_viewpoint(0)

## Función matemática de elevación de la loma para alinear árboles y vegetación con precisión
static func get_terrain_height(pos2d: Vector2) -> float:
	var x = pos2d.x
	var z = pos2d.y
	
	# Cresta principal que sube suavemente hacia el fondo (z negativo) y la izquierda
	var hill1 = exp(-((x + 1.8) * (x + 1.8) * 0.04 + (z + 4.5) * (z + 4.5) * 0.025)) * 3.4
	# Loma secundaria suave a la derecha
	var hill2 = exp(-((x - 4.5) * (x - 4.5) * 0.05 + (z + 2.0) * (z + 2.0) * 0.04)) * 1.8
	# Ondulación natural sutil
	var ridge = sin(x * 0.35 + z * 0.25) * 0.35 - (z * 0.12)
	
	return hill1 + hill2 + ridge

## Normal analítica de la superficie para orientar rocas o vegetación
static func get_terrain_normal(pos2d: Vector2) -> Vector3:
	var eps: float = 0.1
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

func _grass_density_callback(pos2d: Vector2) -> float:
	if _ecology:
		return _ecology.get_soil_info(pos2d)["grass_density"]
	return 1.0

func _flower_density_callback(pos2d: Vector2) -> float:
	if _ecology:
		return _ecology.get_soil_info(pos2d)["flower_density"]
	return 1.0

## Construye o regenera el terreno, árboles y vegetación
func _build_scene(seed_val: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	# 1. Configurar ecología (árboles, manchas de tierra, claros)
	_ecology = TerrainEcology.new(seed_val)
	_ecology.generate_layout()
	
	# 2. Generar elementos del mundo
	_generate_terrain_mesh()
	_populate_trees()
	_populate_field_rocks(rng)
	_populate_vegetation_multimesh(rng)

## Genera la malla del terreno orgánico con la función de relieve y tipos de suelo (COLOR.r = tierra)
func _generate_terrain_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var grid_res: int = 54
	var size_x: float = 24.0
	var size_z: float = 24.0
	var half_x: float = size_x * 0.5
	var half_z: float = size_z * 0.5
	
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
			
			# Consultar el factor de tierra (0.0 = césped verde, 1.0 = tierra/mantillo)
			var soil00 = _ecology.get_soil_info(Vector2(x0, z0))
			var soil10 = _ecology.get_soil_info(Vector2(x1, z0))
			var soil01 = _ecology.get_soil_info(Vector2(x0, z1))
			var soil11 = _ecology.get_soil_info(Vector2(x1, z1))
			
			var col00 := Color(soil00["dirt_factor"], 0.0, 0.0, 1.0)
			var col10 := Color(soil10["dirt_factor"], 0.0, 0.0, 1.0)
			var col01 := Color(soil01["dirt_factor"], 0.0, 0.0, 1.0)
			var col11 := Color(soil11["dirt_factor"], 0.0, 0.0, 1.0)
			
			# Quad triangulado con UVs y Color de Suelo
			st.set_color(col00); st.set_uv(Vector2(u0 * 8.0, v0 * 8.0)); st.add_vertex(p00)
			st.set_color(col10); st.set_uv(Vector2(u1 * 8.0, v0 * 8.0)); st.add_vertex(p10)
			st.set_color(col01); st.set_uv(Vector2(u0 * 8.0, v1 * 8.0)); st.add_vertex(p01)
			
			st.set_color(col10); st.set_uv(Vector2(u1 * 8.0, v0 * 8.0)); st.add_vertex(p10)
			st.set_color(col11); st.set_uv(Vector2(u1 * 8.0, v1 * 8.0)); st.add_vertex(p11)
			st.set_color(col01); st.set_uv(Vector2(u0 * 8.0, v1 * 8.0)); st.add_vertex(p01)
	
	st.generate_normals()
	terrain_mesh.mesh = st.commit()
	
	# Material de terreno PSX con pixelado de pasto, tierra y acantilados
	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = preload("res://shaders/psx_vertex_snap.gdshader")
	terrain_mat.set_shader_parameter("grid_precision", 60)
	terrain_mat.set_shader_parameter("use_pixel_terrain", true)
	terrain_mat.set_shader_parameter("pixel_size", 0.08)
	terrain_mat.set_shader_parameter("grass_g1", Color(0.10, 0.24, 0.08, 1.0))
	terrain_mat.set_shader_parameter("grass_g2", Color(0.14, 0.32, 0.11, 1.0))
	terrain_mat.set_shader_parameter("grass_g3", Color(0.19, 0.42, 0.14, 1.0))
	terrain_mat.set_shader_parameter("grass_g4", Color(0.25, 0.52, 0.18, 1.0))
	terrain_mat.set_shader_parameter("grass_g5", Color(0.32, 0.62, 0.22, 1.0))
	terrain_mat.set_shader_parameter("dirt_d1", Color(0.15, 0.10, 0.06, 1.0))
	terrain_mat.set_shader_parameter("dirt_d2", Color(0.22, 0.15, 0.09, 1.0))
	terrain_mat.set_shader_parameter("dirt_d3", Color(0.30, 0.21, 0.13, 1.0))
	terrain_mat.set_shader_parameter("dirt_d4", Color(0.38, 0.28, 0.17, 1.0))
	terrain_mat.set_shader_parameter("dirt_d5", Color(0.47, 0.35, 0.22, 1.0))
	terrain_mat.set_shader_parameter("slope_cliff_threshold", 0.65)
	terrain_mat.set_shader_parameter("use_psx_color_depth", true)
	terrain_mat.set_shader_parameter("use_vertex_dirt", true)
	terrain_mesh.material_override = terrain_mat

## Genera las agrupaciones ecológicas de árboles usando ProceduralTree (regla estricta del proyecto)
func _populate_trees() -> void:
	for child in trees_container.get_children():
		child.queue_free()
	
	for t in _ecology.trees:
		var pos2d: Vector2 = t["position"]
		var ground_y = get_terrain_height(pos2d)
		var tree := ProceduralTree.new()
		tree.profile_id = t["profile_id"]
		tree.tree_seed = t["seed_val"]
		tree.cast_shadows = true
		trees_container.add_child(tree)
		tree.position = Vector3(pos2d.x, ground_y, pos2d.y)
		var s: float = t["scale"]
		tree.scale = Vector3(s, s, s)

## Genera rocas low-poly integradas en el terreno
func _populate_field_rocks(rng: RandomNumberGenerator) -> void:
	for child in _rocks_container.get_children():
		child.queue_free()
	
	var rock_positions: Array[Vector2] = [
		Vector2(-1.4, -3.4),
		Vector2(2.8, -4.2),
		Vector2(0.5, -5.2),
		Vector2(-4.8, -4.0) # Roca dentro del bosque
	]
	
	for r_pos in rock_positions:
		var r_y = get_terrain_height(r_pos) - 0.15
		var rock_mesh = _create_lowpoly_rock(rng.randi())
		var mi = MeshInstance3D.new()
		mi.mesh = rock_mesh
		_rocks_container.add_child(mi)
		mi.position = Vector3(r_pos.x, r_y, r_pos.y)
		mi.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, rng.randf_range(-0.1, 0.1))
		var s = rng.randf_range(0.85, 1.45)
		mi.scale = Vector3(s, s * 0.75, s)

func _create_lowpoly_rock(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_rock_top := Color(0.38, 0.36, 0.32)
	var col_rock_base := Color(0.24, 0.22, 0.19)
	var col_moss := Color(0.26, 0.32, 0.16)
	
	var r: float = 0.55
	var phi: float = (1.0 + sqrt(5.0)) * 0.5
	var base_v: Array[Vector3] = [
		Vector3(-1,  phi, 0).normalized() * r,
		Vector3( 1,  phi, 0).normalized() * r,
		Vector3(-1, -phi, 0).normalized() * r,
		Vector3( 1, -phi, 0).normalized() * r,
		Vector3(0, -1,  phi).normalized() * r,
		Vector3(0,  1,  phi).normalized() * r,
		Vector3(0, -1, -phi).normalized() * r,
		Vector3(0,  1, -phi).normalized() * r,
		Vector3( phi, 0, -1).normalized() * r,
		Vector3( phi, 0,  1).normalized() * r,
		Vector3(-phi, 0, -1).normalized() * r,
		Vector3(-phi, 0,  1).normalized() * r
	]
	
	for i in range(base_v.size()):
		var jitter = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.15, 0.15))
		base_v[i] += jitter
	
	var faces: Array[int] = [
		0, 11, 5,   0, 5, 1,    0, 1, 7,    0, 7, 10,   0, 10, 11,
		1, 5, 9,    5, 11, 4,   11, 10, 2,  10, 7, 6,   7, 1, 8,
		3, 9, 4,    3, 4, 2,    3, 2, 6,    3, 6, 8,    3, 8, 9,
		4, 9, 5,    2, 4, 11,   6, 2, 10,   8, 6, 7,    9, 8, 1
	]
	
	for f in range(0, faces.size(), 3):
		var v0 = base_v[faces[f]]
		var v1 = base_v[faces[f + 1]]
		var v2 = base_v[faces[f + 2]]
		var avg_y = (v0.y + v1.y + v2.y) / 3.0
		var c = col_rock_top.lerp(col_rock_base, clampf(-avg_y / r, 0.0, 1.0))
		if avg_y > 0.1:
			c = c.lerp(col_moss, 0.45)
		st.set_color(c); st.add_vertex(v0)
		st.set_color(c); st.add_vertex(v1)
		st.set_color(c); st.add_vertex(v2)
	
	st.generate_normals()
	return st.commit()

## Distribuye la vegetación respetando las reglas ecológicas de suelo y árboles
func _populate_vegetation_multimesh(rng: RandomNumberGenerator) -> void:
	for child in vegetation_container.get_children():
		child.queue_free()
	
	var height_cb = Callable(self, "_height_callback")
	var grass_density_cb = Callable(self, "_grass_density_callback")
	var flower_density_cb = Callable(self, "_flower_density_callback")
	
	# 1. CÉSPED FBX: Se adapta al suelo (denso en pradera verde, ralo en tierra bajo árboles)
	_scatter_grass = VegetationScatter.new()
	_scatter_grass.name = "ScatterGrass"
	vegetation_container.add_child(_scatter_grass)
	
	if current_grass_mode == GrassMode.PSX_TEXTURE:
		var grass_mesh = PSXGrass.create_mesh(0.32)
		_scatter_grass.material_override = PSXGrass.get_material()
		_scatter_grass.min_scale = 0.55
		_scatter_grass.max_scale = 1.05
		_scatter_grass.populate_radial(grass_mesh, 950, 11.5, Vector3(0, 0, -2.8), height_cb, rng.randi(), grass_density_cb)
	else:
		var grass_mesh = TriangleGrass.create_mesh(rng.randi())
		_scatter_grass.min_scale = 0.85
		_scatter_grass.max_scale = 1.45
		_scatter_grass.populate_radial(grass_mesh, 850, 11.5, Vector3(0, 0, -2.8), height_cb, rng.randi(), grass_density_cb)
	
	# 2. ESPIGAS DE LAVANDA SILVESTRE (concentradas en cresta soleada libre de árboles)
	_scatter_lavender = VegetationScatter.new()
	_scatter_lavender.name = "ScatterLavender"
	vegetation_container.add_child(_scatter_lavender)
	var lavender_mesh = WildLavender.create_mesh(rng.randi())
	_scatter_lavender.min_scale = 0.90
	_scatter_lavender.max_scale = 1.35
	_scatter_lavender.populate_radial(lavender_mesh, 180, 7.5, Vector3(0.5, 0, -3.6), height_cb, rng.randi(), flower_density_cb)
	
	# 3. MARGARITAS BLANCAS SILVESTRES (pradera abierta soleada, nunca en tierra bajo copa)
	_scatter_daisy = VegetationScatter.new()
	_scatter_daisy.name = "ScatterDaisies"
	vegetation_container.add_child(_scatter_daisy)
	var daisy_mesh = WildDaisy.create_mesh(rng.randi())
	_scatter_daisy.min_scale = 0.85
	_scatter_daisy.max_scale = 1.40
	_scatter_daisy.populate_radial(daisy_mesh, 260, 5.5, Vector3(0.0, 0, -2.0), height_cb, rng.randi(), flower_density_cb)
	
	# 4. AMAPOLAS SILVESTRES ROJAS (acento vivo en claros de pradera)
	_scatter_poppy = VegetationScatter.new()
	_scatter_poppy.name = "ScatterPoppies"
	vegetation_container.add_child(_scatter_poppy)
	var poppy_mesh = WildPoppy.create_mesh(rng.randi())
	_scatter_poppy.min_scale = 0.85
	_scatter_poppy.max_scale = 1.25
	_scatter_poppy.populate_radial(poppy_mesh, 75, 4.5, Vector3(0.5, 0, -1.8), height_cb, rng.randi(), flower_density_cb)

## Configura puntos de vista cinematográficos predefinidos
func _apply_camera_viewpoint(index: int) -> void:
	_viewpoint_index = index % 4
	match _viewpoint_index:
		0:
			# Vista panorámica hacia la cresta con bosque, pinos, loma y atardecer
			var target_2d := Vector2(0.0, -3.2)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.60, target_2d.y)
			_camera_distance = 6.2
			_camera_pitch = deg_to_rad(6.0)
			_camera_yaw = deg_to_rad(-16.0)
		1:
			# Vista del interior del bosque y suelo de tierra/mantillo bajo los árboles
			var target_2d := Vector2(-5.0, -4.8)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.35, target_2d.y)
			_camera_distance = 2.0
			_camera_pitch = deg_to_rad(25.0)
			_camera_yaw = deg_to_rad(20.0)
		2:
			# Primer plano de la espiga de lavanda silvestre y césped en ladera
			var target_2d := Vector2(0.8, -3.4)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.50, target_2d.y)
			_camera_distance = 1.30
			_camera_pitch = deg_to_rad(5.0)
			_camera_yaw = deg_to_rad(-20.0)
		3:
			# Primer plano cenital de las margaritas blancas sobre el pasto verde en el claro
			var target_2d := Vector2(-1.2, -1.8)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.25, target_2d.y)
			_camera_distance = 0.90
			_camera_pitch = deg_to_rad(40.0)
			_camera_yaw = deg_to_rad(8.0)
	
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
			_populate_vegetation_multimesh(RandomNumberGenerator.new())
			print("[Showcase] Modo de césped cambiado a: ", "PSX_Grass (Textura FBX)" if current_grass_mode == GrassMode.PSX_TEXTURE else "TriangleGrass (Procedural)")
	
	# Control orbital de ratón
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_is_mouse_dragging = event.pressed
			_last_mouse_pos = event.position
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera_distance = maxf(_camera_distance - 0.4, 0.6)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera_distance = minf(_camera_distance + 0.5, 20.0)
			_update_camera_transform()
	
	if event is InputEventMouseMotion and _is_mouse_dragging:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_camera_yaw -= delta.x * 0.005
		_camera_pitch = clampf(_camera_pitch - delta.y * 0.005, deg_to_rad(-25.0), deg_to_rad(65.0))
		_update_camera_transform()
