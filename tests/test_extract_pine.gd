@tool
extends SceneTree

func _init() -> void:
	var fbx_scene: PackedScene = load("res://PSX_Forest_AssetCollection_byStarkCrafts.fbx")
	var fbx = fbx_scene.instantiate()
	var tree4: MeshInstance3D = fbx.get_node("PSX_Tree4") as MeshInstance3D
	var orig_mesh: Mesh = tree4.mesh
	var node_t: Transform3D = tree4.transform
	
	# La posición del nodo en el FBX es (-20, 0, 0).
	# Para centrarlo en (0,0,0) local en X y Z, restamos la posición del nodo.
	var center_offset = Vector3(tree4.position.x, 0.0, tree4.position.z)
	var local_t = Transform3D(node_t.basis, node_t.origin - center_offset)
	
	print("--- EXTRAYENDO LOD 0 NORMALIZADO ---")
	var lod0_mesh = ArrayMesh.new()
	for s in range(orig_mesh.get_surface_count()):
		var arr = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var new_verts = PackedVector3Array()
		for v in verts:
			new_verts.append(local_t * v)
		arr[Mesh.ARRAY_VERTEX] = new_verts
		
		# Recalcular normales si se transformó
		lod0_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		lod0_mesh.surface_set_material(s, orig_mesh.surface_get_material(s))
		print("Surface %d ('%s'): %d tris" % [s, orig_mesh.surface_get_material(s).resource_name, arr[Mesh.ARRAY_INDEX].size() / 3])
		
	print("\n--- CONSTRUYENDO LOD 1 (EXACTAMENTE 2 TRIÁNGULOS) ---")
	var lod1_mesh = ArrayMesh.new()
	
	# Superficie 0: Copa (1 triángulo ancho de y=12.8m a y=34.0m)
	# Mapeado con la misma textura TreeCorwn4
	var crown_st = SurfaceTool.new()
	crown_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var c_w = 19.65 * 0.5
	var c_y_base = 12.81
	var c_y_top = 34.00
	
	# Vértices del triángulo de la copa:
	# Base izquierda, base derecha, punta superior
	var p_crown_left = Vector3(-c_w, c_y_base, 0.0)
	var p_crown_right = Vector3(c_w, c_y_base, 0.0)
	var p_crown_top = Vector3(0.0, c_y_top, 0.0)
	
	# UVs: triángulo abarcando la textura completa de la copa
	crown_st.set_uv(Vector2(0.0, 1.0)); crown_st.add_vertex(p_crown_left)
	crown_st.set_uv(Vector2(1.0, 1.0)); crown_st.add_vertex(p_crown_right)
	crown_st.set_uv(Vector2(0.5, 0.0)); crown_st.add_vertex(p_crown_top)
	crown_st.generate_normals()
	lod1_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown_st.commit_to_arrays())
	lod1_mesh.surface_set_material(0, orig_mesh.surface_get_material(0))
	
	# Superficie 1: Tronco (1 triángulo estirado de y=-0.26m a y=29.74m)
	# Mapeado con la misma textura Tree4
	var trunk_st = SurfaceTool.new()
	trunk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var t_w = 2.25 * 0.5
	var t_y_base = -0.26
	var t_y_top = 29.74
	
	var p_trunk_left = Vector3(-t_w, t_y_base, 0.0)
	var p_trunk_right = Vector3(t_w, t_y_base, 0.0)
	var p_trunk_top = Vector3(0.0, t_y_top, 0.0)
	
	# UVs: tronco estirado verticalmente
	trunk_st.set_uv(Vector2(0.0, 8.0)); trunk_st.add_vertex(p_trunk_left)
	trunk_st.set_uv(Vector2(1.0, 8.0)); trunk_st.add_vertex(p_trunk_right)
	trunk_st.set_uv(Vector2(0.5, 0.0)); trunk_st.add_vertex(p_trunk_top)
	trunk_st.generate_normals()
	lod1_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_st.commit_to_arrays())
	lod1_mesh.surface_set_material(1, orig_mesh.surface_get_material(1))
	
	var l0_tris = lod0_mesh.get_faces().size() / 3
	var l1_tris = lod1_mesh.get_faces().size() / 3
	print("LOD 0 Triángulos: %d" % l0_tris)
	print("LOD 1 Triángulos: %d" % l1_tris)
	
	assert(l0_tris == 30, "LOD 0 debe tener 30 triángulos")
	assert(l1_tris == 2, "LOD 1 debe tener exactamente 2 triángulos")
	print("✓ Verificación de conteo de polígonos exitosa!")
	
	fbx.free()
	quit(0)
