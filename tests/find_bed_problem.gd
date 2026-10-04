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
		print("=== SEARCHING FOR THE EXACT BED IN THE USER PHOTO ===")
		var furn = _node.get_node_or_null("CornerHouses/NeighborhoodFurniture")
		var beds_grp = furn.get_node_or_null("BedsMultiGroup")
		
		# For each bed, let's find which house it belongs to and its local position in that house
		for i in range(_node._parcels_config.size()):
			var p_cfg = _node._parcels_config[i]
			var rect: Rect2 = p_cfg["rect"]
			var front_side: int = p_cfg["front_side"]
			var h_seed: int = _node._corner_seeds[i % _node._corner_seeds.size()]
			var z_mode = p_cfg["default_zone"]
			
			var w: int = int(rect.size.x)
			var d: int = int(rect.size.y)
			var rot_y: float = 0.0
			match front_side:
				0: rot_y = 0.0
				1: rot_y = -PI * 0.5; w = int(rect.size.y); d = int(rect.size.x)
				2: rot_y = PI
				3: rot_y = PI * 0.5; w = int(rect.size.y); d = int(rect.size.x)
				
			var house_pos = Vector3(rect.position.x + rect.size.x * 0.5, 0.16, rect.position.y + rect.size.y * 0.5)
			var house_basis = Basis(Vector3.UP, rot_y)
			
			var res = _node._engine.generate_house(w, d, z_mode, h_seed, true)
			var rooms = res.get("rooms", [])
			var floor_h: float = 3.40 if z_mode == 2 else 2.80
			
			for r in rooms:
				if r.name == "Recámara":
					var plan = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
					for item in plan:
						if item.name == "BedroomBed":
							var lpos: Vector3 = item.position
							var r_floor = int(r.get("floor", 1))
							lpos.y += 0.0 if r_floor == 1 else floor_h
							var gpos = house_pos + house_basis * lpos
							
							# Let's check collision boxes of the house!
							# Does gpos fall inside a room on that floor?
							var r_rx0 = float(r.x_min) - float(w) * 0.5
							var r_rx1 = float(r.x_max) - float(w) * 0.5
							var r_rz0 = float(r.z_min) - float(d) * 0.5
							var r_rz1 = float(r.z_max) - float(d) * 0.5
							
							print("House %d (%s) Floor %d: Bed local=(%.2f, %.2f, %.2f), room X=[%.1f, %.1f] Z=[%.1f, %.1f]" % [
								i, p_cfg["corner_name"], r_floor, item.position.x, item.position.y, item.position.z,
								r_rx0, r_rx1, r_rz0, r_rz1
							])
		quit(0)
	return false
