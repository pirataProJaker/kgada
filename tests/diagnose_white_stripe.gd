extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	# Probar con w=7, d=15, zone=1, seeds 1009, 2018, 3027, etc.
	for s in [1009, 2018, 5045, 6054]:
		var res = engine.generate_house(7, 15, 1, s, true)
		var solid_mm: MultiMesh = res.get("solid_multimesh")
		var ext_mm: MultiMesh = res.get("ext_walls_multimesh")
		
		# Buscar si hay alguna caja en solid_mm que esté cerca de la fachada exterior y a y = 2.80
		print("=== SEED %d ===" % s)
		if solid_mm:
			for i in range(solid_mm.instance_count):
				var tr: Transform3D = solid_mm.get_instance_transform(i)
				var pos = tr.origin
				var scale = tr.basis.get_scale()
				var col = solid_mm.get_instance_color(i)
				# Checar si la caja está en entrepiso (y ~ 2.80)
				if abs(pos.y - 2.72) < 0.1 or abs(pos.y - 2.80) < 0.1:
					print("Solid[%d] col=%s pos=%s scale=%s" % [i, col, pos, scale])
		if ext_mm:
			for i in range(ext_mm.instance_count):
				var tr: Transform3D = ext_mm.get_instance_transform(i)
				var pos = tr.origin
				var scale = tr.basis.get_scale()
				if abs(pos.y - 2.80) < 0.1:
					print("Ext[%d] pos=%s scale=%s" % [i, pos, scale])

	quit(0)
