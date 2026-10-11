extends SceneTree

func _initialize() -> void:
	print("--- TEST DE VERIFICACION: CONMUTACION DE SOMBRAS DETALLADAS Y SIMPLES ---")
	
	var settings_mgr = root.get_node_or_null("SettingsManager")
	if settings_mgr == null:
		var SettingsManagerScript = preload("res://autoload/settings_manager.gd")
		settings_mgr = SettingsManagerScript.new()
		settings_mgr.name = "SettingsManager"
		root.add_child(settings_mgr)
	
	# Instanciar árbol
	var tree := ProceduralTree.new()
	tree.profile_id = "classic_oak"
	tree.tree_seed = 999
	tree.cast_shadows = true
	root.add_child(tree)
	
	await process_frame
	await process_frame
	
	var mi_branches = tree.get_node("Branches_LOD0") as MultiMeshInstance3D
	var mi_leaves = tree.get_node("Leaves_LOD0") as MultiMeshInstance3D
	var mi_simple_shadow = tree.get_node("SimpleShadowProxy") as MultiMeshInstance3D
	
	assert(mi_branches != null, "Branches_LOD0 debe existir")
	assert(mi_leaves != null, "Leaves_LOD0 debe existir")
	assert(mi_simple_shadow != null, "SimpleShadowProxy debe existir")
	assert(mi_simple_shadow.multimesh != null, "MultiMesh de SimpleShadowProxy debe estar inicializado")
	assert(mi_simple_shadow.multimesh.instance_count == 1, "SimpleShadowProxy debe tener 1 instancia de icosaedro")
	
	# 1. Probar modo 0: Detalladas
	settings_mgr.set_shadow_mode(0)
	print("[Modo 0 - Detalladas]")
	print("  Hojas cast_shadow: ", mi_leaves.cast_shadow)
	print("  SimpleShadowProxy visible: ", mi_simple_shadow.visible)
	print("  SimpleShadowProxy cast_shadow: ", mi_simple_shadow.cast_shadow)
	assert(mi_leaves.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "En detallado, hojas deben proyectar sombras")
	assert(mi_simple_shadow.visible == false, "En detallado, SimpleShadowProxy debe estar oculto")
	assert(mi_simple_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "En detallado, SimpleShadowProxy cast_shadow debe ser OFF")
	
	# 2. Probar modo 1: Simples
	settings_mgr.set_shadow_mode(1)
	print("[Modo 1 - Simples (Cacahuate)]")
	print("  Hojas cast_shadow: ", mi_leaves.cast_shadow)
	print("  Tronco cast_shadow: ", mi_branches.cast_shadow)
	print("  SimpleShadowProxy visible: ", mi_simple_shadow.visible)
	print("  SimpleShadowProxy cast_shadow: ", mi_simple_shadow.cast_shadow)
	assert(mi_leaves.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "En simple, hojas NO deben proyectar sombras (0 alpha scissor)")
	assert(mi_branches.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "En simple, tronco solido conecta al suelo")
	assert(mi_simple_shadow.visible == true, "En simple, SimpleShadowProxy debe estar visible")
	assert(mi_simple_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "En simple, SimpleShadowProxy debe ser SHADOWS_ONLY")
	
	# 3. Probar con pino boreal
	var pine := ProceduralTree.new()
	pine.profile_id = "pine_boreal"
	pine.tree_seed = 777
	pine.cast_shadows = true
	root.add_child(pine)
	
	await process_frame
	
	var pine_simple_shadow = pine.get_node("SimpleShadowProxy") as MultiMeshInstance3D
	assert(pine_simple_shadow != null and pine_simple_shadow.multimesh != null, "Pino boreal tambien debe tener SimpleShadowProxy")
	print("[Pino Boreal en Modo 1]")
	print("  Pino SimpleShadowProxy visible: ", pine_simple_shadow.visible)
	print("  Pino SimpleShadowProxy cast_shadow: ", pine_simple_shadow.cast_shadow)
	assert(pine_simple_shadow.visible == true, "Pino SimpleShadowProxy debe ser visible en modo 1")
	assert(pine_simple_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "Pino SimpleShadowProxy debe ser SHADOWS_ONLY")
	
	print("--- TODOS LOS TESTS PASARON EXITOSAMENTE (100% CORRECTO) ---")
	quit(0)
