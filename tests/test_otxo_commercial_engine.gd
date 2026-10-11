extends SceneTree

func _init() -> void:
	if ClassDB.class_exists("ProceduralHouseEngine"):
		var engine = ClassDB.instantiate("ProceduralHouseEngine")
		print("✓ ProceduralHouseEngine instanciado con éxito.")

		# Probar 2 lotes comerciales OTXO:
		# 1. Lote regular (14m x 16m) - Estacionamiento frontal simple
		# 2. Lote esquina grande (18m x 18m) - Estacionamiento doble en L
		var test_cases = [
			{"name": "OTXO Lote Regular", "w": 14, "d": 16, "seed": 5555},
			{"name": "OTXO Esquina Grande (L-Parking)", "w": 18, "d": 18, "seed": 7777}
		]

		for tc in test_cases:
			print("\n==================================================")
			print("--- PROBANDO %s (%dx%dm) ---" % [tc["name"], tc["w"], tc["d"]])
			var res: Dictionary = engine.generate_house(tc["w"], tc["d"], 3, tc["seed"], true)

			print("  Zona: %d (CommercialConvenience)" % res.get("zone_type", -1))
			print("  Pisos: %d (esperado: 1)" % res.get("floors", 0))
			print("  Celdas construidas: %d" % res.get("built_cells", 0))
			print("  Cajas de colisión: %d" % res.get("collision_boxes", []).size())

			var solid_mm: MultiMesh = res.get("solid_multimesh", null)
			if solid_mm:
				print("  ✓ solid_multimesh: %d instancias GPU" % solid_mm.instance_count)
			var glass_mm: MultiMesh = res.get("glass_multimesh", null)
			if glass_mm:
				print("  ✓ glass_multimesh: %d instancias GPU (muro cortina)" % glass_mm.instance_count)

			var rooms: Array = res.get("rooms", [])
			print("  ✓ Habitaciones (%d reclamadas):" % rooms.size())
			for r in rooms:
				print("    - [%s F%d] (%d,%d) a (%d,%d)" % [r.name, r.floor, r.x_min, r.z_min, r.x_max, r.z_max])

			var comm: Dictionary = res.get("commercial", {})
			if not comm.is_empty():
				var bays: Array = comm.get("parking_bays", [])
				print("  ✓ Cajones de estacionamiento: %d" % bays.size())
				for b in bays:
					print("    * Cajón en pos: %s, tamaño: %s, rot_y: %.2f" % [b.position, b.size, b.rotation_y])

				var totem: Dictionary = comm.get("totem_sign", {})
				if not totem.is_empty():
					print("  ✓ Tótem Gigante Exterior: pos: %s, altura: %.2fm, rot_y: %.2f" % [totem.position, totem.height, totem.rotation_y])

				var fascia: Array = comm.get("fascia_signs", [])
				print("  ✓ Letreros de Fachada/Marquesina: %d" % fascia.size())
				for fs in fascia:
					print("    * Letrero en pos: %s, tamaño: %s" % [fs.position, fs.size])

				var bollards: Array = comm.get("bollards", [])
				print("  ✓ Bolardos Protectores: %d" % bollards.size())

				if comm.has("ice_freezer"):
					print("  ✓ Hielera exterior: %s" % comm.ice_freezer)
				if comm.has("trash_bin"):
					print("  ✓ Bote de basura doble: %s" % comm.trash_bin)
			else:
				printerr("  ERROR: No se generaron metadatos comerciales!")
	else:
		printerr("ERROR: ProceduralHouseEngine no existe en ClassDB")
	quit(0)
