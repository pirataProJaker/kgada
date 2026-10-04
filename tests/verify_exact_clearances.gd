extends SceneTree

var _frames := 0
var _node = null

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_node = showcase_scn.instantiate()
	_node.is_capture_mode = true
	root.add_child(_node)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var node = _node
		print("=== AUDITORIA 3D GLOBAL DE COLISION DE MUEBLES VS CAJAS DE MUROS ===")
		var total_items := 0
		var total_collisions := 0
		
		for i in range(node._parcels_config.size()):
			var p_cfg = node._parcels_config[i]
			var rect: Rect2 = p_cfg["rect"]
			var front_side: int = p_cfg["front_side"]
			var h_seed: int = node._corner_seeds[i % node._corner_seeds.size()]
			var z_mode = p_cfg["default_zone"]
			var w = int(rect.size.x) if (front_side == 0 or front_side == 2) else int(rect.size.y)
			var d = int(rect.size.y) if (front_side == 0 or front_side == 2) else int(rect.size.x)
			
			var res = node._engine.generate_house(w, d, z_mode, h_seed, true)
			var col_boxes: Array = res.get("collision_boxes", [])
			var rooms: Array = res.get("rooms", [])
			
			# Filtrar solo cajas que son muros (altura >= 1.0 y grosor <= 0.25)
			var wall_boxes: Array = []
			for b in col_boxes:
				var s: Vector3 = b.size
				if s.y >= 1.0 and (s.x <= 0.25 or s.z <= 0.25):
					wall_boxes.append(b)
					
			for r in rooms:
				var r_floor: int = int(r.floor)
				var floor_h: float = 3.40 if z_mode == 2 else 2.80
				var floor_y_offset: float = 0.0 if r_floor == 1 else floor_h

				var items: Array[Dictionary] = []
				if r.name == "Recámara":
					items = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Cocina":
					items = HouseFurniturePlanner.plan_kitchen_furniture(res, r, float(w), float(d))
				elif r.name == "Baño":
					items = HouseFurniturePlanner.plan_bathroom_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Estudio/Biblioteca":
					items = HouseFurniturePlanner.plan_studio_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Lavandería":
					items = HouseFurniturePlanner.plan_laundry_furniture(res, r, float(w), float(d))
				elif r.name == "Sala":
					items = HouseFurniturePlanner.plan_living_room_furniture(res, r, float(w), float(d))
					
				for item in items:
					if not item.has("position"): continue
					var lpos: Vector3 = item.position
					lpos.y += floor_y_offset
					var rot_y: float = item.get("rotation_y", 0.0)
					var iname: String = item.get("name", "Item")
					
					var hx := 0.25; var hz := 0.25; var hy := 0.5
					var is_z := absf(cos(rot_y)) > 0.7
					if iname == "BedroomBed":
						hx = (1.05 if is_z else 2.14) * 0.5
						hz = (2.14 if is_z else 1.05) * 0.5
						hy = 0.5
					elif iname == "BedroomNightstand":
						hx = (0.48 if is_z else 0.43) * 0.5
						hz = (0.43 if is_z else 0.48) * 0.5
						hy = 0.3
					elif iname == "BedroomWardrobe":
						hx = (1.06 if is_z else 0.62) * 0.5
						hz = (0.62 if is_z else 1.06) * 0.5
						hy = 1.0
					elif iname == "BathroomSinkUnit":
						hx = (1.01 if is_z else 0.62) * 0.5
						hz = (0.62 if is_z else 1.01) * 0.5
						hy = 0.45
					elif iname == "KitchenBaseCabinet":
						hx = (0.85 if is_z else 0.60) * 0.5
						hz = (0.60 if is_z else 0.85) * 0.5
						hy = 0.45
					elif iname == "KitchenWallCabinet":
						hx = (0.85 if is_z else 0.38) * 0.5
						hz = (0.38 if is_z else 0.85) * 0.5
						hy = 0.35
					elif iname == "KitchenStove":
						hx = (0.76 if is_z else 0.68) * 0.5
						hz = (0.68 if is_z else 0.76) * 0.5
						hy = 0.45
					elif iname == "KitchenRefrigerator":
						hx = (0.80 if is_z else 0.78) * 0.5
						hz = (0.78 if is_z else 0.80) * 0.5
						hy = 0.85
					elif iname == "StudioBookcase1" or iname == "StudioBookcase2":
						hx = (0.84 if is_z else 0.30) * 0.5
						hz = (0.30 if is_z else 0.84) * 0.5
						hy = 0.95
					elif iname == "LaundryWasher" or iname == "LaundryDryer":
						hx = 0.37; hz = 0.34; hy = 0.45
					else:
						continue
						
					total_items += 1
					var b_min = Vector3(lpos.x - hx, lpos.y, lpos.z - hz)
					var b_max = Vector3(lpos.x + hx, lpos.y + hy * 2.0, lpos.z + hz)
					
					for wb in wall_boxes:
						var wp: Vector3 = wb.position
						var ws: Vector3 = wb.size
						var w_min = wp - ws * 0.5
						var w_max = wp + ws * 0.5
						
						var ox = maxf(0.0, minf(b_max.x, w_max.x) - maxf(b_min.x, w_min.x))
						var oy = maxf(0.0, minf(b_max.y, w_max.y) - maxf(b_min.y, w_min.y))
						var oz = maxf(0.0, minf(b_max.z, w_max.z) - maxf(b_min.z, w_min.z))
						
						if ox > 0.005 and oy > 0.005 and oz > 0.005:
							total_collisions += 1
							print("COLISION: Casa %d (%s) Mueble %s en %s (rot=%.2f, hx=%.2f, hz=%.2f) con Muro en %s sz=%s (overlap: %.1fcm, %.1fcm, %.1fcm)" % [
								i, p_cfg["corner_name"], iname, lpos, rot_y, hx, hz, wp, ws, ox * 100.0, oy * 100.0, oz * 100.0
							])
							
		print("=====================================================================")
		print("AUDITORIA 3D FINALIZADA: Total muebles: %d | Colisiones con muros: %d" % [total_items, total_collisions])
		print("=====================================================================")
		quit(0 if total_collisions == 0 else 1)
	return false
