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
				if r.floor == 2 and r.name == "Recámara":
					var plan = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
					for item in plan:
						if item.name == "BedroomBed":
							print("House %d (%s) seed=%d: Bed local=%s, room x=[%d..%d] z=[%d..%d], house w=%d, d=%d" % [
								i, p_cfg["corner_name"], h_seed, item.position, r.x_min, r.x_max, r.z_min, r.z_max, w, d
							])
		quit(0)
	return false
