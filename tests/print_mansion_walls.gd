extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var res = engine.generate_house(18, 20, 2, 2018, true)
	
	var ext_walls: MultiMesh = res.get("ext_walls_multimesh")
	print("=== ALL EXT WALLS FOR ZONA X MANSION ===")
	if ext_walls:
		for i in range(ext_walls.instance_count):
			var tr: Transform3D = ext_walls.get_instance_transform(i)
			var pos = tr.origin
			var scale = tr.basis.get_scale()
			var y_min = pos.y - scale.y * 0.5
			var y_max = pos.y + scale.y * 0.5
			# Filtramos las que están en el nivel de pretil (y_max > 3.0)
			if y_max >= 3.0:
				print("Wall #%d: pos=%s, size=%s (X: %.2f..%.2f, Z: %.2f..%.2f, Y: %.2f..%.2f)" % [
					i, pos, scale,
					pos.x - scale.x * 0.5, pos.x + scale.x * 0.5,
					pos.z - scale.z * 0.5, pos.z + scale.z * 0.5,
					y_min, y_max
				])

	quit(0)
