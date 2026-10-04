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
			var beds = furn.get_node_or_null("BedsMultiGroup")
			if beds:
				print("=== BED 43 ===")
				var b43 = beds.get_child(43)
				print("pos=", b43.global_position, " rot=", b43.rotation.y, " state=", b43.bed_state)
				print("\n=== ALL STRIPPED / BARE BEDS ===")
				for i in range(beds.get_child_count()):
					var b = beds.get_child(i)
					if b.bed_state == 2 or b.bed_state == 3: # STRIPPED or BARE
						print("Cama %d: pos=%s rot=%.2f state=%d" % [i, b.global_position, b.rotation.y, b.bed_state])
		quit(0)
	return false
