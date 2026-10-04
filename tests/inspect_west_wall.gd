extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var res = engine.generate_house(9, 16, 0, 2018, true)
	var col_boxes = res.get("collision_boxes", [])
	print("Boxes with x < -4.0 in House 1:")
	for b in col_boxes:
		var p: Vector3 = b.position
		var s: Vector3 = b.size
		if p.x < -4.0:
			print("  Box: pos=%s sz=%s" % [p, s])
	quit(0)
