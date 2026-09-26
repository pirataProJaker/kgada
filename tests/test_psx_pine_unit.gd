extends SceneTree

const PSXPine = preload("res://world/vegetation/trees/psx_pine.gd")

func _init() -> void:
	print("--- TEST UNITARIO PSX PINE ---")
	var lod0 = PSXPine.get_lod0_mesh()
	assert(lod0 != null, "LOD0 mesh debe existir")
	var l0_tris := 0
	for s in range(lod0.get_surface_count()):
		var arr = lod0.surface_get_arrays(s)
		var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var tris = (indices.size() / 3) if indices.size() > 0 else (verts.size() / 3)
		print("  Superficie %d: Verts=%d, Indices=%d, Tris=%d" % [s, verts.size(), indices.size(), tris])
		l0_tris += tris
	print("✓ LOD 0 Total: Superficies = %d, Triángulos = %d" % [lod0.get_surface_count(), l0_tris])
	assert(l0_tris == 30, "LOD 0 debe tener exactamente 30 triángulos")
	
	var lod1 = PSXPine.get_lod1_mesh()
	assert(lod1 != null, "LOD1 mesh debe existir")
	var l1_tris := 0
	for s in range(lod1.get_surface_count()):
		var arr = lod1.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		l1_tris += verts.size() / 3
	print("✓ LOD 1: Superficies = %d, Triángulos = %d" % [lod1.get_surface_count(), l1_tris])
	assert(l1_tris == 2, "LOD 1 debe tener EXACTAMENTE 2 triángulos (1 tronco + 1 copa)")
	
	# Test de bosque GPU instancing
	var transforms: Array[Transform3D] = []
	for i in range(10):
		transforms.append(Transform3D(Basis(), Vector3(i * 10.0, 0.0, 0.0)))
	var forest = PSXPine.create_gpu_instanced_forest(transforms, 100.0, 400.0)
	assert(forest.get_child_count() == 2, "Forest debe tener 2 nodos MultiMeshInstance3D (LOD0 y LOD1)")
	var mmi0 = forest.get_node("PineForest_LOD0") as MultiMeshInstance3D
	var mmi1 = forest.get_node("PineForest_LOD1") as MultiMeshInstance3D
	assert(mmi0.multimesh.instance_count == 10, "Instancias LOD0 = 10")
	assert(mmi1.multimesh.instance_count == 10, "Instancias LOD1 = 10")
	assert(mmi0.visibility_range_end == 100.0, "LOD0 range end = 100.0")
	assert(mmi1.visibility_range_begin == 100.0, "LOD1 range begin = 100.0")
	print("✓ Bosque GPU Instancing verificado exitosamente.")
	
	# Test de nodo individual
	var pine_single = PSXPine.new()
	root.add_child(pine_single)
	assert(pine_single.get_node("Pine_LOD0_3D") != null, "Nodo LOD0 individual existe")
	assert(pine_single.get_node("Pine_LOD1_2Tris") != null, "Nodo LOD1 individual existe")
	print("✓ Instancia individual PSXPine verificada exitosamente.")
	
	print("¡TODOS LOS TESTS DE PSXPINE PASARON CON ÉXITO!")
	quit(0)
