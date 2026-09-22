extends SceneTree

const ChunkManager = preload("res://world/chunk_manager.gd")

func _init() -> void:
	print("--- TEST DE ECOLOGIA Y BIOMAS EN CHUNK MANAGER ---")
	
	# 1. Probar ruido de biomas
	var b_spawn = ChunkManager.get_biome_noise(0.0, 0.0)
	print("Bioma en Spawn (0, 0): %.4f (esperado: < 0.12 para Pradera Verde)" % b_spawn)
	assert(b_spawn < 0.12, "El spawn no es pradera verde")
	
	# 2. Instanciar ChunkManager
	var cm = ChunkManager.new()
	cm._init_shared_terrain_material()
	
	# 3. Validar mallas y materiales de pasto y flores
	var grass_mesh = cm._get_grass_mesh()
	assert(grass_mesh != null, "Error creando malla de pasto FBX")
	print("✓ Malla de pasto PSX cargada exitosamente")
	
	var daisy_mesh = cm._get_flower_mesh("daisy")
	var lavender_mesh = cm._get_flower_mesh("lavender")
	var poppy_mesh = cm._get_flower_mesh("poppy")
	assert(daisy_mesh != null and lavender_mesh != null and poppy_mesh != null, "Error creando mallas de flores")
	print("✓ Mallas de margaritas, lavandas y amapolas creadas exitosamente")
	
	var flower_mat = cm._get_flower_material()
	assert(flower_mat != null, "Error creando material de flores")
	print("✓ Material de flores con shader de viento configurado")
	
	# 4. Probar distribución en varios chunks (simulación)
	var meadow_count = 0
	var trans_count = 0
	var forest_count = 0
	for cx in range(-5, 6):
		for cz in range(-5, 6):
			var wx = cx * 40.0 + 20.0
			var wz = cz * 40.0 + 20.0
			var bn = ChunkManager.get_biome_noise(wx, wz)
			if bn < 0.12:
				meadow_count += 1
			elif bn < 0.40:
				trans_count += 1
			else:
				forest_count += 1
	var total_tested = float(meadow_count + trans_count + forest_count)
	print("Distribución de biomas en 121 chunks (área de 440m x 440m):")
	print("  Pradera Verde (Meadow): %d (%.1f%%)" % [meadow_count, meadow_count / total_tested * 100.0])
	print("  Transición / Arboleda: %d (%.1f%%)" % [trans_count, trans_count / total_tested * 100.0])
	print("  Bosque Denso / Tierra: %d (%.1f%%)" % [forest_count, forest_count / total_tested * 100.0])
	
	cm.free()
	print("\n=== TODAS LAS PRUEBAS DE ECOLOGIA PASARON EXITOSAMENTE ===")
	quit(0)
