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
		if _node._nw_house_data.has("res"):
			var res = _node._nw_house_data["res"]
			var rooms = res.get("rooms", [])
			print("House 0 total rooms: ", rooms.size())
			for r in rooms:
				print("Room: ", r)
		quit(0)
	return false
