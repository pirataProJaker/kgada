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
		print("=== CHECKING ALL HOUSES: IS ANY FURNITURE OUTSIDE THE HOUSE CELLS? ===")
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
				
				# Plan furniture for this room
				var items: Array[Dictionary] = []
				if r.name == "Recámara":
					items = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Sala":
					items = HouseFurniturePlanner.plan_living_room_furniture(res, r, float(w), float(d))
				elif r.name == "Baño":
					items = HouseFurniturePlanner.plan_bathroom_furniture(res, r, float(w), float(d), h_seed)
				elif r.name == "Cocina":
					items = HouseFurniturePlanner.plan_kitchen_furniture(res, r, float(w), float(d))
				elif r.name == "Comedor":
					var dplan = HouseFurniturePlanner.plan_dining_set(res, r, float(w), float(d))
					items = [dplan]
				elif r.name == "Lavandería":
					items = HouseFurniturePlanner.plan_laundry_furniture(res, r, float(w), float(d))
				elif r.name == "Estudio/Biblioteca":
					items = HouseFurniturePlanner.plan_studio_furniture(res, r, float(w), float(d), h_seed)
					
				for item in items:
					var lpos: Vector3 = item.position
					# Convert lpos to grid coordinates (0..w, 0..d)
					var gx = lpos.x + float(w) * 0.5
					var gz = lpos.z + float(d) * 0.5
					
					var cell_x = int(floor(gx))
					var cell_z = int(floor(gz))
					
					var cell_val = 0
					if cell_x >= 0 and cell_x < w and cell_z >= 0 and cell_z < d:
						cell_val = map[cell_z * w + cell_x]
						
					if cell_val == 0:
						print("FOUND OUTSIDE ITEM! House %d (%s) Room %s (floor %d): %s at local=%s (grid cell %d, %d has val=0!)" % [
							i, p_cfg["corner_name"], r.name, r_floor, item.name, lpos, cell_x, cell_z
						])
		quit(0)
	return false
