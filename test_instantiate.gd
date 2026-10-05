extends SceneTree

func _init() -> void:
	var f := FileAccess.open("res://test_instantiate_log.txt", FileAccess.WRITE)
	f.store_line("STARTING SNAPSHOT TEST")
	var car := Sedan80s.new()
	root.add_child(car)
	f.store_line("Car created successfully! Model: " + str(car.car_model_name))
	f.store_line("Sockets count: " + str(car.sockets.size()))
	for s in car.sockets:
		var p: VehiclePart = car.sockets[s].installed_part
		f.store_line("  Socket: " + str(s) + " -> Part: " + (p.data.display_name if p and p.data else "EMPTY"))
	f.close()
	quit()
