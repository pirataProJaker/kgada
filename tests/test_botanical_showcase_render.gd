@tool
extends SceneTree

func _init() -> void:
	print("--- TEST DE CARGA DE ESCENA BOTANICAL SHOWCASE ---")
	
	var scene_res = load("res://scenes/botanical_growth_showcase.tscn")
	if not scene_res:
		print("ERROR: No se pudo cargar res://scenes/botanical_growth_showcase.tscn")
		quit(1)
		return
	
	var scene = scene_res.instantiate()
	root.add_child(scene)
	print("  scene.is_node_ready() antes de frame: ", scene.is_node_ready())
	
	# Si no ha ejecutado _ready todavía, llamamos a scene._ready() o emitimos la notificación
	if not scene.is_node_ready():
		# En scripts de SceneTree sin loop asíncrono, forzamos la inicialización
		scene._ready()
	
	print("  scene.is_node_ready() después: ", scene.is_node_ready())
	
	# Verificar árbol principal
	var main_tree = scene.main_tree
	assert(main_tree != null, "main_tree debe existir")
	print("✓ main_tree existe. Altura: %.2f m, Tris: %d, Ramas: %d" % [
		main_tree.get_height(),
		main_tree.get_total_triangles(),
		main_tree.get_branch_count()
	])
	
	# Probar cambio a modo 1 (LODs lineup)
	scene._switch_mode(1)
	print("✓ Modo 1 (LODs Lineup) activado correctamente.")
	assert(scene.lod_trees.size() == 4, "Deben haber 4 árboles en la comparativa de LOD")
	for i in range(4):
		print("    Tree LOD %d: %d triángulos" % [i, scene.lod_trees[i].get_total_triangles(i)])
	
	# Probar cambio a modo 2 (Timeline)
	scene._switch_mode(2)
	print("✓ Modo 2 (Timeline) activado correctamente.")
	assert(scene.timeline_trees.size() == 4, "Deben haber 4 árboles en la línea de tiempo")
	for i in range(4):
		print("    Timeline %d: Edad=%.2f, Altura=%.2f m, Tris=%d" % [
			i,
			scene.timeline_trees[i].age,
			scene.timeline_trees[i].get_height(),
			scene.timeline_trees[i].get_total_triangles()
		])
	
	# Probar poda interactiva en modo 0
	scene._switch_mode(0)
	var branches_before = main_tree.get_branch_count()
	scene._on_prune_pressed()
	var branches_after = main_tree.get_branch_count()
	print("✓ Poda en UI: Ramas antes=%d, Ramas después=%d" % [branches_before, branches_after])
	assert(branches_after < branches_before, "Debe reducirse la cantidad de ramas tras podar")
	
	scene._on_restore_pressed()
	var branches_restored = main_tree.get_branch_count()
	print("✓ Restaurar en UI: Ramas restauradas=%d" % branches_restored)
	assert(branches_restored == branches_before, "Debe restaurarse tras presionar restaurar")
	
	# Limpieza
	scene.queue_free()
	print("\n=== VERIFICACION DE ESCENA SHOWCASE EXITOSA ===")
	quit(0)
