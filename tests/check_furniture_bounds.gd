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
		print("=== CHECKING ALL HOUSES FOR FURNITURE OUTSIDE WALLS ===")
		var furn = _node.get_node_or_null("CornerHouses/NeighborhoodFurniture")
		var houses = _node.get_node_or_null("CornerHouses")
		
		# Let's inspect all parcels
		for i in range(_node._parcels_config.size()):
			var p_cfg = _node._parcels_config[i]
			var rect: Rect2 = p_cfg["rect"]
			var front_side: int = p_cfg["front_side"]
			var h_seed: int = _node._corner_seeds[i % _node._corner_seeds.size()]
			var z_mode = p_cfg["default_zone"]
			
			var w = int(rect.size.x) if (front_side == 0 or front_side == 2) else int(rect.size.y)
			var d = int(rect.size.y) if (front_side == 0 or front_side == 2) else int(rect.size.x)
			
			var res = _node._engine.generate_house(w, d, z_mode, h_seed, true)
			var rooms = res.get("rooms", [])
			for r in rooms:
				if r.name == "Recámara":
					var plan = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
					for item in plan:
						if item.name == "BedroomBed":
							var pos: Vector3 = item.position
							# Check if pos is outside room bounds
							var rx0 = float(r.x_min) - float(w) * 0.5
							var rx1 = float(r.x_max) - float(w) * 0.5
							var rz0 = float(r.z_min) - float(d) * 0.5
							var rz1 = float(r.z_max) - float(d) * 0.5
							
							var is_outside = (pos.x < rx0 or pos.x > rx1 or pos.z < rz0 or pos.z > rz1)
							if is_outside:
								print("CRITICAL: House %d (%s) Room %s (floor %d): BED IS OUTSIDE! pos=%s bounds=[%f..%f, %f..%f]" % [
									i, p_cfg["corner_name"], r.name, r.floor, pos, rx0, rx1, rz0, rz1
								])
							else:
								# Also check if bed extent goes outside room bounds
								# Bed size: width 1.05, depth 2.14
								pass
				elif r.name == "Sala":
					var plan = HouseFurniturePlanner.plan_living_room_furniture(res, r, float(w), float(d))
					for item in plan:
						if item.name == "LivingArmchair":
							var pos: Vector3 = item.position
							var rx0 = float(r.x_min) - float(w) * 0.5
							var rx1 = float(r.x_max) - float(w) * 0.5
							var rz0 = float(r.z_min) - float(d) * 0.5
							var rz1 = float(r.z_max) - float(d) * 0.5
							var is_outside = (pos.x < rx0 or pos.x > rx1 or pos.z < rz0 or pos.z > rz1)
							if is_outside:
								print("CRITICAL: House %d (%s) Room %s (floor %d): ARMCHAIR IS OUTSIDE! pos=%s bounds=[%f..%f, %f..%f]" % [
									i, p_cfg["corner_name"], r.name, r.floor, pos, rx0, rx1, rz0, rz1
								])
		quit(0)
	return false
