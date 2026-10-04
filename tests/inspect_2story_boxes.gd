extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var res = engine.generate_house(7, 15, 1, 8072, true)
	
	var ext_walls: MultiMesh = res.get("ext_walls_multimesh")
	var solid_mm: MultiMesh = res.get("solid_multimesh")
	
	print("=== EXT WALLS AROUND Y = 2.80 ===")
	if ext_walls:
		for i in range(ext_walls.instance_count):
			var tr: Transform3D = ext_walls.get_instance_transform(i)
			var pos = tr.origin
			var scale = tr.basis.get_scale()
			var y_min = pos.y - scale.y * 0.5
			var y_max = pos.y + scale.y * 0.5
			if y_min <= 2.85 and y_max >= 2.75:
				print("ExtWall #%d: pos=%s, size=%s (y: %.3f .. %.3f)" % [i, pos, scale, y_min, y_max])

	print("=== SOLID BOXES AROUND Y = 2.80 ===")
	if solid_mm:
		for i in range(solid_mm.instance_count):
			var tr: Transform3D = solid_mm.get_instance_transform(i)
			var pos = tr.origin
			var scale = tr.basis.get_scale()
			var y_min = pos.y - scale.y * 0.5
			var y_max = pos.y + scale.y * 0.5
			if y_min <= 2.85 and y_max >= 2.75:
				print("SolidBox #%d: pos=%s, size=%s (y: %.3f .. %.3f)" % [i, pos, scale, y_min, y_max])

	quit(0)
