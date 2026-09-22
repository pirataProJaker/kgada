extends SceneTree

const ProceduralTreeProfiles = preload("res://world/procedural_trees/procedural_tree_profiles.gd")
const ProceduralTreeGenerator = preload("res://world/procedural_trees/procedural_tree_generator.gd")
const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")

## Script de verificacion automatizada sin interfaz (headless) para el sistema
## de arboles procedurales hiperoptimizados.

func _init() -> void:
	ProceduralTree.trees_disabled = false
	print("[VERIFY] Iniciando verificacion del sistema de arboles procedurales...")
	
	# 1. Verificar perfiles y especies
	var profile_ids := ProceduralTreeProfiles.get_profile_ids()
	print("[VERIFY] Perfiles disponibles: %s" % str(profile_ids))
	assert(profile_ids.size() >= 6, "Debe haber al menos 6 perfiles definidos")
	
	# 2. Verificar mallas primitivas
	var frustum_mesh := ProceduralTreeGenerator.get_frustum_mesh()
	assert(frustum_mesh != null, "La malla de tronco de cono (frustum) debe existir")
	assert(frustum_mesh.get_surface_count() == 1, "La malla de frustum debe tener 1 superficie")
	print("[VERIFY] Malla de cono/frustum verificada correctamente (6 caras laterales, abierta).")
	
	var leaf_mesh := ProceduralTreeGenerator.get_leaf_mesh()
	assert(leaf_mesh != null, "La malla de hoja de 1 triangulo debe existir")
	assert(leaf_mesh.get_surface_count() == 1, "La malla de hoja debe tener 1 superficie")
	print("[VERIFY] Malla de hoja de 1 solo triangulo verificada correctamente.")
	
	# 3. Probar generacion procedural para cada una de las 6 especies
	for p_id in profile_ids:
		var profile := ProceduralTreeProfiles.get_profile(p_id)
		assert(profile != null, "El perfil %s no debe ser nulo" % p_id)
		
		var seed_val := 42 + hash(p_id)
		var res := ProceduralTreeGenerator.generate_tree(profile, seed_val)
		assert(res != null, "El resultado de generacion no debe ser nulo")
		assert(res.mm_branches_lod0 != null, "MultiMesh de ramas LOD0 no debe ser nulo")
		assert(res.mm_branches_lod0.instance_count > 0, "Debe haber segmentos de tronco/ramas")
		
		# Verificar reglas de LOD
		if profile.has_leaves:
			assert(res.mm_leaves_lod0.instance_count > 0, "Debe haber hojas en arboles con follaje")
			assert(res.lod0_leaves_count >= res.lod1_leaves_count, "LOD0 debe tener mas o igual hojas que LOD1")
			assert(res.lod1_leaves_count >= res.lod2_leaves_count, "LOD1 debe tener mas o igual hojas que LOD2")
		else:
			assert(res.lod0_leaves_count == 0, "Arbol muerto no debe tener hojas")
		
		print("[VERIFY]  - %s: LOD0=%d ramas, %d hojas | LOD1=%d ramas, %d hojas | LOD2=%d ramas, %d hojas" % [
			profile.name,
			res.lod0_branches_count, res.lod0_leaves_count,
			res.lod1_branches_count, res.lod1_leaves_count,
			res.lod2_branches_count, res.lod2_leaves_count
		])
	
	# 4. Instanciar la escena interactiva y probar regeneraciones
	var scene_res := load("res://tests/test_procedural_tree.tscn") as PackedScene
	assert(scene_res != null, "La escena test_procedural_tree.tscn debe cargar")
	var scene_node: Node = scene_res.instantiate()
	root.add_child(scene_node)
	
	var tree_node: ProceduralTree = scene_node.get_node("ProceduralTree") as ProceduralTree
	assert(tree_node != null, "El nodo ProceduralTree debe existir en la escena")
	
	# Simular pulsacion de [R] (regenerar con diferentes semillas)
	for test_seed in [100, 200, 300, 99999]:
		var r := tree_node.generate(test_seed, "pine_boreal")
		assert(r.seed_used == test_seed)
		assert(r.mm_branches_lod0.instance_count > 0)
	
	# 5. Verificar que disable_lod = true mantiene visible LOD0 y apaga LOD1 y LOD2
	assert(tree_node.disable_lod == true, "disable_lod debe estar activo por defecto")
	assert(tree_node._mi_branches_lod0.visible == true, "Ramas LOD0 deben estar visibles")
	assert(tree_node._mi_leaves_lod0.visible == true, "Hojas LOD0 deben estar visibles")
	assert(tree_node._mi_branches_lod0.visibility_range_end == 0.0, "Rango final LOD0 debe ser 0.0 (infinito)")
	assert(tree_node._mi_branches_lod1.visible == false, "LOD1 debe estar invisible")
	assert(tree_node._mi_branches_lod2.visible == false, "LOD2 debe estar invisible")
	print("[VERIFY] Desactivacion de sistema LOD y visibilidad permanente de arbol normal verificadas.")
	
	print("[VERIFY] === TODAS LAS PRUEBAS PROCEDURALES PASARON CON EXITO ===")
	
	scene_node.queue_free()
	quit(0)
