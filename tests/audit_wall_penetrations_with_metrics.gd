extends SceneTree

const CellWallMetricsScript = preload("res://world/furniture/cell_wall_metrics.gd")

var _frames := 0
var _node = null

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_node = showcase_scn.instantiate()
	_node.is_capture_mode = true
	root.add_child(_node)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		print("=== AUDITORIA COMPLETA DE PENETRACION DE MUROS CON CellWallMetrics ===")
		var total_items := 0
		var penetrations_found := 0
		
		for i in range(_node._parcels_config.size()):
			var p_cfg = _node._parcels_config[i]
			var rect: Rect2 = p_cfg["rect"]
			var front_side: int = p_cfg["front_side"]
			var h_seed: int = _node._corner_seeds[i % _node._corner_seeds.size()]
			var z_mode = p_cfg["default_zone"]
			var w = int(rect.size.x) if (front_side == 0 or front_side == 2) else int(rect.size.y)
			var d = int(rect.size.y) if (front_side == 0 or front_side == 2) else int(rect.size.x)
			
			var res = _node._engine.generate_house(w, d, z_mode, h_seed, true)
			var f1: PackedByteArray = res.get("room_map_floor1", PackedByteArray())
			var f2: PackedByteArray = res.get("room_map_floor2", PackedByteArray())
			var rooms = res.get("rooms", [])
			
			for r in rooms:
				var r_floor: int = int(r.floor)
				var map = f1 if r_floor == 1 else f2
				
				var items: Array[Dictionary] = []
				if r.name == "Recámara":
					items = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Sala":
					items = HouseFurniturePlanner.plan_living_room_furniture(res, r, float(w), float(d))
				elif r.name == "Comedor":
					var plan = HouseFurniturePlanner.plan_dining_set(res, r, float(w), float(d))
					items = [plan]
				elif r.name == "Cocina":
					items = HouseFurniturePlanner.plan_kitchen_furniture(res, r, float(w), float(d))
				elif r.name == "Baño":
					items = HouseFurniturePlanner.plan_bathroom_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Estudio/Biblioteca":
					items = HouseFurniturePlanner.plan_studio_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Lavandería":
					items = HouseFurniturePlanner.plan_laundry_furniture(res, r, float(w), float(d))
					
				for item in items:
					if not item.has("position"): continue
					var lpos: Vector3 = item.position
					var rot_y: float = item.get("rotation_y", 0.0)
					var iname: String = item.get("name", "Item")
					total_items += 1
					
					var hx := 0.25
					var hz := 0.25
					var is_z_aligned := absf(cos(rot_y)) > 0.7
					if iname == "BedroomBed":
						hx = (1.05 if is_z_aligned else 2.14) * 0.5
						hz = (2.14 if is_z_aligned else 1.05) * 0.5
					elif iname == "BedroomNightstand":
						hx = (0.48 if is_z_aligned else 0.43) * 0.5
						hz = (0.43 if is_z_aligned else 0.48) * 0.5
					elif iname == "BedroomWardrobe":
						hx = (1.06 if is_z_aligned else 0.62) * 0.5
						hz = (0.62 if is_z_aligned else 1.06) * 0.5
					elif iname == "BathroomSinkUnit":
						hx = (1.01 if is_z_aligned else 0.62) * 0.5
						hz = (0.62 if is_z_aligned else 1.01) * 0.5
					elif iname == "KitchenBaseCabinet":
						hx = (0.85 if is_z_aligned else 0.60) * 0.5
						hz = (0.60 if is_z_aligned else 0.85) * 0.5
					elif iname == "KitchenWallCabinet":
						hx = (0.85 if is_z_aligned else 0.38) * 0.5
						hz = (0.38 if is_z_aligned else 0.85) * 0.5
					elif iname == "KitchenStove":
						hx = (0.76 if is_z_aligned else 0.68) * 0.5
						hz = (0.68 if is_z_aligned else 0.76) * 0.5
					elif iname == "KitchenRefrigerator":
						hx = (0.80 if is_z_aligned else 0.78) * 0.5
						hz = (0.78 if is_z_aligned else 0.80) * 0.5
					elif iname == "StudioBookcase1" or iname == "StudioBookcase2":
						hx = (0.84 if is_z_aligned else 0.30) * 0.5
						hz = (0.30 if is_z_aligned else 0.84) * 0.5
					elif iname == "LaundryWasher" or iname == "LaundryDryer":
						hx = 0.37; hz = 0.34
					else:
						continue # Props pequeños sobre mesas no tocan paredes
						
					var gx = int(floor(lpos.x + float(w) * 0.5))
					var gz = int(floor(lpos.z + float(d) * 0.5))
					if gx < 0 or gx >= w or gz < 0 or gz >= d:
						continue
						
					var m = CellWallMetricsScript.measure_cell(map, w, d, gx, gz, r.id)
					
					var item_min_x = lpos.x - hx
					var item_max_x = lpos.x + hx
					var item_min_z = lpos.z - hz
					var item_max_z = lpos.z + hz
					
					# Verificar contra paramento interior del muro
					if m.wall_west > 0.0:
						var wall_face_w = m.cell_min_x + m.wall_west
						if item_min_x < wall_face_w - 0.005:
							penetrations_found += 1
							print("  PENETRATION WEST: Casa %d (%s) %s %s: min_x=%.3f < wall_face=%.3f (pen=%.1fcm)" % [
								i, p_cfg["corner_name"], r.name, iname, item_min_x, wall_face_w, (wall_face_w - item_min_x) * 100.0
							])
					if m.wall_east > 0.0:
						var wall_face_e = m.cell_max_x - m.wall_east
						if item_max_x > wall_face_e + 0.005:
							penetrations_found += 1
							print("  PENETRATION EAST: Casa %d (%s) %s %s: max_x=%.3f > wall_face=%.3f (pen=%.1fcm)" % [
								i, p_cfg["corner_name"], r.name, iname, item_max_x, wall_face_e, (item_max_x - wall_face_e) * 100.0
							])
					if m.wall_north > 0.0:
						var wall_face_n = m.cell_min_z + m.wall_north
						if item_min_z < wall_face_n - 0.005:
							penetrations_found += 1
							print("  PENETRATION NORTH: Casa %d (%s) %s %s: min_z=%.3f < wall_face=%.3f (pen=%.1fcm)" % [
								i, p_cfg["corner_name"], r.name, iname, item_min_z, wall_face_n, (wall_face_n - item_min_z) * 100.0
							])
					if m.wall_south > 0.0:
						var wall_face_s = m.cell_max_z - m.wall_south
						if item_max_z > wall_face_s + 0.005:
							penetrations_found += 1
							print("  PENETRATION SOUTH: Casa %d (%s) %s %s: max_z=%.3f > wall_face=%.3f (pen=%.1fcm)" % [
								i, p_cfg["corner_name"], r.name, iname, item_max_z, wall_face_s, (item_max_z - wall_face_s) * 100.0
							])
		print("=====================================================================")
		print("AUDITORIA FINALIZADA: Total muebles auditados: %d | Penetraciones: %d" % [total_items, penetrations_found])
		print("=====================================================================")
		quit(0 if penetrations_found == 0 else 1)
	return false
