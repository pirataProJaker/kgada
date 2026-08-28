extends SceneTree

const ROAD_SCENES := {
	"cross": preload("res://assets/URBAN/URBAN/Roads/Road type 1/road_1_junction.fbx"),
	"t_junction": preload("res://assets/URBAN/URBAN/Roads/Road type 1/road_1_Tjunction.fbx"),
	"corner": preload("res://assets/URBAN/URBAN/Roads/Road type 1/road_1_corner.fbx"),
}
const LIGHT_SCENE: PackedScene = preload("res://assets/URBAN/URBAN/Traffic lights/traffic_light_L.fbx")

func _init() -> void:
	for key in ROAD_SCENES:
		_print_scene_aabb(key, ROAD_SCENES[key])
	_print_scene_aabb("traffic_light_L", LIGHT_SCENE)
	quit()

func _print_scene_aabb(label: String, scene: PackedScene) -> void:
	var instance: Node3D = scene.instantiate()
	var aabb := _compute_local_aabb(instance)
	print("[CityGeometry] %s aabb_pos=%s aabb_size=%s center=%s" % [label, aabb.position, aabb.size, aabb.get_center()])
	_print_visual_nodes(instance, instance, Transform3D.IDENTITY)
	instance.free()

func _print_visual_nodes(root: Node, node: Node, relative_transform: Transform3D) -> void:
	var current_transform := relative_transform
	if node is Node3D and node != root:
		current_transform = relative_transform * (node as Node3D).transform
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		var mesh_aabb := visual.get_aabb()
		var transformed_aabb: AABB = current_transform * mesh_aabb
		print("[CityGeometry]   mesh=%s local=%s transformed=%s parent_transform=%s" % [node.name, mesh_aabb, transformed_aabb, current_transform])
		if visual is MeshInstance3D and visual.mesh != null:
			_print_floor_footprint(visual as MeshInstance3D, current_transform)
	for child in node.get_children():
		_print_visual_nodes(root, child, current_transform)

func _print_floor_footprint(mesh_instance: MeshInstance3D, current_transform: Transform3D) -> void:
	var min_y := INF
	var vertices_at_floor: Array[Vector3] = []
	for surface_index in mesh_instance.mesh.get_surface_count():
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var transformed_vertex: Vector3 = current_transform * vertex
			min_y = minf(min_y, transformed_vertex.y)
	for surface_index in mesh_instance.mesh.get_surface_count():
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var transformed_vertex: Vector3 = current_transform * vertex
			if is_equal_approx(transformed_vertex.y, min_y) or transformed_vertex.y <= min_y + 0.01:
				vertices_at_floor.append(transformed_vertex)
	if vertices_at_floor.is_empty():
		return
	var floor_aabb := AABB(vertices_at_floor[0], Vector3.ZERO)
	for vertex in vertices_at_floor.slice(1):
		floor_aabb = floor_aabb.expand(vertex)
	print("[CityGeometry]   floor_footprint=%s floor_vertices=%d" % [floor_aabb, vertices_at_floor.size()])

func _compute_local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var relative_transform: Transform3D = entry[1]
		if node is VisualInstance3D:
			var mesh_aabb: AABB = (node as VisualInstance3D).get_aabb()
			var relative_aabb: AABB = relative_transform * mesh_aabb
			if not initialized:
				result = relative_aabb
				initialized = true
			else:
				result = result.merge(relative_aabb)
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, relative_transform * (child as Node3D).transform])
			else:
				stack.append([child, relative_transform])
	return result
