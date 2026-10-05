extends Node

func _ready() -> void:
	var car := Sedan80s.new()
	add_child(car)

	var f := FileAccess.open("res://inspect_out.txt", FileAccess.WRITE)
	f.store_line("=== CAR INSPECTION IN GODOT ===")
	f.store_line("Sockets count: " + str(car.sockets.size()))
	for slot in car.sockets:
		var s: PartSocket = car.sockets[slot]
		var part = s.installed_part
		var part_name = part.name if part else "EMPTY"
		f.store_line("  Socket: " + str(s.name) + " @ pos=" + str(s.position) + " | Installed: " + part_name)
	var eng := car.get_installed_engine()
	if eng:
		f.store_line("Installed engine: " + str(eng.data.display_name))
		f.store_line("  Engine pos: " + str(eng.position) + " global_pos: " + str(eng.global_position))
		if eng.battery_socket and eng.battery_socket.installed_part:
			f.store_line("  Battery installed: " + str(eng.battery_socket.installed_part.name) + " @ pos=" + str(eng.battery_socket.position))
		if eng.radiator_socket and eng.radiator_socket.installed_part:
			f.store_line("  Radiator installed: " + str(eng.radiator_socket.installed_part.name) + " @ pos=" + str(eng.radiator_socket.position))
	f.close()
	get_tree().quit()
