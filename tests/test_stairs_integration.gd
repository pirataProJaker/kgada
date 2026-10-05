extends Node

func _ready() -> void:
	var f = FileAccess.open("res://scratch/stair_test_out.txt", FileAccess.WRITE)
	f.store_line("--- TEST DE INTEGRACIÓN DE ESCALERAS PROCEDURALES ---")
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		f.store_line("ERROR: ProceduralHouseEngine no está disponible en ClassDB.")
		f.close()
		get_tree().quit(1)
		return

	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	f.store_line("✓ ProceduralHouseEngine instanciado correctamente.")

	# Probamos varias semillas de casas de 2 pisos
	var test_configs = [
		{"name": "Colonia Vieja (10x16)", "w": 10, "d": 16, "zone": 0, "seed": 1009},
		{"name": "Colonia Nueva Infonavit (7x15)", "w": 7, "d": 15, "zone": 1, "seed": 2018},
		{"name": "Zona X Residencia (12x18)", "w": 12, "d": 18, "zone": 2, "seed": 3027},
	]

	for cfg in test_configs:
		f.store_line("\nGenerando: %s..." % cfg["name"])
		var res: Dictionary = engine.generate_house(cfg["w"], cfg["d"], cfg["zone"], cfg["seed"], true)
		if res.is_empty():
			f.store_line("  ❌ Error: generate_house devolvió un diccionario vacío.")
			continue

		var floors: int = res.get("floors", 1)
		f.store_line("  Pisos totales generados: %d" % floors)

		if res.has("stair"):
			var stair: Dictionary = res["stair"]
			var type_str := "Recta (1x3m)" if stair.get("type", 0) == 0 else "En 'U' (2x3m)"
			f.store_line("  ✓ Escalera integrada con éxito!")
			f.store_line("    - Tipo: %s" % type_str)
			f.store_line("    - Ubicación cuadrícula: X=%d, Z=%d (Dimensiones: %dx%d m)" % [
				stair.get("x", 0), stair.get("z", 0),
				stair.get("width", 0), stair.get("length", 0)
			])
		else:
			f.store_line("  (Casa de 1 solo piso o sin necesidad de escalera)")

		# Verificar cuartos de planta alta
		var rooms: Array = res.get("rooms", [])
		var floor2_rooms: Array = []
		for r in rooms:
			if r.get("floor", 1) == 2:
				floor2_rooms.append(r.get("name", "Desconocido"))
		f.store_line("  Cuartos en Planta Alta: %s" % str(floor2_rooms))

	f.store_line("\n✓ TEST FINALIZADO CON ÉXITO.")
	f.close()
	get_tree().quit(0)
