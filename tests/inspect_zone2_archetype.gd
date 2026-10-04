extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	
	for s in [1009, 2018, 3027, 4036]:
		print("\n--- SEED %d (Zone 2, 18x20) ---" % s)
		var res: Dictionary = engine.generate_house(18, 20, 2, s, false)
		var rooms: Array = res.get("rooms", [])
		for r in rooms:
			var rd: Dictionary = r
			print(" Room %d: %s | Floor: %d | Bounds: [%.0f..%.0f, %.0f..%.0f] | Area: %.1f m²" % [
				rd.get("id", 0),
				rd.get("name", ""),
				rd.get("floor", 1),
				rd.get("x_min", 0), rd.get("x_max", 0),
				rd.get("z_min", 0), rd.get("z_max", 0),
				(float(rd.get("x_max", 0)) - float(rd.get("x_min", 0))) * (float(rd.get("z_max", 0)) - float(rd.get("z_min", 0)))
			])
		print(" Doors: %d" % res.get("doors", []).size())
		for d in res.get("doors", []):
			var dd: Dictionary = d
			print("   Door at %s (style %d, is_main: %s)" % [dd.get("position"), dd.get("style", 0), dd.get("is_main", false)])
	
	quit(0)
