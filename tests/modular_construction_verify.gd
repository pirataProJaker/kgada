extends SceneTree

const MAP_DOCUMENT_SCRIPT := preload("res://map_editor/map_document.gd")
const CONSTRUCTION_MANAGER_SCRIPT := preload("res://map_editor/modular_construction_manager.gd")
const FENCE_TYPE_ID := "smart_fence"
const CARDINAL_OFFSETS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var manager = CONSTRUCTION_MANAGER_SCRIPT.new()
	holder.add_child(manager)
	await process_frame

	var document = MAP_DOCUMENT_SCRIPT.new(Vector2i(17, 17))
	var center := Vector2i(8, 8)
	for mask in 16:
		document.objects.clear()
		document.objects.append(_make_object(1, center))
		var next_id := 2
		for direction_index in 4:
			if mask & (1 << direction_index):
				document.objects.append(_make_object(next_id, center + CARDINAL_OFFSETS[direction_index]))
				next_id += 1
		manager.configure_document(document)
		_check(
			int(manager.get_connectivity_mask(center)) == mask,
			"mask %d se calculo como %d" % [mask, int(manager.get_connectivity_mask(center))],
		)

	document.objects.clear()
	manager.configure_document(document)
	_check(manager.place_object(center, FENCE_TYPE_ID), "colocacion inicial")
	_check(manager.get_batch_count() == 1, "un solo batch para una valla")
	_check(manager.get_child_count() == 1, "un nodo visual para el batch")
	_check(manager.get_last_refresh_count() == 1, "una celda refrescada al colocar")
	var serialized_object: Dictionary = document.to_dictionary()["objects"][0]
	_check(serialized_object.get("category", "") == "fences", "categoria persistida")
	_check(serialized_object.get("connection_key", "") == "fence/smart", "connection_key persistido")
	_check(not serialized_object.has("visual_slot"), "el slot no se persiste")
	_check(not serialized_object.has("batch_key"), "el batch no se persiste")
	_check(not serialized_object.has("connectivity_mask"), "la mascara derivada no se persiste")

	var east := center + Vector2i(1, 0)
	_check(manager.place_object(east, FENCE_TYPE_ID), "colocacion vecina")
	_check(manager.get_connectivity_mask(center) == 2, "el centro conecta al Este")
	_check(manager.get_connectivity_mask(east) == 8, "la vecina conecta al Oeste")
	_check(manager.get_last_refresh_count() == 2, "solo centro y vecina se refrescan")
	_check(manager.remove_object_at_cell(east), "eliminacion vecina")
	_check(manager.get_connectivity_mask(center) == 0, "el centro vuelve a aislado")
	_check(manager.get_last_refresh_count() == 1, "solo el centro se refresca al eliminar")
	_check(manager.move_object(1, Vector2i(10, 8)), "movimiento dentro del chunk")
	_check(manager.get_object_at_cell(center) == null, "la celda anterior queda vacia")
	_check(manager.get_object_at_cell(Vector2i(10, 8)) != null, "la celda nueva contiene el objeto")
	_check(manager.get_batch_count() == 1 and manager.get_child_count() == 1, "el movimiento conserva un batch")
	_check(manager.move_object(1, Vector2i(16, 8)), "movimiento entre chunks")
	_check(manager.get_batch_count() == 1 and manager.get_child_count() == 1, "el batch vacio se libera")

	if _failures == 0:
		print("[modular_construction_verify] OK")
	else:
		print("[modular_construction_verify] FAILURES: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _make_object(object_id: int, cell: Vector2i) -> Dictionary:
	return {
		"object_id": object_id,
		"category": "fences",
		"type_id": FENCE_TYPE_ID,
		"connection_key": "fence/smart",
		"cell": [cell.x, cell.y],
		"rotation_step": 0,
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	print("[modular_construction_verify] ERROR: %s" % message)
