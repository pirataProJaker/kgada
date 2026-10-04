extends SceneTree

func _init() -> void:
	var scn = load("res://scenes/cross_street_houses_showcase.tscn")
	var node = scn.instantiate()
	node.is_capture_mode = true
	root.add_child(node)

	var furn_sys = node.get_node("CornerHouses/NeighborhoodFurniture")
	print("\n=== RECUENTO DE MOBILIARIO EN EL SHOWCASE DE LA CIUDAD ===")
	print("Total muebles y props: ", furn_sys.get_total_furniture_count())
	print("Total wardrobes en _wardrobes: ", furn_sys._wardrobes.size())
	for i in range(min(5, furn_sys._wardrobes.size())):
		print("  Wardrobe %d: transform=%s" % [i, furn_sys._wardrobes[i]["transform"]])
	quit(0)
