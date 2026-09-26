@tool
extends SceneTree

func _init() -> void:
	print("--- TEST BOTANICAL TREE (RUST GDExtension) ---")
	
	if not ClassDB.class_exists("BotanicalTree"):
		print("ERROR: BotanicalTree no esta registrada en ClassDB!")
		quit(1)
		return
	
	var tree = ClassDB.instantiate("BotanicalTree")
	print("✓ BotanicalTree instanciado correctamente: ", tree)
	
	tree.set_species_id("alnus_acuminata")
	tree.set_tree_seed(12345)
	
	# Test default properties
	print("  Especie: ", tree.get_species_id())
	print("  Semilla: ", tree.get_tree_seed())
	
	# Test growth at age 0.1 (Brote)
	tree.set_age(0.1)
	var h_sprout = tree.get_height()
	var tris_sprout_lod0 = tree.get_total_triangles(0)
	print("  [Brote edad 0.1] Altura: %.2f m | Tris LOD0: %d" % [h_sprout, tris_sprout_lod0])
	
	# Test growth at age 0.5 (Juvenil)
	tree.set_age(0.5)
	var h_young = tree.get_height()
	var tris_young_lod0 = tree.get_total_triangles(0)
	var tris_young_lod1 = tree.get_total_triangles(1)
	print("  [Joven edad 0.5] Altura: %.2f m | Tris LOD0: %d | Tris LOD1: %d" % [h_young, tris_young_lod0, tris_young_lod1])
	
	# Test growth at age 1.0 (Maduro 100%)
	tree.set_age(1.0)
	var h_mature = tree.get_height()
	var tris_mature_lod0 = tree.get_total_triangles(0)
	var tris_mature_lod1 = tree.get_total_triangles(1)
	var tris_mature_lod2 = tree.get_total_triangles(2)
	var tris_mature_lod3 = tree.get_total_triangles(3)
	print("  [Adulto edad 1.0] Altura: %.2f m" % h_mature)
	print("    LOD 0 Tris: %d (Malla 3D completa)" % tris_mature_lod0)
	print("    LOD 1 Tris: %d (Aletas 2D sincronizadas)" % tris_mature_lod1)
	print("    LOD 2 Tris: %d (Cruce/Planos dominantes)" % tris_mature_lod2)
	print("    LOD 3 Tris: %d (Impostor 2 triangulos)" % tris_mature_lod3)
	
	# Verificar generación de mallas ArrayMesh
	for lod in range(4):
		var mesh = tree.get_lod_mesh(lod)
		assert(mesh != null, "Mesh LOD %d debe existir" % lod)
		print("    Mesh LOD %d generado: %d superficies" % [lod, mesh.get_surface_count()])
	
	# Test poda interactiva
	var branches_before = tree.get_branch_count()
	print("  Ramas antes de podar: ", branches_before)
	var pruned_id = tree.prune_random_branch()
	print("  Rama podada nodos cortados: ", pruned_id)
	var branches_after = tree.get_branch_count()
	print("  Ramas despues de podar: ", branches_after)
	assert(branches_after < branches_before, "El numero de ramas debio reducirse")
	
	tree.restore_all_branches()
	var branches_restored = tree.get_branch_count()
	print("  Ramas restauradas: ", branches_restored)
	assert(branches_restored == branches_before, "El numero de ramas debio restaurarse")
	
	print("\n=== TODOS LOS TESTS BOTANICAL TREE COMPLETADOS CON EXITO ===")
	quit(0)
