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
			print("Total tables in _tables array: ", furn._tables.size())
			if not furn._tables.is_empty():
				print("Table 0 transform from array: ", furn._tables[0]["transform"])
			print("Total sink units in _sink_units: ", furn._sink_units.size())
			if not furn._sink_units.is_empty():
				print("Sink 0 transform from array: ", furn._sink_units[0]["transform"])
			print("Total wardrobes in _wardrobes: ", furn._wardrobes.size())
			if not furn._wardrobes.is_empty():
				print("Wardrobe 0 transform from array: ", furn._wardrobes[0]["transform"])
		quit(0)
	return false
