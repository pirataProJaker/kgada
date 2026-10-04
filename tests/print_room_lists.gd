extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("ProceduralHouseEngine"):
		print("ERROR: ProceduralHouseEngine no existe.")
		quit(1)
		return

	var eng = ClassDB.instantiate("ProceduralHouseEngine")
	for s in [1009, 2018, 3027, 4036]:
		for z in [0, 1, 2]:
			var res: Dictionary = eng.generate_house(14, 18, z, s, false)
			var rooms: Array = res.get("rooms", [])
			var has_comedor := false
			var names: Array = []
			for r in rooms:
				var n: String = r.get("name")
				names.append(n)
				if n == "Comedor":
					has_comedor = true
			if has_comedor or z == 2:
				print("Seed %d | Zona %d -> Comedor: %s | Cuartos: %s" % [s, z, has_comedor, str(names)])

	quit(0)
