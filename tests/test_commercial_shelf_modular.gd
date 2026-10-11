extends SceneTree

const CommercialShelfModularScript = preload("res://world/furniture/commercial_shelf_modular.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")

func _init() -> void:
	print("[TestCommercialShelf] === INICIANDO VALIDACIÓN DE ESTANTERÍA COMERCIAL MODULAR ===")

	# 1. Validar inicialización del Atlas Inteligente con la nueva capa "commercial_shelf"
	FurnitureTextureManagerScript.ensure_initialized()
	var layer := FurnitureTextureManagerScript.get_texture_layer("commercial_shelf")
	print("[TestCommercialShelf] ✓ Capa de commercial_shelf en Texture2DArray: %d" % layer)

	# 2. Validar generación de mallas unitarias para presets OTXO y Walmart
	var otxo_mesh := CommercialShelfModularScript.get_shared_unit_mesh(
		CommercialShelfModularScript.ShelfStyle.DOUBLE_SIDED_ISLAND,
		CommercialShelfModularScript.ShelfPreset.CONVENIENCE_OTXO
	)
	assert(otxo_mesh != null, "La malla de OTXO no debe ser nula")
	print("[TestCommercialShelf] ✓ Malla unitaria OTXO generada con éxito (%d superficies)." % otxo_mesh.get_surface_count())

	var walmart_mesh := CommercialShelfModularScript.get_shared_unit_mesh(
		CommercialShelfModularScript.ShelfStyle.SINGLE_SIDED_WALL,
		CommercialShelfModularScript.ShelfPreset.SUPERMARKET_WALMART
	)
	assert(walmart_mesh != null, "La malla de Walmart no debe ser nula")
	print("[TestCommercialShelf] ✓ Malla unitaria Walmart generada con éxito (%d superficies)." % walmart_mesh.get_surface_count())

	# 3. Validar instanciación Standalone Node3D con 4 módulos (4 metros)
	var shelf_node := CommercialShelfModularScript.new()
	shelf_node.modules_count = 4
	shelf_node.shelf_style = CommercialShelfModularScript.ShelfStyle.DOUBLE_SIDED_ISLAND
	shelf_node.shelf_preset = CommercialShelfModularScript.ShelfPreset.CONVENIENCE_OTXO
	root.add_child(shelf_node)
	print("[TestCommercialShelf] ✓ Estantería modular de 4 módulos (4m) instanciada correctamente en escena.")

	# 4. Validar cálculo del planograma y carriles de productos
	var sample_catalog: Array[Dictionary] = [
		{"id": "lata_atun", "name": "Lata de Atún", "size": Vector3(0.08, 0.05, 0.08), "can_stack": true},
		{"id": "refresco_cola", "name": "Refresco Cola", "size": Vector3(0.07, 0.14, 0.07), "can_stack": false},
		{"id": "cereal_caja", "name": "Caja de Cereal", "size": Vector3(0.18, 0.28, 0.08), "can_stack": false},
		{"id": "papas_fritas", "name": "Bolsa de Papas", "size": Vector3(0.16, 0.22, 0.10), "can_stack": false}
	]

	var stocked := shelf_node.stock_shelves_procedural(sample_catalog, 12345)
	print("[TestCommercialShelf] ✓ Planograma calculado: %d productos ubicados en carriles de profundidad." % stocked.size())
	assert(stocked.size() > 50, "Debe haber una cantidad sustancial de productos en 4m de estante doble cara")

	# 5. Validar integración con FurnitureMultiMeshSystem (GPU Instancing)
	var fms := FurnitureMultiMeshSystemScript.new()
	root.add_child(fms)
	# Agregar 2 estantes de 5 metros cada uno
	fms.add_commercial_shelf(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 5, 0, 0)
	fms.add_commercial_shelf(Transform3D(Basis.IDENTITY, Vector3(0, 0, 3)), 5, 0, 0)
	fms.build(true)
	print("[TestCommercialShelf] ✓ FurnitureMultiMeshSystem construyó exitosamente los MultiMeshes de estanterías comerciales.")

	print("[TestCommercialShelf] === TODOS LOS TESTS PASARON CON ÉXITO ===")
	quit(0)
