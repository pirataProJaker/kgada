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
		var p_cfg = node._parcels_config[7]
		var rect: Rect2 = p_cfg["rect"]
		var front_side: int = p_cfg["front_side"]
		var h_seed: int = node._corner_seeds[7 % node._corner_seeds.size()]
		var z_mode = p_cfg["default_zone"]
		var w = int(rect.size.x) if (front_side == 0 or front_side == 2) else int(rect.size.y)
		var d = int(rect.size.y) if (front_side == 0 or front_side == 2) else int(rect.size.x)
		
		var res = node._engine.generate_house(w, d, z_mode, h_seed, true)
		var map_f1 = res.get("room_map_floor1", PackedByteArray())
		var map_f2 = res.get("room_map_floor2", PackedByteArray())
		var rooms = res.get("rooms", [])
		
		print("Casa 7: w=%d, d=%d" % [w, d])
		for r in rooms:
			if r.name == "Recámara":
				print("Recámara ID=%d, floor=%d, rect=[%d, %d]x[%d, %d]" % [r.id, r.floor, r.x_min, r.x_max, r.z_min, r.z_max])
				var items = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
				for it in items:
					if it.name == "BedroomBed":
						print("  Bed item: ", it.position, " rot: ", it.rotation_y)
						var map = map_f1 if r.floor == 1 else map_f2
						for z in range(r.z_min - 1, r.z_max + 1):
							var s := "  Z=%2d: " % z
							for x in range(r.x_min - 1, r.x_max + 1):
								if x >= 0 and x < w and z >= 0 and z < d:
									s += "%2d " % map[z * w + x]
								else:
									s += " X "
							print(s)
		quit(0)
	return false
