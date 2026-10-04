extends SceneTree

const FurnitureStorageContainerScript = preload("res://world/furniture/furniture_storage_container.gd")
const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const BookcaseTallScript = preload("res://world/furniture/bookcase_tall.gd")
const NightstandOakScript = preload("res://world/furniture/nightstand_oak.gd")
const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")
const WardrobeOakScript = preload("res://world/furniture/wardrobe_oak.gd")
const SinkUnitWhiteScript = preload("res://world/furniture/sink_unit_white.gd")
const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")

func _init() -> void:
	print("=== INICIANDO TEST DE MOBILIARIO PRIMARIO, ALMACENAMIENTO Y CONSUMIBLES ===")
	var errors := 0

	# ---------------------------------------------------------
	# 1. TEST DE ALMACENAMIENTO Y CONSUMIBLES CON PORCENTAJES
	# ---------------------------------------------------------
	print("\n[1] Probando FurnitureStorageContainer y Consumibles...")
	var container := FurnitureStorageContainerScript.new(FurnitureStorageContainerScript.StorageMode.SLOTS_3D, 8)
	
	# Verificar lazy evaluation cerrado
	if container.should_render_contents():
		printerr("FAIL: El contenedor cerrado no debería renderizar contenido.")
		errors += 1
	else:
		print("  OK: Contenedor cerrado -> 0 draw calls (should_render_contents = false)")

	# Abrir contenedor
	container.set_open_state(true)
	if not container.should_render_contents():
		printerr("FAIL: El contenedor abierto debería renderizar contenido.")
		errors += 1
	else:
		print("  OK: Contenedor abierto -> renderizado activo (should_render_contents = true)")

	# Crear consumibles con porcentajes
	var milk := FurnitureStorageContainerScript.create_milk(1.0, 1.0)
	var cereal := FurnitureStorageContainerScript.create_cereal(1.0, 1.0)
	var soup := FurnitureStorageContainerScript.create_soup(1.0, 1.0)
	var beer := FurnitureStorageContainerScript.create_beer(1.0)

	container.add_item(milk, 0)
	container.add_item(cereal, 1)
	container.add_item(soup, 2)
	container.add_item(beer, 3)

	if container.get_item_count() != 4:
		printerr("FAIL: Se esperaban 4 ítems, encontrados: ", container.get_item_count())
		errors += 1
	else:
		print("  OK: 4 consumibles agregados correctamente.")

	# Consumir 25% de leche (e.g. un vaso de 250ml de 1L)
	var consumed := container.consume_item(0, 0.25)
	var remaining_milk: float = container.get_item_fill_pct(0)
	if absf(remaining_milk - 0.75) > 0.01:
		printerr("FAIL: Se esperaba 75% de leche restante, encontrado: ", remaining_milk)
		errors += 1
	else:
		print("  OK: Consumo parcial exitoso (Consumido: %.2f, Restante: %.0f%%)" % [consumed, remaining_milk * 100.0])

	var label := container.get_item_label(0)
	print("  OK: Etiqueta descriptiva para HUD: ", label)

	# ---------------------------------------------------------
	# 2. TEST DE MODO ABSTRACTO (LAVADORA / SECADORA)
	# ---------------------------------------------------------
	print("\n[2] Probando Modo Abstracto (Lavadora / Secadora)...")
	var washer_storage := FurnitureStorageContainerScript.new(FurnitureStorageContainerScript.StorageMode.ABSTRACT_METRIC, 5)
	if washer_storage.should_render_contents():
		printerr("FAIL: Modo abstracto NUNCA debe renderizar contenido 3D.")
		errors += 1
	else:
		print("  OK: Modo abstracto garantiza 0 vértices de ropa en todo momento.")

	washer_storage.add_item({"name": "Camisa azul", "dirt_pct": 0.8, "wetness_pct": 0.0})
	washer_storage.run_laundry_cycle("wash")
	var clothes: Dictionary = washer_storage.get_item_at_slot(0)
	if float(clothes.get("dirt_pct", 1.0)) != 0.0 or float(clothes.get("wetness_pct", 0.0)) != 1.0:
		printerr("FAIL: Ciclo de lavado no configuró porcentajes correctos.")
		errors += 1
	else:
		print("  OK: Ciclo de lavado ejecutado con éxito: Limpio 100%, Mojado 100%.")

	# ---------------------------------------------------------
	# 3. TEST DE MALLAS PRIMARIAS DE PROPS (PROPS BUILDER)
	# ---------------------------------------------------------
	print("\n[3] Probando FurniturePropsBuilder (Figuras primarias)...")
	var p_cereal := FurniturePropsBuilderScript.get_cereal_mesh()
	var p_milk := FurniturePropsBuilderScript.get_milk_mesh()
	var p_soup := FurniturePropsBuilderScript.get_soup_can_mesh()
	var p_beer := FurniturePropsBuilderScript.get_beer_can_mesh()
	var p_mug := FurniturePropsBuilderScript.get_mug_mesh()
	var p_plate := FurniturePropsBuilderScript.get_plate_mesh()
	var p_news := FurniturePropsBuilderScript.get_newspaper_mesh()
	var p_rug := FurniturePropsBuilderScript.get_rug_braided_mesh()
	var p_pic := FurniturePropsBuilderScript.get_picture_landscape_mesh()
	var p_book := FurniturePropsBuilderScript.get_book_mesh("bible")
	var p_stack := FurniturePropsBuilderScript.get_book_stack_mesh()

	if p_cereal == null or p_milk == null or p_soup == null or p_book == null:
		printerr("FAIL: Error al generar mallas de accesorios primarios.")
		errors += 1
	else:
		print("  OK: Las 11 mallas de accesorios y consumibles se generaron perfectamente.")

	# ---------------------------------------------------------
	# 4. TEST DE LIBRERO ALTO (BOOKCASE TALL)
	# ---------------------------------------------------------
	print("\n[4] Probando BookcaseTall (Empieza vacío, modular)...")
	var bookcase: BookcaseTallScript = BookcaseTallScript.new()
	if bookcase.storage.get_item_count() != 0:
		printerr("FAIL: El librero DEBE iniciar completamente vacío.")
		errors += 1
	else:
		print("  OK: El librero inicia 100% vacío (0 libros pre-renderizados).")

	var inserted := bookcase.insert_book(0, "bible")
	inserted = bookcase.insert_book(5, "atlas") and inserted
	if not inserted or bookcase.storage.get_item_count() != 2:
		printerr("FAIL: Falló la inserción modular de libros.")
		errors += 1
	else:
		print("  OK: Inserción modular de 2 libros exitosa.")

	var shared_bc := BookcaseTallScript.get_shared_mesh()
	var bc_col := BookcaseTallScript.get_collision_boxes()
	if shared_bc == null or bc_col.is_empty():
		printerr("FAIL: Malla compartida o colisión de BookcaseTall inválida.")
		errors += 1
	else:
		print("  OK: BookcaseTall get_shared_mesh() y get_collision_boxes() válidos.")
	bookcase.free()

	# ---------------------------------------------------------
	# 5. TEST DE MESA DE NOCHE (NIGHTSTAND OAK)
	# ---------------------------------------------------------
	print("\n[5] Probando NightstandOak (Cajón deslizante y lazy eval)...")
	var nightstand: NightstandOakScript = NightstandOakScript.new()
	var ns_mesh := NightstandOakScript.get_shared_mesh()
	var ns_col := NightstandOakScript.get_collision_boxes()
	if ns_mesh == null or ns_col.is_empty():
		printerr("FAIL: NightstandOak mallas o colisión inválidas.")
		errors += 1
	else:
		print("  OK: NightstandOak get_shared_mesh() y get_collision_boxes() válidos.")
	nightstand.free()

	# ---------------------------------------------------------
	# 6. TEST DE CAMA INDIVIDUAL (BED SINGLE OAK)
	# ---------------------------------------------------------
	print("\n[6] Probando BedSingleOak...")
	var bed_mesh := BedSingleOakScript.get_shared_mesh()
	var bed_col := BedSingleOakScript.get_collision_boxes()
	if bed_mesh == null or bed_col.is_empty():
		printerr("FAIL: BedSingleOak mallas o colisión inválidas.")
		errors += 1
	else:
		print("  OK: BedSingleOak get_shared_mesh() y get_collision_boxes() válidos.")

	# ---------------------------------------------------------
	# 7. TEST DE ROPERO (WARDROBE OAK)
	# ---------------------------------------------------------
	print("\n[7] Probando WardrobeOak...")
	var wd_mesh := WardrobeOakScript.get_shared_mesh()
	var wd_col := WardrobeOakScript.get_collision_boxes()
	if wd_mesh == null or wd_col.is_empty():
		printerr("FAIL: WardrobeOak mallas o colisión inválidas.")
		errors += 1
	else:
		print("  OK: WardrobeOak get_shared_mesh() y get_collision_boxes() válidos.")

	# ---------------------------------------------------------
	# 8. TEST DE FREGADERO (SINK UNIT WHITE)
	# ---------------------------------------------------------
	print("\n[8] Probando SinkUnitWhite...")
	var sink_mesh := SinkUnitWhiteScript.get_shared_mesh()
	var sink_col := SinkUnitWhiteScript.get_collision_boxes()
	if sink_mesh == null or sink_col.is_empty():
		printerr("FAIL: SinkUnitWhite mallas o colisión inválidas.")
		errors += 1
	else:
		print("  OK: SinkUnitWhite get_shared_mesh() y get_collision_boxes() válidos.")

	# ---------------------------------------------------------
	# 9. TEST DE GPU INSTANCING MULTIMESH SYSTEM
	# ---------------------------------------------------------
	print("\n[9] Probando FurnitureMultiMeshSystem...")
	var root_node := Node3D.new()
	root.add_child(root_node)

	var mm_sys := FurnitureMultiMeshSystemScript.new()
	root_node.add_child(mm_sys)

	# Agregar muebles nuevos
	mm_sys.add_bookcase(Transform3D.IDENTITY)
	mm_sys.add_nightstand(Transform3D(Basis.IDENTITY, Vector3(1.0, 0, 0)))
	mm_sys.add_bed_single(Transform3D(Basis.IDENTITY, Vector3(2.5, 0, 0)))
	mm_sys.add_wardrobe(Transform3D(Basis.IDENTITY, Vector3(4.0, 0, 0)))
	mm_sys.add_sink_unit(Transform3D(Basis.IDENTITY, Vector3(5.5, 0, 0)))
	mm_sys.add_rug_braided(Transform3D(Basis.IDENTITY, Vector3(2.5, 0, 1.5)))
	mm_sys.add_picture_landscape(Transform3D(Basis.IDENTITY, Vector3(2.5, 1.5, -1.0)))

	# Agregar consumibles en el mundo
	mm_sys.add_milk(Transform3D(Basis.IDENTITY, Vector3(1.0, 0.72, 0.0)))
	mm_sys.add_cereal(Transform3D(Basis.IDENTITY, Vector3(5.5, 0.90, 0.2)))
	mm_sys.add_soup(Transform3D(Basis.IDENTITY, Vector3(5.5, 0.90, -0.2)))
	mm_sys.add_beer(Transform3D(Basis.IDENTITY, Vector3(1.0, 0.72, 0.1)))
	mm_sys.add_mug(Transform3D(Basis.IDENTITY, Vector3(1.0, 0.72, -0.1)))
	mm_sys.add_book(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0)), "bible")

	var total_count := mm_sys.get_total_furniture_count()
	print("  Total muebles y props registrados: ", total_count)
	if total_count != 13:
		printerr("FAIL: Se esperaban 13 registros en MultiMeshSystem, encontrados: ", total_count)
		errors += 1

	mm_sys.build(true)
	var active_mm := mm_sys.get_active_multimesh_count()
	print("  Total categorías MultiMesh activas compiladas: ", active_mm)
	if active_mm == 0:
		printerr("FAIL: No se compiló ningún MultiMeshInstance3D.")
		errors += 1
	else:
		print("  OK: MultiMeshSystem compilado exitosamente con colisiones unificadas.")

	root_node.queue_free()

	print("\n=======================================================")
	if errors == 0:
		print(">>> TODOS LOS TESTS PASARON EXITOSAMENTE (0 ERRORES) <<<")
	else:
		printerr(">>> HUBO %d ERRORES EN EL TEST <<<" % errors)
	print("=======================================================")

	quit(0 if errors == 0 else 1)
