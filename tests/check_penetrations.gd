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
	if _frames == 5:
		print("=== CHECKING ALL FURNITURE EXTENTS AGAINST ROOM FOOTPRINTS ===")
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
				var rx0 = float(r.x_min) - float(w) * 0.5
				var rx1 = float(r.x_max) - float(w) * 0.5
				var rz0 = float(r.z_min) - float(d) * 0.5
				var rz1 = float(r.z_max) - float(d) * 0.5
				
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
					
					# Exact half extents based on object type and orientation
					var hx := 0.25
					var hz := 0.25
					var is_z_aligned := absf(cos(rot_y)) > 0.7
					if iname == "BedroomBed":
						hx = (1.05 if is_z_aligned else 2.14) * 0.5
						hz = (2.14 if is_z_aligned else 1.05) * 0.5
					elif iname == "BedroomNightstand":
						hx = (0.48 if is_z_aligned else 0.43) * 0.5
						hz = (0.43 if is_z_aligned else 0.48) * 0.5
					elif iname == "NightstandMug" or iname == "StudioMug":
						hx = 0.08; hz = 0.08
					elif iname == "NightstandBook":
						hx = 0.12; hz = 0.12
					elif iname == "BedroomRug":
						hx = 0.80; hz = 0.55
					elif iname == "BedroomWardrobe":
						hx = (1.06 if is_z_aligned else 0.62) * 0.5
						hz = (0.62 if is_z_aligned else 1.06) * 0.5
					elif iname == "BathroomSinkUnit":
						hx = (1.01 if is_z_aligned else 0.62) * 0.5
						hz = (0.62 if is_z_aligned else 1.01) * 0.5
					elif iname == "LivingCoffeeTable":
						hx = (0.90 if is_z_aligned else 0.55) * 0.5
						hz = (0.55 if is_z_aligned else 0.90) * 0.5
					elif iname == "LivingArmchair" or iname == "StudioReadingArmchair":
						hx = 0.42; hz = 0.42
					elif iname == "KitchenBaseCabinet" or iname == "KitchenWallCabinet":
						hx = (0.85 if is_z_aligned else 0.60) * 0.5
						hz = (0.60 if is_z_aligned else 0.85) * 0.5
					elif iname == "KitchenStove":
						hx = (0.76 if is_z_aligned else 0.68) * 0.5
						hz = (0.68 if is_z_aligned else 0.76) * 0.5
					elif iname == "KitchenRefrigerator":
						hx = (0.80 if is_z_aligned else 0.78) * 0.5
						hz = (0.78 if is_z_aligned else 0.80) * 0.5
					elif iname == "KitchenMicrowave":
						hx = 0.25; hz = 0.18
					elif iname == "KitchenToaster":
						hx = 0.14; hz = 0.10
					elif iname == "StudioBookcase1" or iname == "StudioBookcase2":
						hx = (0.80 if is_z_aligned else 0.30) * 0.5
						hz = (0.30 if is_z_aligned else 0.80) * 0.5
					elif iname == "StudioCoffeeTable":
						hx = 0.25; hz = 0.25
					elif iname == "LaundryWasher" or iname == "LaundryDryer":
						hx = 0.34; hz = 0.34
						
					var item_min_x = lpos.x - hx
					var item_max_x = lpos.x + hx
					var item_min_z = lpos.z - hz
					var item_max_z = lpos.z + hz
					
					var margin = 0.05
					var p_name = p_cfg["corner_name"]
					if item_min_x < rx0 - margin:
						print("PENETRATION WEST: House %d (%s) Room %s (F%d) Item %s: min_x=%.3f < rx0=%.3f (diff=%.3f)" % [
							i, p_name, r.name, r_floor, iname, item_min_x, rx0, rx0 - item_min_x
						])
					if item_max_x > rx1 + margin:
						print("PENETRATION EAST: House %d (%s) Room %s (F%d) Item %s: max_x=%.3f > rx1=%.3f (diff=%.3f)" % [
							i, p_name, r.name, r_floor, iname, item_max_x, rx1, item_max_x - rx1
						])
					if item_min_z < rz0 - margin:
						print("PENETRATION NORTH: House %d (%s) Room %s (F%d) Item %s: min_z=%.3f < rz0=%.3f (diff=%.3f)" % [
							i, p_name, r.name, r_floor, iname, item_min_z, rz0, rz0 - item_min_z
						])
					if item_max_z > rz1 + margin:
						print("PENETRATION SOUTH: House %d (%s) Room %s (F%d) Item %s: max_z=%.3f > rz1=%.3f (diff=%.3f)" % [
							i, p_name, r.name, r_floor, iname, item_max_z, rz1, item_max_z - rz1
						])
		quit(0)
	return false
