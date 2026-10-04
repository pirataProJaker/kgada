extends SceneTree

func _init() -> void:
	var engine = ClassDB.instantiate("ProceduralHouseEngine")
	var w := 10
	var d := 16
	var h_seed := 1009
	var res = engine.generate_house(w, d, 0, h_seed, false)
	var rooms: Array = res.get("rooms", [])
	for r in rooms:
		if r.id == 5:
			print("\nRecámara ID=%d Piso=%d:" % [r.id, r.floor])
			var map = res.get("room_map_floor1", PackedByteArray())
			print("Room rect: X=[%d, %d], Z=[%d, %d]" % [r.x_min, r.x_max, r.z_min, r.z_max])
			for z in range(r.z_min, r.z_max):
				var s := "  Z=%2d: " % z
				for x in range(r.x_min, r.x_max):
					s += "%d " % map[z * w + x]
				print(s)
			print("Neighbor (6, 8): ", map[8 * w + 6])
			print("Neighbor (5, 7): ", map[7 * w + 5])
			print("Neighbor (5, 9): ", map[9 * w + 5])
			var items = HouseFurniturePlanner.plan_bedroom_furniture(res, r, float(w), float(d), h_seed)
			for item in items:
				if item.name == "BedroomBed":
					print("  Bed pos: %s rot: %.2f" % [item.position, item.rotation_y])
	quit(0)
