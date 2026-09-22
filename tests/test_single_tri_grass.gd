extends SceneTree

const GrassMSingleTri = preload("res://world/vegetation/grass/grass_m_single_tri.gd")

var _frames: int = 0
var _scene: Node3D

func _init() -> void:
	print("--- VERIFICACIÓN DE CÉSPED 2D EN 1 SOLO TRIÁNGULO ---")
	
	var single_mesh = GrassMSingleTri.create_single_triangle_mesh()
	var tris_single = _count_mesh_triangles(single_mesh)
	print("✓ Modo 1 Triángulo: %d triángulo(s)" % tris_single)
	assert(tris_single == 1, "Debe tener exactamente 1 triángulo")
	
	var cross_mesh = GrassMSingleTri.create_cross_triangles_mesh()
	var tris_cross = _count_mesh_triangles(cross_mesh)
	print("✓ Modo Cruz '+': %d triángulos" % tris_cross)
	assert(tris_cross == 2, "Debe tener exactamente 2 triángulos")
	
	# Construir escena de previsualización
	_scene = Node3D.new()
	root.add_child(_scene)
	
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.70, 0.75, 1.0)
	env_node.environment = env
	_scene.add_child(env_node)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_color = Color(1.0, 0.95, 0.88)
	light.light_energy = 1.2
	_scene.add_child(light)
	
	# Instancia 1: Triángulo individual (1 tri)
	var mi1 = MeshInstance3D.new()
	mi1.mesh = single_mesh
	mi1.material_override = GrassMSingleTri.get_shared_material()
	mi1.position = Vector3(-0.35, 0.0, 0.0)
	_scene.add_child(mi1)
	
	# Instancia 2: Triángulos en cruz '+' (2 tris)
	var mi2 = MeshInstance3D.new()
	mi2.mesh = cross_mesh
	mi2.material_override = GrassMSingleTri.get_shared_material()
	mi2.position = Vector3(0.35, 0.0, 0.0)
	_scene.add_child(mi2)
	
	# Cámara de primer plano
	var cam = Camera3D.new()
	cam.position = Vector3(0.0, 0.25, 0.85)
	_scene.add_child(cam)
	cam.look_at(Vector3(0.0, 0.18, 0.0), Vector3.UP)
	cam.current = true

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 12:
		var vp = root.get_viewport()
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img != null:
				img.save_png("res://tests/single_tri_grass_preview.png")
				print("✓ Captura guardada en: res://tests/single_tri_grass_preview.png")
		print("=== PRUEBA DE CÉSPED EN 1 TRIÁNGULO COMPLETADA EXITOSAMENTE ===")
		quit(0)
		return true
	return false

func _count_mesh_triangles(mesh: ArrayMesh) -> int:
	if mesh == null: return 0
	var total: int = 0
	for s in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(s)
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			total += arrays[Mesh.ARRAY_INDEX].size() / 3
		elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			total += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return total
