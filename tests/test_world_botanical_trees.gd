extends SceneTree

func _init() -> void:
	print("--- TEST PROCEDURAL TREES EN EL MUNDO NORMAL ---")
	
	var profiles_to_test := [
		"classic_oak",
		"alnus_acuminata",
		"autumn_birch",
		"weeping_willow",
		"dead_tree",
		"pine_boreal"
	]
	
	for pid in profiles_to_test:
		var prof := ProceduralTreeProfiles.get_profile(pid)
		var t0 := Time.get_ticks_usec()
		var res := ProceduralTreeGenerator.generate_tree(prof, 12345)
		var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
		
		var lod0_branches_tris := 0
		var lod0_leaves_tris := 0
		if res.mm_branches_lod0 and res.mm_branches_lod0.mesh:
			var m: Mesh = res.mm_branches_lod0.mesh
			for s in range(m.get_surface_count()):
				lod0_branches_tris += m.surface_get_array_index_len(s) / 3
		if res.mm_leaves_lod0 and res.mm_leaves_lod0.mesh:
			var m: Mesh = res.mm_leaves_lod0.mesh
			for s in range(m.get_surface_count()):
				lod0_leaves_tris += m.surface_get_array_index_len(s) / 3
				
		var lod1_tris := 0
		if res.mm_branches_lod1 and res.mm_branches_lod1.mesh:
			var m: Mesh = res.mm_branches_lod1.mesh
			for s in range(m.get_surface_count()):
				lod1_tris += m.surface_get_array_index_len(s) / 3
		if res.mm_leaves_lod1 and res.mm_leaves_lod1.mesh:
			var m: Mesh = res.mm_leaves_lod1.mesh
			for s in range(m.get_surface_count()):
				lod1_tris += m.surface_get_array_index_len(s) / 3
				
		var lod2_tris := 0
		if res.mm_branches_lod2 and res.mm_branches_lod2.mesh:
			var m: Mesh = res.mm_branches_lod2.mesh
			for s in range(m.get_surface_count()):
				lod2_tris += m.surface_get_array_index_len(s) / 3
		if res.mm_leaves_lod2 and res.mm_leaves_lod2.mesh:
			var m: Mesh = res.mm_leaves_lod2.mesh
			for s in range(m.get_surface_count()):
				lod2_tris += m.surface_get_array_index_len(s) / 3
				
		print("[%s] Generado en %.2f ms | Altura: %.1fm | LOD0: %d tris (Tronco: %d, Follaje: %d) | LOD1: %d tris | LOD2: %d tris" % [
			pid,
			elapsed_ms,
			res.tree_height,
			lod0_branches_tris + lod0_leaves_tris,
			lod0_branches_tris,
			lod0_leaves_tris,
			lod1_tris,
			lod2_tris
		])
		
	print("--- TEST COMPLETADO EXITOSAMENTE ---")
	quit()
