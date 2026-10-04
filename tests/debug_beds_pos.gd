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
			var beds_group = furn.get_node_or_null("BedsMultiGroup")
			if beds_group:
				print("Total beds in BedsMultiGroup: ", beds_group.get_child_count())
				for i in range(mini(10, beds_group.get_child_count())):
					var b = beds_group.get_child(i)
					print("Bed ", i, ": global_pos=", b.global_position, " visible=", b.visible, " state=", b.bed_state, " children=", b.get_child_count())
					for c in b.get_children():
						var has_mesh = (c as MeshInstance3D).mesh != null if c is MeshInstance3D else false
						print("   child: ", c.name, " class=", c.get_class(), " mesh=", has_mesh, " visible=", c.visible)
			else:
				print("No BedsMultiGroup found!")
		else:
			print("No NeighborhoodFurniture found!")
		quit(0)
	return false
