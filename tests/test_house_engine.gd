extends SceneTree

func _init() -> void:
	if ClassDB.class_exists("ProceduralHouseEngine"):
		var engine = ClassDB.instantiate("ProceduralHouseEngine")
		print("✓ ProceduralHouseEngine instanciado con éxito: ", engine)
		
		# Probar generación de 3 casas con diferentes tipologías
		var zones = [0, 1, 2]
		var zone_names = ["ColoniaVieja", "ColoniaNueva", "ZonaX"]
		var dims = [Vector2i(10, 16), Vector2i(7, 15), Vector2i(20, 22)]
		
		for idx in range(3):
			var res = engine.generate_house(dims[idx].x, dims[idx].y, zones[idx], 12345 + idx * 777, true)
			print("\n--- TEST CASA: %s (%dx%dm) ---" % [zone_names[idx], dims[idx].x, dims[idx].y])
			print("  Pisos: %d | Terraza: %s" % [res.get("floors"), res.get("has_terrace")])
			print("  Celdas PB: %d | Celdas PA: %d" % [res.get("built_cells"), res.get("floor2_cells")])
			print("  Cajas de colisión: %d" % [res.get("collision_boxes").size()])
			var solid_mm: MultiMesh = res.get("solid_multimesh", null)
			if solid_mm:
				print("  ✓ solid_multimesh: %d instancias GPU (Draw call: 1)" % [solid_mm.instance_count])
			var glass_mm: MultiMesh = res.get("glass_multimesh", null)
			if glass_mm:
				print("  ✓ glass_multimesh: %d instancias GPU (Draw call: 1)" % [glass_mm.instance_count])
			var rooms: Array = res.get("rooms", [])
			print("  ✓ Habitaciones interiores reclamadas: %d" % [rooms.size()])
			for r in rooms:
				print("    - [%s F%d] (%d,%d) a (%d,%d)" % [r.name, r.floor, r.x_min, r.z_min, r.x_max, r.z_max])
	else:
		print("ERROR: ProceduralHouseEngine no existe en ClassDB")
	quit(0)
