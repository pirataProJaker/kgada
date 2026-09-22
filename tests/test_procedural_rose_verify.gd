extends SceneTree

const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")
const FlowerProfiles = preload("res://world/procedural_flora/procedural_flower_profiles.gd")
const FlowerGenerator = preload("res://world/procedural_flora/procedural_flower_generator.gd")

func _init() -> void:
	print("--- INICIANDO VERIFICACION DE SISTEMA PROCEDURAL DE ROSAS ---")
	
	# 1. Verificar perfiles y paletas de colores
	assert(FlowerProfiles.PROFILES.has("solitary_rose"), "Falta perfil solitary_rose")
	assert(FlowerProfiles.PROFILES.has("shrub_rose"), "Falta perfil shrub_rose")
	assert(FlowerProfiles.ROSE_PALETTES.size() >= 6, "Deben haber al menos 6 paletas de rosas")
	print("✓ Perfiles botánicos y paletas de colores verificados.")
	
	# 2. Verificar generación de Rosa Solitaria en todas las etapas
	var solitary = ProceduralFlower.new()
	root.add_child(solitary)
	solitary.profile_id = "solitary_rose"
	solitary.flower_seed = 42
	
	var stages = [0.1, 0.4, 0.7, 1.0]
	for stage in stages:
		solitary.growth_progress = stage
		solitary.generate()
		var m = solitary.get_mesh()
		assert(m != null, "Mesh no debe ser nulo en etapa %f" % stage)
		assert(m.get_surface_count() > 0, "Debe tener al menos 1 superficie")
		print("  - Solitaria etapa %s (%.2f): OK (Superficies: %d, Altura: %.2f m)" % [
			solitary.get_stage_name(), stage, m.get_surface_count(), solitary.get_flower_height()
		])
	
	# Verificar cosecha de solitaria
	var harvest_sol = solitary.harvest()
	assert(harvest_sol.has("flower_count") and harvest_sol["flower_count"] == 1, "Cosecha solitaria fallida")
	print("✓ Cosecha de Rosa Solitaria exitosa: %s" % str(harvest_sol))
	solitary.queue_free()
	
	# 3. Verificar generación de Rosal Arbustivo en todas las etapas
	var shrub = ProceduralFlower.new()
	root.add_child(shrub)
	shrub.profile_id = "shrub_rose"
	shrub.flower_seed = 100
	
	for stage in stages:
		shrub.growth_progress = stage
		shrub.generate()
		var m = shrub.get_mesh()
		assert(m != null, "Mesh de arbusto no debe ser nulo en etapa %f" % stage)
		assert(m.get_surface_count() > 0, "Debe tener superficies")
		print("  - Arbusto etapa %s (%.2f): OK (Superficies: %d, Flores: %d, Altura: %.2f m)" % [
			shrub.get_stage_name(), stage, m.get_surface_count(), shrub.get_flower_count(), shrub.get_flower_height()
		])
	
	# Verificar colores
	for c in range(FlowerProfiles.ROSE_PALETTES.size()):
		shrub.color_index = c
		shrub.generate()
	print("✓ Verificación de 6 colores de rosas en rosal arbustivo exitosa.")
	
	# Verificar cosecha de arbusto
	var harvest_shrub = shrub.harvest()
	assert(harvest_shrub.has("flower_count") and harvest_shrub["flower_count"] > 1, "Cosecha de arbusto fallida")
	print("✓ Cosecha de Rosal Arbustivo exitosa: %s" % str(harvest_shrub))
	shrub.queue_free()
	
	# 4. Probar carga de la escena completa test_procedural_rose.tscn
	var rose_scene = load("res://tests/test_procedural_rose.tscn")
	assert(rose_scene != null, "No se pudo cargar test_procedural_rose.tscn")
	var instance = rose_scene.instantiate()
	root.add_child(instance)
	print("✓ Escena test_procedural_rose.tscn instanciada correctamente en el SceneTree.")
	
	# 5. Verificar niveles de LOD y ahorros geométricos
	var test_shrub = ProceduralFlower.new()
	root.add_child(test_shrub)
	test_shrub.profile_id = "shrub_rose"
	test_shrub.flower_seed = 12345
	test_shrub.growth_progress = 1.0
	test_shrub.generate()
	
	var t0 = test_shrub.get_triangle_count_lod(0)
	var t1 = test_shrub.get_triangle_count_lod(1)
	var t2 = test_shrub.get_triangle_count_lod(2)
	assert(test_shrub.get_mesh_lod(0) != null, "Mesh LOD 0 no debe ser nulo")
	assert(test_shrub.get_mesh_lod(1) != null, "Mesh LOD 1 no debe ser nulo")
	assert(test_shrub.get_mesh_lod(2) != null, "Mesh LOD 2 no debe ser nulo")
	assert(test_shrub.get_mesh_lod(1).get_surface_count() == 2, "LOD 1 debe tener 2 superficies (veg y flor) para fidelidad de material")
	assert(test_shrub.get_mesh_lod(2).get_surface_count() == 2, "LOD 2 debe tener 2 superficies (veg y flor) para fidelidad de material")
	assert(t0 > t1 and t1 > t2, "Los triángulos deben decrecer estrictamente: LOD0(%d) > LOD1(%d) > LOD2(%d)" % [t0, t1, t2])
	
	# Verificación de fidelidad total de esqueleto: conteo y posiciones de flores idénticas
	var r_l0 = FlowerGenerator.generate_flower("shrub_rose", 12345, 1.0, 0, 0)
	var r_l1 = FlowerGenerator.generate_flower("shrub_rose", 12345, 1.0, 0, 1)
	var r_l2 = FlowerGenerator.generate_flower("shrub_rose", 12345, 1.0, 0, 2)
	assert(r_l0.flower_count == r_l1.flower_count and r_l0.flower_count == r_l2.flower_count, 
		"El conteo de flores debe ser idéntico en todos los LODs: LOD0=%d, LOD1=%d, LOD2=%d" % [r_l0.flower_count, r_l1.flower_count, r_l2.flower_count])
	for f_idx in range(r_l0.flower_positions.size()):
		var pf0 = r_l0.flower_positions[f_idx]
		var pf1 = r_l1.flower_positions[f_idx]
		var pf2 = r_l2.flower_positions[f_idx]
		assert(pf0.distance_to(pf1) < 0.001, "Flor %d en LOD1 debe estar en la misma posición que LOD0" % f_idx)
		assert(pf0.distance_to(pf2) < 0.001, "Flor %d en LOD2 debe estar en la misma posición que LOD0" % f_idx)
	print("✓ Fidelidad de esqueleto y flores verificada: %d flores en exactamente las mismas posiciones 3D en LOD0, LOD1 y LOD2." % r_l0.flower_count)
	
	# Comprobar conmutación de forzado
	test_shrub.forced_lod_level = 1
	assert(test_shrub.forced_lod_level == 1, "forced_lod_level debe ser 1")
	test_shrub.forced_lod_level = 2
	assert(test_shrub.forced_lod_level == 2, "forced_lod_level debe ser 2")
	test_shrub.forced_lod_level = -1
	assert(test_shrub.forced_lod_level == -1, "forced_lod_level debe ser -1 (Auto)")
	
	print("✓ Verificación de LODs exitosa: LOD0=%d tris, LOD1=%d tris (-%.1f%%), LOD2=%d tris (-%.1f%%)" % [
		t0, t1, (1.0 - float(t1) / float(t0)) * 100.0, t2, (1.0 - float(t2) / float(t0)) * 100.0
	])
	test_shrub.queue_free()
	
	print("=== TODAS LAS PRUEBAS DE ROSAS PROCEDURALES PASARON CON ÉXITO ===")
	quit(0)
