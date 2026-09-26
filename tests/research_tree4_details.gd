@tool
extends SceneTree

func _init() -> void:
	var fbx_scene: PackedScene = load("res://PSX_Forest_AssetCollection_byStarkCrafts.fbx")
	var fbx = fbx_scene.instantiate()
	var tree4: MeshInstance3D = fbx.get_node("PSX_Tree4") as MeshInstance3D
	var m: Mesh = tree4.mesh
	print("PSX_Tree4 Node Transform: pos=%s, rot=%s, scale=%s" % [tree4.position, tree4.rotation_degrees, tree4.scale])
	print("PSX_Tree4 Total Surfaces: %d" % m.get_surface_count())
	for s in range(m.get_surface_count()):
		var mat = m.surface_get_material(s)
		var s_name: String = str(mat.resource_name if mat else "surf_%d" % s)
		var arr := m.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var tris := indices.size() / 3
		print("\n--- SURFACE %d: '%s' ---" % [s, s_name])
		print("Triangles: %d | Vertices: %d" % [tris, verts.size()])
		if mat:
			print("Material: %s (%s)" % [mat.resource_name, mat.get_class()])
			if mat is StandardMaterial3D:
				var std_mat := mat as StandardMaterial3D
				if std_mat.albedo_texture:
					print("Albedo Texture: %s" % std_mat.albedo_texture.resource_path)
				print("Transparency: %s, Cull: %s, Alpha Cut: %s" % [std_mat.transparency, std_mat.cull_mode, std_mat.alpha_scissor_threshold])
		
		# Bounding box in raw mesh coordinates and in node local coordinates (with node scale 100 and rot -90)
		var min_v := Vector3(9999, 9999, 9999)
		var max_v := Vector3(-9999, -9999, -9999)
		var min_uv := Vector2(9999, 9999)
		var max_uv := Vector2(-9999, -9999)
		for v in verts:
			min_v.x = minf(min_v.x, v.x); min_v.y = minf(min_v.y, v.y); min_v.z = minf(min_v.z, v.z)
			max_v.x = maxf(max_v.x, v.x); max_v.y = maxf(max_v.y, v.y); max_v.z = maxf(max_v.z, v.z)
		for uv in uvs:
			min_uv.x = minf(min_uv.x, uv.x); min_uv.y = minf(min_uv.y, uv.y)
			max_uv.x = maxf(max_uv.x, uv.x); max_uv.y = maxf(max_uv.y, uv.y)
		print("Raw Mesh Bounds: min=%s, max=%s, size=%s" % [min_v, max_v, max_v - min_v])
		print("UV Range: min=%s, max=%s" % [min_uv, max_uv])
		
		# Now transformed by node transform
		var node_t := tree4.transform
		var t_min := Vector3(9999, 9999, 9999)
		var t_max := Vector3(-9999, -9999, -9999)
		for v in verts:
			var world_v: Vector3 = node_t * v
			t_min.x = minf(t_min.x, world_v.x); t_min.y = minf(t_min.y, world_v.y); t_min.z = minf(t_min.z, world_v.z)
			t_max.x = maxf(t_max.x, world_v.x); t_max.y = maxf(t_max.y, world_v.y); t_max.z = maxf(t_max.z, world_v.z)
		print("Transformed Bounds (in game meters Y-up): min=%s, max=%s, size=%s" % [t_min, t_max, t_max - t_min])
		
	fbx.free()
	quit(0)
