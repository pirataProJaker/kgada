extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var res = engine.generate_house(10, 16, 0, 1009, true)
	
	print("=== HOUSE 0 COLLISION BOXES (WALLS) ===")
	var col_boxes = res.get("collision_boxes", [])
	print("Total collision boxes: ", col_boxes.size())
	
	for b in col_boxes:
		var p: Vector3 = b.position
		var s: Vector3 = b.size
		# Wall boxes typically have height ~2.8m and one thin dimension (<= 0.25)
		if (absf(s.x - 0.20) < 0.05 or absf(s.z - 0.20) < 0.05 or absf(s.x - 0.12) < 0.05 or absf(s.z - 0.12) < 0.05):
			print("  Wall: pos=%s sz=%s -> min=(%.2f, %.2f) max=(%.2f, %.2f)" % [
				p, s, p.x - s.x * 0.5, p.z - s.z * 0.5, p.x + s.x * 0.5, p.z + s.z * 0.5
			])
	quit(0)
