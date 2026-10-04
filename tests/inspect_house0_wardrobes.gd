extends SceneTree

const CellWallMetricsScript = preload("res://world/furniture/cell_wall_metrics.gd")

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var w := 10
	var d := 16
	var h_seed := 1009
	var res = engine.generate_house(w, d, 0, h_seed, false)
	var rooms = res.get("rooms", [])
	var map_f1 = res.get("room_map_floor1", PackedByteArray())
	var map_f2 = res.get("room_map_floor2", PackedByteArray())

	print("--- VERIFICACION FINAL DE HouseFurniturePlanner EN HOUSE 0 ---")
	for r in rooms:
		if r.name == "Recámara":
			var map = map_f1 if r.floor == 1 else map_f2
			var items = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
			for it in items:
				if it.name == "BedroomWardrobe":
					var pos: Vector3 = it.position
					var gx = int(floor(pos.x + float(w) * 0.5))
					var gz = int(floor(pos.z + float(d) * 0.5))
					var rot = it.rotation_y
					var dir = Vector2i(0, 1)
					if absf(rot - PI) < 0.1 or absf(rot + PI) < 0.1:
						dir = Vector2i(0, -1)
					elif absf(rot - PI * 0.5) < 0.1:
						dir = Vector2i(1, 0)
					elif absf(rot + PI * 0.5) < 0.1:
						dir = Vector2i(-1, 0)

					var m = CellWallMetricsScript.measure_cell(map, w, d, gx, gz, r.id)
					print("Recámara ID=%d Piso=%d:" % [r.id, r.floor])
					print("  Wardrobe Pos: %s Rot: %.2f Cell=(%d, %d)" % [pos, rot, gx, gz])
					print("  Muros celda: W=%.2f E=%.2f N=%.2f S=%.2f" % [m.wall_west, m.wall_east, m.wall_north, m.wall_south])
					
					var hx = 1.06 * 0.5 if (dir.y != 0) else 0.62 * 0.5
					var hz = 0.62 * 0.5 if (dir.y != 0) else 1.06 * 0.5
					
					if m.wall_west > 0.0:
						var dist_to_w = (pos.x - hx) - (m.cell_min_x + m.wall_west)
						print("  Clearance a muro Oeste: %.3fm (debe ser >= 0.02)" % dist_to_w)
					if m.wall_east > 0.0:
						var dist_to_e = (m.cell_max_x - m.wall_east) - (pos.x + hx)
						print("  Clearance a muro Este: %.3fm (debe ser >= 0.02)" % dist_to_e)
					if m.wall_north > 0.0:
						var dist_to_n = (pos.z - hz) - (m.cell_min_z + m.wall_north)
						print("  Clearance a muro Norte: %.3fm (debe ser >= 0.02)" % dist_to_n)
					if m.wall_south > 0.0:
						var dist_to_s = (m.cell_max_z - m.wall_south) - (pos.z + hz)
						print("  Clearance a muro Sur: %.3fm (debe ser >= 0.02)" % dist_to_s)
	quit(0)
