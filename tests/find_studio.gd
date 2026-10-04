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
		var furn = _node.get_node_or_null("CornerHouses/NeighborhoodFurniture")
		if furn:
			print("Bookcases count: ", furn._bookcases.size())
			for i in range(mini(5, furn._bookcases.size())):
				print("Bookcase ", i, ": ", furn._bookcases[i]["transform"])
			print("Armchairs count: ", furn._armchairs.size())
			for i in range(mini(5, furn._armchairs.size())):
				print("Armchair ", i, ": ", furn._armchairs[i]["transform"])
		quit(0)
	return false
