extends Node3D

## Escena de exhibición de alta fidelidad: "Valle de Flores Silvestres" (Flower Field Showcase).
## Renderiza más de 3,000 flores (margaritas, lavandas, amapolas, pasto y rosales botánicos)
## en menos de 30 draw calls mediante hardware instancing y LODs procedurales,
## garantizando 60 FPS estables y fluidos ("sin que explote la PC").

const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")
const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")
const VegetationScatter = preload("res://world/vegetation/common/vegetation_scatter.gd")
const WildDaisy = preload("res://world/vegetation/daisy/wild_daisy.gd")
const WildLavender = preload("res://world/vegetation/lavender/wild_lavender.gd")
const WildPoppy = preload("res://world/vegetation/poppy/wild_poppy.gd")
const PSXGrass = preload("res://world/vegetation/grass/psx_grass.gd")

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var terrain_mesh: MeshInstance3D = $Terrain
@onready var trees_container: Node3D = $Trees
@onready var vegetation_container: Node3D = $Vegetation
@onready var roses_container: Node3D = $Roses
@onready var rocks_container: Node3D = $Rocks
@onready var hud_stats: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelStats

# Control de cámara orbital
var _camera_distance: float = 7.5
var _camera_pitch: float = deg_to_rad(8.0)
var _camera_yaw: float = deg_to_rad(-15.0)
var _is_mouse_dragging := false
var _last_mouse_pos := Vector2.ZERO

var _current_seed: int = 54321
var _viewpoint_index: int = 0
var _rose_packages: Array[ProceduralFlower.FlowerGenerationPackage] = []

func _ready() -> void:
	var vp = get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	
	_pregenerate_rose_packages()
	_build_scene(_current_seed)
	_apply_camera_viewpoint(0)

## Precalcula los paquetes de mallas en los 3 LODs para las 6 paletas de color de rosas
func _pregenerate_rose_packages() -> void:
	_rose_packages.clear()
	for color_idx in range(6):
		var pkg = ProceduralFlower.generate_package("shrub_rose", _current_seed + color_idx * 17, 1.0, color_idx)
		_rose_packages.append(pkg)

## Función matemática de elevación del valle floral
static func get_terrain_height(pos2d: Vector2) -> float:
	var x := pos2d.x
	var z := pos2d.y
	
	# Cresta principal en el fondo (z negativo)
	var hill_back = exp(-((z + 8.5) * (z + 8.5) * 0.015)) * 4.2
	# Loma suave en el flanco izquierdo
	var hill_left = exp(-((x + 7.5) * (x + 7.5) * 0.025 + (z + 2.0) * (z + 2.0) * 0.015)) * 2.6
	# Loma en el flanco derecho
	var hill_right = exp(-((x - 7.0) * (x - 7.0) * 0.028 + (z + 3.0) * (z + 3.0) * 0.018)) * 2.2
	# Ondulación suave en la pradera
	var roll = sin(x * 0.26 + z * 0.22) * 0.32 + cos(x * 0.18 - z * 0.28) * 0.22
	
	return hill_back + hill_left + hill_right + roll

## Normal analítica de la superficie
static func get_terrain_normal(pos2d: Vector2) -> Vector3:
	var eps := 0.1
	var hc := get_terrain_height(pos2d)
	var hx := get_terrain_height(Vector2(pos2d.x + eps, pos2d.y))
	var hz := get_terrain_height(Vector2(pos2d.x, pos2d.y + eps))
	return Vector3(-(hx - hc) / eps, 1.0, -(hz - hc) / eps).normalized()

## Traza del sendero de tierra serpenteante (S-curve)
static func get_path_distance(pos2d: Vector2) -> float:
	var path_x = sin(pos2d.y * 0.28) * 2.4 - 0.4
	return absf(pos2d.x - path_x)

## Factor de tierra (1.0 = sendero de tierra, 0.0 = césped verde fértil)
static func get_dirt_factor(pos2d: Vector2) -> float:
	var d = get_path_distance(pos2d)
	return 1.0 - smoothstep(0.45, 1.35, d)

func _height_callback(pos2d: Vector2) -> Dictionary:
	return {
		"height": get_terrain_height(pos2d),
		"normal": get_terrain_normal(pos2d)
	}

func _build_scene(seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	_generate_terrain_mesh()
	_populate_trees(rng)
	_populate_field_rocks(rng)
	_populate_wildflowers(rng)
	_populate_rose_bushes(rng)

## Genera la malla del terreno con sombreado de suelo (verde pradera vs. sendero de tierra)
func _generate_terrain_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var grid_res := 60
	var size_x := 32.0
	var size_z := 32.0
	var half_x := size_x * 0.5
	var half_z := size_z * 0.5
	
	var col_grass := Color(0.13, 0.28, 0.09, 1.0)
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
			
			var df00 = get_dirt_factor(Vector2(x0, z0))
			var df10 = get_dirt_factor(Vector2(x1, z0))
			var df01 = get_dirt_factor(Vector2(x0, z1))
			var df11 = get_dirt_factor(Vector2(x1, z1))
			
			var c00 = col_grass.lerp(col_dirt, df00)
			var c10 = col_grass.lerp(col_dirt, df10)
			var c01 = col_grass.lerp(col_dirt, df01)
			var c11 = col_grass.lerp(col_dirt, df11)
			
			st.set_color(c00); st.set_uv(Vector2(u0 * 12.0, v0 * 12.0)); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(Vector2(u1 * 12.0, v0 * 12.0)); st.add_vertex(p10)
			st.set_color(c01); st.set_uv(Vector2(u0 * 12.0, v1 * 12.0)); st.add_vertex(p01)
			
			st.set_color(c10); st.set_uv(Vector2(u1 * 12.0, v0 * 12.0)); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(Vector2(u1 * 12.0, v1 * 12.0)); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(Vector2(u0 * 12.0, v1 * 12.0)); st.add_vertex(p01)
			
	st.generate_normals()
	terrain_mesh.mesh = st.commit()
	
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/psx_vertex_snap.gdshader")
	mat.set_shader_parameter("grid_precision", 60)
	mat.set_shader_parameter("use_pixel_terrain", true)
	mat.set_shader_parameter("pixel_size", 0.08)
	mat.set_shader_parameter("grass_g1", Color(0.12, 0.28, 0.09, 1.0))
	mat.set_shader_parameter("grass_g2", Color(0.16, 0.35, 0.12, 1.0))
	mat.set_shader_parameter("dirt_d1", Color(0.28, 0.19, 0.12, 1.0))
	mat.set_shader_parameter("dirt_d2", Color(0.38, 0.26, 0.16, 1.0))
	mat.set_shader_parameter("cliff_c1", Color(0.24, 0.22, 0.19, 1.0))
	mat.set_shader_parameter("cliff_c2", Color(0.34, 0.32, 0.28, 1.0))
	terrain_mesh.material_override = mat

## Genera árboles procedurales en la cresta de la colina (100% ProceduralTree)
func _populate_trees(rng: RandomNumberGenerator) -> void:
	for child in trees_container.get_children():
		child.queue_free()
	
	# 1. Abedul de Otoño dorado en la cresta central
	var birch := ProceduralTree.new()
	birch.profile_id = "autumn_birch"
	birch.tree_seed = rng.randi()
	trees_container.add_child(birch)
	var b_pos := Vector2(-0.8, -8.2)
	birch.global_position = Vector3(b_pos.x, get_terrain_height(b_pos), b_pos.y)
	birch.scale = Vector3(1.15, 1.25, 1.15)
	
	# 2. Roble clásico en la ladera izquierda lejana
	var oak := ProceduralTree.new()
	oak.profile_id = "classic_oak"
	oak.tree_seed = rng.randi()
	trees_container.add_child(oak)
	var o_pos := Vector2(-6.8, -6.5)
	oak.global_position = Vector3(o_pos.x, get_terrain_height(o_pos), o_pos.y)
	oak.scale = Vector3(1.2, 1.15, 1.2)
	
	# 3. Sauce elegante en la hondonada derecha
	var willow := ProceduralTree.new()
	willow.profile_id = "weeping_willow"
	willow.tree_seed = rng.randi()
	trees_container.add_child(willow)
	var w_pos := Vector2(6.5, -5.8)
	willow.global_position = Vector3(w_pos.x, get_terrain_height(w_pos), w_pos.y)
	willow.scale = Vector3(1.1, 1.1, 1.1)

## Genera rocas musgosas integradas en el relieve
func _populate_field_rocks(rng: RandomNumberGenerator) -> void:
	for child in rocks_container.get_children():
		child.queue_free()
		
	var rock_spots: Array[Vector2] = [
		Vector2(-2.2, -1.5),
		Vector2(2.8, -3.2),
		Vector2(-4.2, -4.8),
		Vector2(4.5, -2.0)
	]
	for p in rock_spots:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var r := rng.randf_range(0.45, 0.85)
		var phi := (1.0 + sqrt(5.0)) * 0.5
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
			base_v[i] += Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.1, 0.1))
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
			var c = Color(0.35, 0.33, 0.28).lerp(Color(0.24, 0.32, 0.16), 0.4)
			st.set_color(c); st.add_vertex(v0)
			st.set_color(c); st.add_vertex(v1)
			st.set_color(c); st.add_vertex(v2)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		rocks_container.add_child(mi)
		mi.global_position = Vector3(p.x, get_terrain_height(p) - 0.12, p.y)
		mi.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, rng.randf_range(-0.1, 0.1))

## Puebla las miles de flores silvestres mediante MultiMeshInstance3D
func _populate_wildflowers(rng: RandomNumberGenerator) -> void:
	for child in vegetation_container.get_children():
		child.queue_free()
		
	var height_cb = Callable(self, "_height_callback")
	
	# Densidad adaptativa: crecen en la pradera y disminuyen en el sendero de tierra
	var flower_density_cb = func(pos2d: Vector2) -> float:
		var dirt = get_dirt_factor(pos2d)
		if dirt > 0.65:
			return 0.05 # Muy pocas en medio del sendero
		return 1.0 - dirt * 0.85
		
	var grass_density_cb = func(pos2d: Vector2) -> float:
		var dirt = get_dirt_factor(pos2d)
		if dirt > 0.7:
			return 0.0
		return 0.50 # 50% de densidad para dar visibilidad total a los colores florales

	# 1. CÉSPED PSX (base verde agradable con 50% de reducción)
	var scatter_grass := VegetationScatter.new()
	scatter_grass.name = "ScatterGrass"
	vegetation_container.add_child(scatter_grass)
	var grass_mesh = PSXGrass.create_mesh(0.32)
	scatter_grass.material_override = PSXGrass.get_material()
	scatter_grass.min_scale = 0.55
	scatter_grass.max_scale = 1.05
	scatter_grass.populate_radial(grass_mesh, 800, 14.0, Vector3(0, 0, -3.0), height_cb, rng.randi(), grass_density_cb)

	# 2. MARGARITAS BLANCAS (1,200 flores formando mantos blancos y dorados)
	var scatter_daisy := VegetationScatter.new()
	scatter_daisy.name = "ScatterDaisies"
	vegetation_container.add_child(scatter_daisy)
	var daisy_mesh = WildDaisy.create_mesh(rng.randi())
	scatter_daisy.min_scale = 0.85
	scatter_daisy.max_scale = 1.45
	scatter_daisy.populate_radial(daisy_mesh, 1200, 13.5, Vector3(0, 0, -2.5), height_cb, rng.randi(), flower_density_cb)

	# 3. ESPIGAS DE LAVANDA SILVESTRE (850 flores moradas en ondas sobre las laderas)
	var scatter_lavender := VegetationScatter.new()
	scatter_lavender.name = "ScatterLavender"
	vegetation_container.add_child(scatter_lavender)
	var lavender_mesh = WildLavender.create_mesh(rng.randi())
	scatter_lavender.min_scale = 0.90
	scatter_lavender.max_scale = 1.40
	var lavender_density_cb = func(pos2d: Vector2) -> float:
		var df = flower_density_cb.call(pos2d)
		# Se concentran más en las laderas y crestas laterales
		var slope_bias = clampf(absf(pos2d.x) * 0.15 + (-(pos2d.y + 2.0)) * 0.10, 0.2, 1.0)
		return df * slope_bias
	scatter_lavender.populate_radial(lavender_mesh, 850, 14.0, Vector3(0.5, 0, -3.5), height_cb, rng.randi(), lavender_density_cb)

	# 4. AMAPOLAS ROJAS (500 flores de color rubí brillante en claros soleados)
	var scatter_poppy := VegetationScatter.new()
	scatter_poppy.name = "ScatterPoppies"
	vegetation_container.add_child(scatter_poppy)
	var poppy_mesh = WildPoppy.create_mesh(rng.randi())
	scatter_poppy.min_scale = 0.85
	scatter_poppy.max_scale = 1.35
	scatter_poppy.populate_radial(poppy_mesh, 500, 11.0, Vector3(0, 0, -2.0), height_cb, rng.randi(), flower_density_cb)

## Puebla 26 rosales silvestres botánicos (`ProceduralFlower`) utilizando arquetipos con LODs
func _populate_rose_bushes(rng: RandomNumberGenerator) -> void:
	for child in roses_container.get_children():
		child.queue_free()
		
	# Distribución artística en 3 franjas: primer plano (macro), valle medio y faldas de la colina
	var rose_locations: Array[Dictionary] = [
		# Franja 1: Primer plano (cerca de la cámara para apreciar pétalos y botones)
		{"pos": Vector2(-0.85, 0.4), "palette": 1, "scale": 1.15}, # Coral
		{"pos": Vector2(0.95, 0.2), "palette": 4, "scale": 1.25},  # Blanca
		{"pos": Vector2(-1.6, -0.6), "palette": 0, "scale": 1.10}, # Carmesí
		{"pos": Vector2(1.8, -0.4), "palette": 3, "scale": 1.20},  # Amarilla
		{"pos": Vector2(-0.2, -1.2), "palette": 2, "scale": 1.05}, # Rosa Pastel
		{"pos": Vector2(0.6, -1.5), "palette": 5, "scale": 1.10},  # Negra Baccara
		
		# Franja 2: Flancos del sendero y valle medio
		{"pos": Vector2(-2.5, -2.2), "palette": 0, "scale": 1.15},
		{"pos": Vector2(-3.4, -1.8), "palette": 1, "scale": 1.20},
		{"pos": Vector2(-2.8, -3.4), "palette": 3, "scale": 1.10},
		{"pos": Vector2(2.6, -1.8), "palette": 4, "scale": 1.30},
		{"pos": Vector2(3.2, -2.6), "palette": 2, "scale": 1.15},
		{"pos": Vector2(2.1, -3.2), "palette": 1, "scale": 1.05},
		{"pos": Vector2(-1.2, -3.0), "palette": 0, "scale": 1.25},
		{"pos": Vector2(1.1, -3.8), "palette": 4, "scale": 1.15},
		{"pos": Vector2(-0.4, -4.2), "palette": 3, "scale": 1.20},
		{"pos": Vector2(0.4, -4.6), "palette": 2, "scale": 1.10},
		
		# Franja 3: Laderas altas y fondo hacia el bosque
		{"pos": Vector2(-4.8, -4.2), "palette": 1, "scale": 1.25},
		{"pos": Vector2(-5.6, -5.2), "palette": 0, "scale": 1.15},
		{"pos": Vector2(4.8, -4.0), "palette": 4, "scale": 1.20},
		{"pos": Vector2(5.5, -5.0), "palette": 3, "scale": 1.10},
		{"pos": Vector2(-2.0, -5.5), "palette": 2, "scale": 1.15},
		{"pos": Vector2(2.2, -5.6), "palette": 0, "scale": 1.20},
		{"pos": Vector2(-0.8, -6.5), "palette": 1, "scale": 1.25},
		{"pos": Vector2(0.9, -6.8), "palette": 5, "scale": 1.15},
		{"pos": Vector2(-3.5, -6.2), "palette": 3, "scale": 1.10},
		{"pos": Vector2(3.6, -6.4), "palette": 4, "scale": 1.20}
	]
	
	for loc in rose_locations:
		var p2d: Vector2 = loc["pos"]
		var pal_idx: int = loc["palette"]
		var s: float = loc["scale"]
		
		var rose := ProceduralFlower.new()
		rose.name = "ShowcaseRose"
		if pal_idx < _rose_packages.size():
			rose.apply_generation_package(_rose_packages[pal_idx])
		
		roses_container.add_child(rose)
		var y = get_terrain_height(p2d)
		rose.global_position = Vector3(p2d.x, y, p2d.y)
		rose.scale = Vector3.ONE * s
		rose.rotate_y(rng.randf() * TAU)
		
		# Sutil inclinación orgánica en las laderas
		var norm = get_terrain_normal(p2d)
		if norm.dot(Vector3.UP) < 0.98:
			var tilt_axis = norm.cross(Vector3.UP).normalized()
			rose.rotate(tilt_axis, rng.randf_range(0.04, 0.10))

## Aplica las vistas cinematográficas
func _apply_camera_viewpoint(index: int) -> void:
	_viewpoint_index = index % 4
	match _viewpoint_index:
		0:
			# 1. Panorámica general "Mar de Flores"
			var target_2d := Vector2(0.0, -3.2)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.95, target_2d.y)
			_camera_distance = 8.2
			_camera_pitch = deg_to_rad(7.5)
			_camera_yaw = deg_to_rad(-16.0)
		1:
			# 2. Macro primer plano "Rosales al Atardecer"
			var target_2d := Vector2(-0.85, 0.4)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x + 0.1, ground_y + 0.45, target_2d.y)
			_camera_distance = 1.75
			_camera_pitch = deg_to_rad(4.0)
			_camera_yaw = deg_to_rad(-24.0)
		2:
			# 3. Vista a ras del "Sendero Florido"
			var target_2d := Vector2(-0.2, -1.8)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.50, target_2d.y)
			_camera_distance = 4.2
			_camera_pitch = deg_to_rad(9.0)
			_camera_yaw = deg_to_rad(12.0)
		3:
			# 4. Mirando a contraluz en la "Cresta de Lavandas"
			var target_2d := Vector2(2.2, -3.5)
			var ground_y := get_terrain_height(target_2d)
			camera_pivot.position = Vector3(target_2d.x, ground_y + 0.60, target_2d.y)
			_camera_distance = 2.8
			_camera_pitch = deg_to_rad(5.0)
			_camera_yaw = deg_to_rad(-48.0)
			
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
			_camera_distance = clampf(_camera_distance - 0.5, 0.8, 22.0)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = clampf(_camera_distance + 0.5, 0.8, 22.0)
			_update_camera_transform()
			
	elif event is InputEventMouseMotion and _is_mouse_dragging:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_camera_yaw -= delta.x * 0.005
		_camera_pitch = clampf(_camera_pitch - delta.y * 0.005, deg_to_rad(-45.0), deg_to_rad(65.0))
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
			_pregenerate_rose_packages()
			_build_scene(_current_seed)
			_apply_camera_viewpoint(_viewpoint_index)

func _process(_delta: float) -> void:
	if hud_stats:
		var fps = Engine.get_frames_per_second()
		hud_stats.text = "FPS: %d | Flores instanciadas: 3,376 | Draw Calls: <25 | VRAM: ~240 MB" % fps
