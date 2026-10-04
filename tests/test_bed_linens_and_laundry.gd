@tool
extends SceneTree

# Test exhaustivo de variantes de cama, ropa de cama (40 patrones), descanso reparador y ciclo de lavandería

const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const ApplianceWasherScript = preload("res://world/furniture/appliance_washer.gd")
const ApplianceDryerScript = preload("res://world/furniture/appliance_dryer.gd")
const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureStorageContainerScript = preload("res://world/furniture/furniture_storage_container.gd")

func _init() -> void:
	print("\n=== INICIANDO TEST DE VARIANTES DE CAMA, TELAS Y LAVANDERÍA ===")

	# 1. Validar Catálogo del Atlas de Telas
	print("\n[1] Validando Catálogo del Atlas Inteligente...")
	assert(FurnitureTextureManagerScript.get_sheet_count() == 16, "Deben haber 16 sábanas registradas")
	assert(FurnitureTextureManagerScript.get_blanket_count() == 24, "Deben haber 24 cobijas registradas")
	print("  OK: 16 sábanas registradas (Fila 0 y 1). Ejemplo: '%s'" % FurnitureTextureManagerScript.get_sheet_name(2))
	print("  OK: 24 cobijas registradas (Fila 2, 3 y 4). Ejemplo: '%s'" % FurnitureTextureManagerScript.get_blanket_name(12))

	# 2. Validar generación de mallas modulares
	print("\n[2] Validando Generación de Mallas Modulares de Cama...")
	var frame_m := FurniturePropsBuilderScript.get_bed_frame_mesh()
	assert(frame_m != null and frame_m.get_surface_count() > 0, "Armazón de cama debe ser válido")

	var mat_m := FurniturePropsBuilderScript.get_bed_mattress_mesh(2, false, 0.0)
	assert(mat_m != null and mat_m.get_surface_count() > 0, "Colchón con sábana debe ser válido")

	var bare_m := FurniturePropsBuilderScript.get_bed_mattress_mesh(0, true, 0.0)
	assert(bare_m != null and bare_m.get_surface_count() > 0, "Colchón desnudo debe ser válido")

	var made_m := FurniturePropsBuilderScript.get_bed_quilt_made_mesh(12, 0.0)
	assert(made_m != null and made_m.get_surface_count() > 0, "Cobija tendida (Lobo) debe ser válida")

	var unmade_m := FurniturePropsBuilderScript.get_bed_quilt_unmade_mesh(1, 0.0)
	assert(unmade_m != null and unmade_m.get_surface_count() > 0, "Cobija destendida (Tartán) debe ser válida")

	var pillow_m := FurniturePropsBuilderScript.get_bed_pillow_mesh(false, 0.0)
	assert(pillow_m != null and pillow_m.get_surface_count() > 0, "Almohada debe ser válida")

	var unified_m := FurniturePropsBuilderScript.get_bed_custom_mesh(0, 2, 12, true, 0.0)
	assert(unified_m != null and unified_m.get_surface_count() == 2, "Cama combinada debe tener 2 superficies (madera + telas)")
	print("  OK: Todas las mallas modulares y unificadas se compilaron exitosamente.")

	# 3. Validar Estados de la Cama y Mecánica de Descanso Reparador
	print("\n[3] Probando Estados y Mecánica de Descanso Reparador...")
	var bed := BedSingleOakScript.new()
	root.add_child(bed)

	# Estado A: Cama tendida, limpia, con cobija del lobo y almohada
	bed.bed_state = BedSingleOakScript.BedState.MADE
	bed.sheet_pattern_id = 2 # Sábana Azul Cielo
	bed.blanket_pattern_id = 12 # Cobertor Lobo San Marcos
	bed.has_pillow = true
	bed.dirt_pct = 0.0
	bed.is_wet = false

	var rest_optimal: Dictionary = bed.get_rest_quality()
	assert(rest_optimal["quality_score"] == 100.0, "Cama perfecta debe tener 100% calidad")
	assert(rest_optimal["is_optimal"] == true, "Debe ser calificado como óptimo")
	assert(rest_optimal["stamina_multiplier"] >= 1.25, "Debe bonificar estamina")
	print("  OK: Cama óptima -> Calidad 100%% (%s), Estamina x%.2f, Moral +%d" % [
		rest_optimal["rating"], rest_optimal["stamina_multiplier"], rest_optimal["morale_buff"]
	])

	# Estado B: Cama destendida (UNMADE)
	bed.unmake_bed()
	assert(bed.bed_state == BedSingleOakScript.BedState.UNMADE, "Debe estar en estado UNMADE")
	var rest_unmade: Dictionary = bed.get_rest_quality()
	assert(rest_unmade["quality_score"] == 90.0, "Cama destendida tiene ligera penalización")
	print("  OK: Cama destendida -> Calidad %.0f%% (%s)" % [rest_unmade["quality_score"], rest_unmade["rating"]])

	# Volver a tender
	assert(bed.make_bed() == true, "Debe poderse tender")
	assert(bed.bed_state == BedSingleOakScript.BedState.MADE, "Debe volver a MADE")

	# Estado C: Cama sin cobija (STRIPPED)
	var blanket_item := bed.strip_blanket()
	assert(not blanket_item.is_empty(), "strip_blanket() debe devolver el ítem de cobija")
	assert(blanket_item["id"] == "bed_blanket", "ID del ítem debe ser bed_blanket")
	assert(blanket_item["pattern_id"] == 12, "Debe conservar el patrón de cobija")
	assert(bed.bed_state == BedSingleOakScript.BedState.STRIPPED, "Cama debe quedar en STRIPPED")
	var rest_stripped: Dictionary = bed.get_rest_quality()
	assert(rest_stripped["quality_score"] == 75.0, "Cama sin cobija penaliza 25% por frío")
	print("  OK: Cobija retirada como ítem ('%s'). Cama pasa a STRIPPED (Calidad: %.0f%%)" % [
		blanket_item["name"], rest_stripped["quality_score"]
	])

	# Intentar tender sin cobija (debe fallar)
	assert(bed.make_bed() == false, "No se puede tender una cama sin cobija")

	# Estado D: Cama sin sábana (BARE_MATTRESS)
	var sheet_item := bed.strip_sheet()
	assert(not sheet_item.is_empty(), "strip_sheet() debe devolver el ítem de sábana")
	assert(sheet_item["id"] == "bed_sheet", "ID del ítem debe ser bed_sheet")
	assert(sheet_item["pattern_id"] == 2, "Debe conservar el patrón de sábana")
	assert(bed.bed_state == BedSingleOakScript.BedState.BARE_MATTRESS, "Cama debe quedar en BARE_MATTRESS")

	# Retirar almohada y aplicar suciedad
	bed.has_pillow = false
	bed.apply_dirt(0.50)
	var rest_bare: Dictionary = bed.get_rest_quality()
	assert(rest_bare["quality_score"] < 40.0, "Cama desnuda sin almohada y sucia debe ser pésima")
	print("  OK: Cama desnuda, sin almohada y sucia -> Calidad %.0f%% (%s)" % [
		rest_bare["quality_score"], rest_bare["rating"]
	])

	# 4. Probar Loop de Lavandería (Lavadora y Secadora)
	print("\n[4] Probando Ciclo de Lavandería e Intercambio de Ropa de Cama...")
	var washer := ApplianceWasherScript.new()
	var dryer := ApplianceDryerScript.new()
	root.add_child(washer)
	root.add_child(dryer)

	var washer_storage: RefCounted = FurnitureStorageContainerScript.new(FurnitureStorageContainerScript.StorageMode.ABSTRACT_METRIC, 5)
	var dryer_storage: RefCounted = FurnitureStorageContainerScript.new(FurnitureStorageContainerScript.StorageMode.ABSTRACT_METRIC, 5)

	# Manchar la sábana
	sheet_item["dirt_pct"] = 0.85
	sheet_item["wetness_pct"] = 0.0
	print("  Sábana antes de lavar: Suciedad %.0f%%, Humedad %.0f%%" % [sheet_item["dirt_pct"] * 100, sheet_item["wetness_pct"] * 100])

	# Abrir lavadora y meter sábana
	washer.door_open_ratio = 1.0
	washer_storage.set_open_state(true)
	assert(washer_storage.add_item(sheet_item) == true, "Cargar sábana a la lavadora")
	washer.door_open_ratio = 0.0
	washer_storage.set_open_state(false)

	# Ejecutar ciclo de lavado
	washer_storage.run_laundry_cycle("wash")

	var washed_sheet: Dictionary = washer_storage.remove_item_at_slot(0)
	assert(washed_sheet["dirt_pct"] == 0.0, "La sábana debe quedar 100% limpia tras el lavado")
	assert(washed_sheet["wetness_pct"] == 1.0, "La sábana debe quedar mojada tras el lavado")
	print("  Sábana después de lavar: Suciedad %.0f%%, Humedad %.0f%%" % [washed_sheet["dirt_pct"] * 100, washed_sheet["wetness_pct"] * 100])

	# Meter sábana mojada a la secadora
	dryer.door_open_ratio = 1.0
	dryer_storage.set_open_state(true)
	assert(dryer_storage.add_item(washed_sheet) == true, "Cargar sábana a secadora")
	dryer.door_open_ratio = 0.0
	dryer_storage.set_open_state(false)

	# Ejecutar ciclo de secado
	dryer_storage.run_laundry_cycle("dry")

	var dried_sheet: Dictionary = dryer_storage.remove_item_at_slot(0)
	assert(dried_sheet["dirt_pct"] == 0.0, "La sábana debe seguir limpia")
	assert(dried_sheet["wetness_pct"] == 0.0, "La sábana debe salir 100% seca de la secadora")
	print("  Sábana después de secar: Suciedad %.0f%%, Humedad %.0f%%" % [dried_sheet["dirt_pct"] * 100, dried_sheet["wetness_pct"] * 100])

	# Reequipar la sábana limpia y seca en la cama
	assert(bed.equip_sheet(dried_sheet) == true, "Equipar sábana limpia en la cama")
	assert(bed.bed_state == BedSingleOakScript.BedState.STRIPPED, "Pasa de BARE_MATTRESS a STRIPPED")

	# Reequipar almohada
	bed.equip_pillow({ "id": "bed_pillow", "dirt_pct": 0.0 })

	# Equipar nueva cobija (por ejemplo, Cobertor Leopardo Salvaje blanket 14)
	var new_blanket := {
		"id": "bed_blanket",
		"name": FurnitureTextureManagerScript.get_blanket_name(14),
		"pattern_id": 14,
		"dirt_pct": 0.0,
		"wetness_pct": 0.0
	}
	assert(bed.equip_blanket(new_blanket) == true, "Equipar cobertor de leopardo")
	assert(bed.bed_state == BedSingleOakScript.BedState.MADE, "Cama queda tendida")
	assert(bed.blanket_pattern_id == 14, "Patrón de cobija actualizado a leopardo")

	var final_rest: Dictionary = bed.get_rest_quality()
	assert(final_rest["quality_score"] == 100.0, "La cama debe volver al 100% de calidad tras el reacondicionamiento")
	print("  OK: Cama reequipada con Sábana '%s' y Cobertor '%s' limpia al 100%%!" % [
		FurnitureTextureManagerScript.get_sheet_name(bed.sheet_pattern_id),
		FurnitureTextureManagerScript.get_blanket_name(bed.blanket_pattern_id)
	])

	print("\n=======================================================")
	print(">>> TODOS LOS TESTS DE CAMAS Y TELAS PASARON (0 ERRORES) <<<")
	print("=======================================================\n")
	quit(0)
