extends SceneTree

const PSXPine = preload("res://world/vegetation/trees/psx_pine.gd")

func _init() -> void:
	print("--- TEST DE BILLBOARD EN MULTIMESH ---")
	var scene := Node3D.new()
	root.add_child(scene)
	
	var forest = PSXPine.create_gpu_instanced_forest([Transform3D(Basis(), Vector3.ZERO)], 100.0, 400.0)
	scene.add_child(forest)
	
	var mmi_lod1 = forest.get_node("PineForest_LOD1") as MultiMeshInstance3D
	var mesh = mmi_lod1.multimesh.mesh
	print("LOD1 Mesh Surfaces: %d" % mesh.get_surface_count())
	for s in range(mesh.get_surface_count()):
		var mat = mesh.surface_get_material(s)
		if mat is StandardMaterial3D:
			print("Surface %d mat: billboard_mode=%s, cull=%s" % [s, mat.billboard_mode, mat.cull_mode])
		else:
			print("Surface %d mat: %s" % [s, mat])
			
	forest.free()
	scene.free()
	quit(0)
