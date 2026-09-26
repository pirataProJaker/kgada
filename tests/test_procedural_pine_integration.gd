extends SceneTree

const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")

func _init() -> void:
	print("--- TEST DE INTEGRACIÓN: PROCEDURAL TREE (PINO PSX) ---")
	
	# 1. Crear árbol de pino
	var pine := ProceduralTree.new()
	pine.profile_id = "pine_boreal"
	pine.tree_seed = 12345
	pine.disable_lod = false
	root.add_child(pine)
	pine.generate()
	
	var mi_b0 = pine.get_node("Branches_LOD0") as MultiMeshInstance3D
	var mi_l0 = pine.get_node("Leaves_LOD0") as MultiMeshInstance3D
	var mi_b1 = pine.get_node("Branches_LOD1") as MultiMeshInstance3D
	var mi_l1 = pine.get_node("Leaves_LOD1") as MultiMeshInstance3D
	
	assert(mi_b0 != null and mi_l0 != null, "Nodos LOD0 existen")
	assert(mi_b1 != null and mi_l1 != null, "Nodos LOD1 existen")
	
	# Contar triángulos en LOD 0
	var b0_mesh: Mesh = mi_b0.multimesh.mesh
	var l0_mesh: Mesh = mi_l0.multimesh.mesh
	
	var b0_indices: PackedInt32Array = b0_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var l0_indices: PackedInt32Array = l0_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var lod0_tris = (b0_indices.size() / 3) + (l0_indices.size() / 3)
	print("✓ LOD 0 Triángulos = %d (Tronco: %d, Copa: %d)" % [lod0_tris, b0_indices.size() / 3, l0_indices.size() / 3])
	assert(lod0_tris == 30, "LOD 0 debe tener exactamente 30 triángulos")
	
	# Contar triángulos en LOD 1
	var b1_mesh: Mesh = mi_b1.multimesh.mesh
	var l1_mesh: Mesh = mi_l1.multimesh.mesh
	
	var b1_arr = b1_mesh.surface_get_arrays(0)
	var l1_arr = l1_mesh.surface_get_arrays(0)
	var b1_indices = b1_arr[Mesh.ARRAY_INDEX]
	var l1_indices = l1_arr[Mesh.ARRAY_INDEX]
	var b1_verts: PackedVector3Array = b1_arr[Mesh.ARRAY_VERTEX]
	var l1_verts: PackedVector3Array = l1_arr[Mesh.ARRAY_VERTEX]
	var b1_tris = (b1_indices.size() / 3) if b1_indices != null else (b1_verts.size() / 3)
	var l1_tris = (l1_indices.size() / 3) if l1_indices != null else (l1_verts.size() / 3)
	var lod1_tris = b1_tris + l1_tris
	print("✓ LOD 1 Triángulos = %d (Tronco: %d, Copa: %d)" % [lod1_tris, b1_tris, l1_tris])
	assert(lod1_tris == 2, "LOD 1 debe tener EXACTAMENTE 2 triángulos (1 tronco + 1 copa)")
	
	# Verificar rangos de LOD a los 100m
	assert(mi_b0.visibility_range_begin == 0.0 and mi_b0.visibility_range_end == 100.0, "LOD 0 visible 0-100m")
	assert(mi_l0.visibility_range_begin == 0.0 and mi_l0.visibility_range_end == 100.0, "LOD 0 visible 0-100m")
	assert(mi_b1.visibility_range_begin == 100.0 and mi_b1.visibility_range_end == 400.0, "LOD 1 visible 100-400m")
	assert(mi_l1.visibility_range_begin == 100.0 and mi_l1.visibility_range_end == 400.0, "LOD 1 visible 100-400m")
	print("✓ Rangos de visibilidad verificados: LOD0 de 0 a 100m, LOD1 de 100 a 400m.")
	
	# 2. Verificar que otra especie (classic_oak) sigue funcionando normalmente
	var oak := ProceduralTree.new()
	oak.profile_id = "classic_oak"
	oak.tree_seed = 99999
	root.add_child(oak)
	oak.generate()
	var oak_b0 = oak.get_node("Branches_LOD0") as MultiMeshInstance3D
	assert(oak_b0 != null and oak_b0.multimesh != null, "Oak genera ramas correctamente")
	print("✓ Especie procedural classic_oak sigue operando con normalidad.")
	
	print("¡TODOS LOS TESTS DE INTEGRACIÓN DE PINO PASARON CON ÉXITO!")
	quit(0)
