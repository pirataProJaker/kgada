@tool
extends SceneTree

func _init() -> void:
	print("\n=== TEST DE RESILIENCIA Y AUTO-ACOMODACIÓN DEL ATLAS INTELIGENTE ===")

	var FTM = preload("res://world/furniture/furniture_texture_manager.gd")
	var Atlas = preload("res://world/object_engine/object_atlas.gd")

	Atlas.ensure_initialized()
	var initial_keys := FTM.get_all_keys()
	print("1. Texturas iniciales detectadas (%d): %s" % [initial_keys.size(), ", ".join(initial_keys)])

	# Verificar que maderas base siempre sean 0, 1, 2, 3
	assert(FTM.get_texture_layer("roble_claro") == 0, "Roble debe ser capa 0")
	assert(FTM.get_texture_layer("nogal_oscuro") == 1, "Nogal debe ser capa 1")
	assert(FTM.get_texture_layer("caoba_rojiza") == 2, "Caoba debe ser capa 2")
	assert(FTM.get_texture_layer("pino_natural") == 3, "Pino debe ser capa 3")
	print("✓ Capas base ordenadas y deterministas (0..3).")

	# 2. Simular consulta a textura inexistente o eliminada
	var deleted_layer := FTM.get_texture_layer("textura_que_no_existe_o_fue_borrada")
	print("2. Consulta de textura inexistente: Capa retornada = %d (Fallback seguro)" % deleted_layer)
	assert(deleted_layer == 0, "Debe caer en capa 0 sin crasheos")

	# 3. Resolver semánticamente una textura eliminada
	var resolved_deleted := Atlas.resolve_semantic_texture("textura_fantasma", "region_x")
	print("3. Resolución semántica de textura eliminada: layer=%d, uv_rect=%s" % [resolved_deleted["layer"], str(resolved_deleted["uv_rect"])])
	assert(resolved_deleted["layer"] == 0, "Layer resuelto debe ser 0")

	# 4. Simular agregar una nueva imagen al vuelo
	print("4. Simulando inyección de nueva textura 'cafetera_test'...")
	var test_img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	test_img.fill(Color(0.2, 0.4, 0.8, 1.0))
	FTM.register_texture("cafetera_test", test_img, true)

	var new_keys := FTM.get_all_keys()
	var cafetera_layer := FTM.get_texture_layer("cafetera_test")
	print("   ✓ Nueva textura incorporada automáticamente. Total capas: %d. Capa asignada a 'cafetera_test': %d" % [new_keys.size(), cafetera_layer])
	assert(cafetera_layer > 0, "Cafetera debe tener una capa válida")

	# 5. Comprobar que las capas de los demás objetos no se corrompieron
	var cabinets_layer := FTM.get_texture_layer("cabinets")
	var resolved_granite := Atlas.resolve_semantic_texture("granito")
	print("5. Verificación de textura existente ('cabinets' / 'granito'):")
	print("   - Capa cabinets: %d" % cabinets_layer)
	print("   - Capa resuelta de granito: %d (coincide: %s)" % [resolved_granite["layer"], str(resolved_granite["layer"] == cabinets_layer)])
	assert(resolved_granite["layer"] == cabinets_layer, "Granito debe coincidir exactamente con cabinets")

	print("\n=== TODAS LAS PRUEBAS DE AUTO-ACOMODACIÓN Y RESILIENCIA PASARON CON ÉXITO ===")
	quit(0)
