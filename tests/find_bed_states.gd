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
				print("=== LISTA DE CAMAS CON ESTADOS ===")
				for i in range(beds.get_child_count()):
					var b = beds.get_child(i)
					var state_names = ["MADE", "UNMADE", "STRIPPED", "BARE_MATTRESS"]
					print("Cama %d: pos=%s state=%s sheet=%d blanket=%d dirt=%.2f" % [
						i, b.global_position, state_names[b.bed_state], b.sheet_pattern_id, b.blanket_pattern_id, b.dirt_pct
					])
		quit(0)
	return false
