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
			var p = _node._parcels_config[i]
			var seed = _node._corner_seeds[i % _node._corner_seeds.size()]
			var wall_keys = CityTextureManager.get_all_wall_keys()
			var wall_key: String = wall_keys[int((seed ^ (seed >> 5)) & 0x7FFFFFFF) % wall_keys.size()]
			print("House %d: %s | seed=%d | wall=%s | front_side=%d" % [
				i, p["corner_name"], seed, wall_key, p["front_side"]
			])
		quit(0)
	return false
