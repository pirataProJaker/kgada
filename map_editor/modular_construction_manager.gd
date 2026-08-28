extends Node3D
class_name ModularConstructionManager

const CONSTRUCTION_CATALOG_SCRIPT := preload("res://map_editor/construction_catalog.gd")
const CHUNK_SAMPLE_STRIDE := 16
const KEY_STRIDE := 1000000
const INITIAL_BATCH_CAPACITY := 32
const DEFAULT_CUBE_COLOR := Color(0.36, 0.22, 0.10, 1.0)
const HIDDEN_TRANSFORM := Transform3D(Basis(), Vector3(0.0, -100000.0, 0.0))
const CARDINAL_OFFSETS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var _document = null
var _grid_size := Vector2i.ZERO
var _cell_size := 1.0
var _objects_by_cell: Dictionary = {}
var _objects_by_id: Dictionary = {}
var _objects_by_chunk: Dictionary = {}
var _runtime_slots: Dictionary = {}
var _runtime_masks: Dictionary = {}
var _next_object_id := 1
var _batches: Dictionary = {}
var _collision_bodies: Dictionary = {}
var _collision_shapes: Dictionary = {}
var _shared_cube_mesh: BoxMesh
var _shared_material: StandardMaterial3D
var _last_refresh_count := 0


func _ready() -> void:
	_build_shared_resources()


func _exit_tree() -> void:
	_clear_collision_runtime()


func configure_document(next_document) -> void:
	_document = next_document
	_clear_visual_runtime()
	_clear_collision_runtime()
	_objects_by_cell.clear()
	_objects_by_id.clear()
	_objects_by_chunk.clear()
	_runtime_slots.clear()
	_runtime_masks.clear()
	_next_object_id = 1
	_last_refresh_count = 0
	if _document == null:
		_grid_size = Vector2i.ZERO
		return

	_grid_size = _document.grid_size
	_cell_size = float(_document.cell_size)
	_index_document_objects()
	_rebuild_all_visuals()
	_rebuild_all_collisions()


func place_object(cell: Vector2i, type_id: String, rotation_quarters: int = 0) -> bool:
	if _document == null or not _is_valid_cell(cell) or _objects_by_cell.has(_cell_key(cell)):
		return false
	var definition: ConstructionDefinition = CONSTRUCTION_CATALOG_SCRIPT.get_definition(type_id)
	if definition == null:
		return false

	var object_id := _next_object_id
	_next_object_id += 1
	var object_data := {
		"object_id": object_id,
		"category": definition.category_id,
		"type_id": type_id,
		"connection_key": definition.connection_key,
		"cell": [cell.x, cell.y],
		"rotation_step": posmod(rotation_quarters, 4),
	}
	_document.objects.append(object_data)
	_objects_by_cell[_cell_key(cell)] = object_data
	_objects_by_id[object_id] = object_data
	_register_object_in_chunk(object_data)
	_allocate_visual_slot(object_data, definition)
	_refresh_centers([cell])
	return true


func remove_object_at_cell(cell: Vector2i) -> bool:
	var object_data = _objects_by_cell.get(_cell_key(cell), null)
	if object_data == null:
		return false
	var object_id := int(object_data.get("object_id", 0))
	_objects_by_cell.erase(_cell_key(cell))
	_objects_by_id.erase(object_id)
	_unregister_object_in_chunk(object_data)
	_runtime_masks.erase(object_id)
	_release_visual_slot(object_data)
	for index in _document.objects.size():
		if int(_document.objects[index].get("object_id", -1)) == object_id:
			_document.objects.remove_at(index)
			break
	_refresh_centers([cell])
	return true


func move_object(object_id: int, destination_cell: Vector2i) -> bool:
	var object_data = _objects_by_id.get(object_id, null)
	if object_data == null or not _is_valid_cell(destination_cell):
		return false
	var origin_cell := _object_cell(object_data)
	if origin_cell == destination_cell or _objects_by_cell.has(_cell_key(destination_cell)):
		return false
	var definition: ConstructionDefinition = _definition_for_object(object_data)
	if definition == null:
		return false

	var runtime_slot: Dictionary = _runtime_slots.get(object_id, {})
	var old_batch_key := str(runtime_slot.get("batch_key", ""))
	var old_chunk := _chunk_for_cell(origin_cell)
	var new_chunk := _chunk_for_cell(destination_cell)
	if old_chunk != new_chunk:
		_release_visual_slot(object_data)
		_unregister_object_in_chunk(object_data)
	_objects_by_cell.erase(_cell_key(origin_cell))
	object_data["cell"] = [destination_cell.x, destination_cell.y]
	_objects_by_cell[_cell_key(destination_cell)] = object_data
	if old_chunk != new_chunk:
		_register_object_in_chunk(object_data)
		_allocate_visual_slot(object_data, definition)
	elif runtime_slot.has("visual_slot") and _batches.has(old_batch_key):
		var batch: Dictionary = _batches[old_batch_key]
		batch["cell_to_slot"].erase(_cell_key(origin_cell))
		batch["cell_to_slot"][_cell_key(destination_cell)] = int(runtime_slot["visual_slot"])
	_refresh_centers([origin_cell, destination_cell], [old_chunk, new_chunk])
	return old_batch_key != str(_runtime_slots.get(object_id, {}).get("batch_key", "")) or origin_cell != destination_cell


func get_object_at_cell(cell: Vector2i):
	var object_data = _objects_by_cell.get(_cell_key(cell), null)
	if object_data == null:
		return null
	var result: Dictionary = object_data.duplicate()
	result["connectivity_mask"] = get_connectivity_mask(cell)
	return result


func get_connectivity_mask(cell: Vector2i) -> int:
	var object_data = _objects_by_cell.get(_cell_key(cell), null)
	if object_data == null:
		return 0
	return int(_runtime_masks.get(int(object_data.get("object_id", 0)), _calculate_connectivity_mask(object_data)))


func update_terrain_region(sample_min: Vector2i, sample_max: Vector2i) -> void:
	if _document == null:
		return
	var touched_chunks: Dictionary = {}
	var affected_object_ids: Dictionary = {}
	_last_refresh_count = 0
	for object_data in _objects_by_id.values():
		var cell := _object_cell(object_data)
		if cell.x < sample_min.x or cell.x > sample_max.x or cell.y < sample_min.y or cell.y > sample_max.y:
			continue
		_update_object_visual(object_data)
		touched_chunks[_chunk_key(_chunk_for_cell(cell))] = _chunk_for_cell(cell)
		affected_object_ids[int(object_data.get("object_id", 0))] = true
		_last_refresh_count += 1
	_sync_collision_chunks(touched_chunks, affected_object_ids)


func get_last_refresh_count() -> int:
	return _last_refresh_count


func get_batch_count() -> int:
	return _batches.size()


func get_render_instance_count() -> int:
	var count := 0
	for batch in _batches.values():
		count += int(batch["active_count"]) * int(batch["max_parts"])
	return count


func _build_shared_resources() -> void:
	if _shared_cube_mesh != null:
		return
	_shared_material = StandardMaterial3D.new()
	_shared_material.albedo_color = DEFAULT_CUBE_COLOR
	_shared_material.roughness = 1.0
	_shared_material.metallic = 0.0
	_shared_material.metallic_specular = 0.0
	_shared_cube_mesh = BoxMesh.new()
	_shared_cube_mesh.size = Vector3.ONE
	_shared_cube_mesh.material = _shared_material


func _index_document_objects() -> void:
	var highest_object_id := 0
	for object_data in _document.objects:
		if not object_data is Dictionary:
			continue
		var cell := _object_cell(object_data)
		if not _is_valid_cell(cell) or _objects_by_cell.has(_cell_key(cell)):
			continue
		var object_id := int(object_data.get("object_id", 0))
		if object_id <= 0 or _objects_by_id.has(object_id):
			object_id = highest_object_id + 1
			object_data["object_id"] = object_id
		highest_object_id = maxi(highest_object_id, object_id)
		var definition: ConstructionDefinition = _definition_for_object(object_data)
		if definition == null:
			continue
		object_data["cell"] = [cell.x, cell.y]
		object_data["category"] = definition.category_id
		object_data["connection_key"] = definition.connection_key
		object_data["rotation_step"] = _object_rotation_step(object_data)
		_objects_by_cell[_cell_key(cell)] = object_data
		_objects_by_id[object_id] = object_data
		_register_object_in_chunk(object_data)
	_next_object_id = highest_object_id + 1
	for object_data in _objects_by_id.values():
		_runtime_masks[int(object_data.get("object_id", 0))] = _calculate_connectivity_mask(object_data)


func _rebuild_all_visuals() -> void:
	for object_data in _objects_by_id.values():
		var definition: ConstructionDefinition = _definition_for_object(object_data)
		if definition != null:
			_allocate_visual_slot(object_data, definition)
	for object_data in _objects_by_id.values():
		_update_object_visual(object_data)


func _rebuild_all_collisions() -> void:
	for chunk_data in _objects_by_chunk.values():
		_rebuild_collision_chunk(chunk_data["chunk"])


func _allocate_visual_slot(object_data: Dictionary, definition: ConstructionDefinition) -> void:
	var cell := _object_cell(object_data)
	var batch_key := _batch_key(cell, definition)
	var batch := _get_or_create_batch(batch_key, _chunk_for_cell(cell), definition)
	var object_id := int(object_data.get("object_id", 0))
	var existing_slot: Dictionary = _runtime_slots.get(object_id, {})
	if str(existing_slot.get("batch_key", "")) == batch_key and existing_slot.has("visual_slot"):
		return
	var free_slots: Array = batch["free_slots"]
	var slot := -1
	if not free_slots.is_empty():
		slot = int(free_slots.pop_back())
	else:
		slot = int(batch["next_slot"])
		batch["next_slot"] = slot + 1
		_ensure_batch_capacity(batch, slot)
	batch["cell_to_slot"][_cell_key(cell)] = slot
	batch["object_ids"][object_id] = true
	batch["active_count"] = int(batch["active_count"]) + 1
	_runtime_slots[object_id] = {"batch_key": batch_key, "visual_slot": slot}


func _release_visual_slot(object_data: Dictionary) -> void:
	var object_id := int(object_data.get("object_id", 0))
	var runtime_slot: Dictionary = _runtime_slots.get(object_id, {})
	var batch_key := str(runtime_slot.get("batch_key", ""))
	if batch_key.is_empty() or not _batches.has(batch_key):
		_runtime_slots.erase(object_id)
		return
	var batch: Dictionary = _batches[batch_key]
	var slot := int(runtime_slot.get("visual_slot", -1))
	if slot >= 0:
		var first_instance := slot * int(batch["max_parts"])
		for part_index in int(batch["max_parts"]):
			batch["multimesh"].set_instance_transform(first_instance + part_index, HIDDEN_TRANSFORM)
		batch["free_slots"].append(slot)
		batch["active_count"] = maxi(0, int(batch["active_count"]) - 1)
	batch["object_ids"].erase(object_id)
	batch["cell_to_slot"].erase(_cell_key(_object_cell(object_data)))
	_runtime_slots.erase(object_id)
	if int(batch["active_count"]) == 0:
		var batch_node: Node3D = batch["node"]
		if is_instance_valid(batch_node):
			batch_node.free()
		_batches.erase(batch_key)


func _get_or_create_batch(batch_key: String, chunk: Vector2i, definition: ConstructionDefinition) -> Dictionary:
	if _batches.has(batch_key):
		return _batches[batch_key]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _shared_cube_mesh
	multimesh.instance_count = INITIAL_BATCH_CAPACITY * definition.max_visual_parts()
	var node := MultiMeshInstance3D.new()
	node.name = "ConstructionBatch_%d_%d_%s" % [chunk.x, chunk.y, definition.batch_key.replace("/", "_")]
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)
	var batch := {
		"key": batch_key,
		"chunk": chunk,
		"node": node,
		"multimesh": multimesh,
		"capacity": INITIAL_BATCH_CAPACITY,
		"max_parts": definition.max_visual_parts(),
		"next_slot": 0,
		"active_count": 0,
		"free_slots": [],
		"cell_to_slot": {},
		"object_ids": {},
	}
	_batches[batch_key] = batch
	return batch


func _ensure_batch_capacity(batch: Dictionary, requested_slot: int) -> void:
	if requested_slot < int(batch["capacity"]):
		return
	var new_capacity := maxi(int(batch["capacity"]) * 2, requested_slot + 1)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _shared_cube_mesh
	multimesh.instance_count = new_capacity * int(batch["max_parts"])
	batch["multimesh"] = multimesh
	batch["capacity"] = new_capacity
	batch["node"].multimesh = multimesh
	for object_id in batch["object_ids"].keys():
		var object_data = _objects_by_id.get(int(object_id), null)
		if object_data != null:
			_update_object_visual(object_data)


func _update_object_visual(object_data: Dictionary) -> void:
	var definition: ConstructionDefinition = _definition_for_object(object_data)
	if definition == null:
		return
	var object_id := int(object_data.get("object_id", 0))
	var runtime_slot: Dictionary = _runtime_slots.get(object_id, {})
	var batch_key := str(runtime_slot.get("batch_key", ""))
	if batch_key.is_empty() or not _batches.has(batch_key):
		return
	var batch: Dictionary = _batches[batch_key]
	var mask := _calculate_connectivity_mask(object_data)
	_runtime_masks[object_id] = mask
	var transforms: Array = definition.build_instance_transforms(
		mask,
		_local_base_position(_object_cell(object_data)),
		_object_rotation_step(object_data),
	)
	var first_instance := int(runtime_slot.get("visual_slot", -1)) * int(batch["max_parts"])
	for part_index in int(batch["max_parts"]):
		var transform := HIDDEN_TRANSFORM
		if part_index < transforms.size():
			transform = transforms[part_index]
		batch["multimesh"].set_instance_transform(first_instance + part_index, transform)


func _refresh_centers(centers: Array, extra_chunks: Array = []) -> void:
	var affected_cells: Dictionary = {}
	var affected_chunks: Dictionary = {}
	var affected_object_ids: Dictionary = {}
	for center in centers:
		if not center is Vector2i:
			continue
		for offset in CARDINAL_OFFSETS:
			var cell: Vector2i = center + offset
			if _is_valid_cell(cell):
				affected_cells[_cell_key(cell)] = cell
		if _is_valid_cell(center):
			affected_cells[_cell_key(center)] = center
			affected_chunks[_chunk_key(_chunk_for_cell(center))] = _chunk_for_cell(center)
	for chunk in extra_chunks:
		if chunk is Vector2i:
			affected_chunks[_chunk_key(chunk)] = chunk
	_last_refresh_count = 0
	for cell in affected_cells.values():
		var object_data = _objects_by_cell.get(_cell_key(cell), null)
		if object_data == null:
			continue
		_update_object_visual(object_data)
		affected_chunks[_chunk_key(_chunk_for_cell(cell))] = _chunk_for_cell(cell)
		affected_object_ids[int(object_data.get("object_id", 0))] = true
		_last_refresh_count += 1
	_sync_collision_chunks(affected_chunks, affected_object_ids)


func _sync_collision_chunks(affected_chunks: Dictionary, affected_object_ids: Dictionary) -> void:
	for chunk in affected_chunks.values():
		var chunk_key := _chunk_key(chunk)
		var chunk_data: Dictionary = _objects_by_chunk.get(chunk_key, {})
		if chunk_data.is_empty() or chunk_data["object_ids"].is_empty():
			_free_collision_body(chunk_key)
			continue
		if not _collision_bodies.has(chunk_key):
			_rebuild_collision_chunk(chunk)
			continue

		var body_data: Dictionary = _collision_bodies[chunk_key]
		var stale_object_ids: Array[int] = []
		for object_id in body_data["object_indices"].keys():
			if not chunk_data["object_ids"].has(int(object_id)):
				stale_object_ids.append(int(object_id))
		for object_id in stale_object_ids:
			_remove_collision_shape(body_data, object_id)

		for object_id in affected_object_ids.keys():
			if not chunk_data["object_ids"].has(int(object_id)):
				continue
			var object_data = _objects_by_id.get(int(object_id), null)
			if object_data == null:
				continue
			_update_collision_shape(body_data, object_data)


func _register_object_in_chunk(object_data: Dictionary) -> void:
	var chunk := _chunk_for_cell(_object_cell(object_data))
	var chunk_key := _chunk_key(chunk)
	var chunk_data: Dictionary = _objects_by_chunk.get(chunk_key, {})
	if chunk_data.is_empty():
		chunk_data = {"chunk": chunk, "object_ids": {}}
	chunk_data["object_ids"][int(object_data.get("object_id", 0))] = true
	_objects_by_chunk[chunk_key] = chunk_data


func _unregister_object_in_chunk(object_data: Dictionary) -> void:
	var chunk_key := _chunk_key(_chunk_for_cell(_object_cell(object_data)))
	if not _objects_by_chunk.has(chunk_key):
		return
	var chunk_data: Dictionary = _objects_by_chunk[chunk_key]
	chunk_data["object_ids"].erase(int(object_data.get("object_id", 0)))
	if chunk_data["object_ids"].is_empty():
		_objects_by_chunk.erase(chunk_key)
	else:
		_objects_by_chunk[chunk_key] = chunk_data


func _calculate_connectivity_mask(object_data: Dictionary) -> int:
	var definition: ConstructionDefinition = _definition_for_object(object_data)
	if definition == null:
		return 0
	var cell := _object_cell(object_data)
	var mask := 0
	for direction_index in 4:
		var neighbor_cell: Vector2i = cell + CARDINAL_OFFSETS[direction_index]
		var neighbor = _objects_by_cell.get(_cell_key(neighbor_cell), null)
		if neighbor == null:
			continue
		var neighbor_definition: ConstructionDefinition = _definition_for_object(neighbor)
		if definition.can_connect_to(neighbor_definition):
			mask |= 1 << direction_index
	return mask


func _rebuild_collision_chunk(chunk: Vector2i) -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	var chunk_key := _chunk_key(chunk)
	var chunk_data: Dictionary = _objects_by_chunk.get(chunk_key, {})
	if chunk_data.is_empty() or chunk_data["object_ids"].is_empty():
		_free_collision_body(chunk_key)
		return
	var body_data := _get_or_create_collision_body(chunk_key)
	if body_data.is_empty():
		return
	var body_rid: RID = body_data["rid"]
	PhysicsServer3D.body_clear_shapes(body_rid)
	body_data["shape_count"] = 0
	body_data["object_indices"].clear()
	for object_id in chunk_data["object_ids"].keys():
		var object_data = _objects_by_id.get(int(object_id), null)
		if object_data == null:
			continue
		_add_collision_shape(body_data, object_data)


func _add_collision_shape(body_data: Dictionary, object_data: Dictionary) -> void:
	var collision_data := _collision_data_for_object(object_data)
	if collision_data.is_empty():
		return
	var shape_index := int(body_data["shape_count"])
	PhysicsServer3D.body_add_shape(
		body_data["rid"],
		collision_data["shape_rid"],
		collision_data["transform"],
	)
	body_data["object_indices"][int(object_data.get("object_id", 0))] = shape_index
	body_data["shape_count"] = shape_index + 1


func _update_collision_shape(body_data: Dictionary, object_data: Dictionary) -> void:
	var object_id := int(object_data.get("object_id", 0))
	if not body_data["object_indices"].has(object_id):
		_add_collision_shape(body_data, object_data)
		return
	var collision_data := _collision_data_for_object(object_data)
	if collision_data.is_empty():
		return
	var shape_index := int(body_data["object_indices"][object_id])
	PhysicsServer3D.body_set_shape(body_data["rid"], shape_index, collision_data["shape_rid"])
	PhysicsServer3D.body_set_shape_transform(body_data["rid"], shape_index, collision_data["transform"])


func _remove_collision_shape(body_data: Dictionary, object_id: int) -> void:
	if not body_data["object_indices"].has(object_id):
		return
	var removed_index := int(body_data["object_indices"][object_id])
	PhysicsServer3D.body_remove_shape(body_data["rid"], removed_index)
	body_data["object_indices"].erase(object_id)
	body_data["shape_count"] = maxi(0, int(body_data["shape_count"]) - 1)
	for other_id in body_data["object_indices"].keys():
		var other_index := int(body_data["object_indices"][other_id])
		if other_index > removed_index:
			body_data["object_indices"][other_id] = other_index - 1


func _collision_data_for_object(object_data: Dictionary) -> Dictionary:
	var definition: ConstructionDefinition = _definition_for_object(object_data)
	if definition == null:
		return {}
	var object_id := int(object_data.get("object_id", 0))
	var mask := int(_runtime_masks.get(object_id, _calculate_connectivity_mask(object_data)))
	var bounds := definition.collision_bounds(mask)
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(float(_object_rotation_step(object_data)) * 90.0))
	var local_position := _local_base_position(_object_cell(object_data)) + rotation_basis * (bounds.position + bounds.size * 0.5)
	var shape_key := "%s:%.3f:%.3f:%.3f" % [definition.batch_key, bounds.size.x, bounds.size.y, bounds.size.z]
	return {
		"shape_rid": _get_collision_shape(shape_key, bounds.size),
		"transform": Transform3D(rotation_basis, local_position),
	}


func _get_or_create_collision_body(chunk_key: String) -> Dictionary:
	if _collision_bodies.has(chunk_key):
		return _collision_bodies[chunk_key]
	var world_space := get_world_3d().space
	if not world_space.is_valid():
		return {}
	var body_rid := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(body_rid, world_space)
	PhysicsServer3D.body_set_collision_layer(body_rid, 1)
	PhysicsServer3D.body_set_collision_mask(body_rid, 1)
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
	var body_data := {"rid": body_rid, "shape_count": 0, "object_indices": {}}
	_collision_bodies[chunk_key] = body_data
	return body_data


func _free_collision_body(chunk_key: String) -> void:
	if not _collision_bodies.has(chunk_key):
		return
	var body_data: Dictionary = _collision_bodies[chunk_key]
	var body_rid: RID = body_data["rid"]
	if body_rid.is_valid():
		PhysicsServer3D.free_rid(body_rid)
	_collision_bodies.erase(chunk_key)


func _get_collision_shape(shape_key: String, size: Vector3) -> RID:
	if _collision_shapes.has(shape_key):
		return _collision_shapes[shape_key]
	var shape_rid := PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape_rid, size * 0.5)
	_collision_shapes[shape_key] = shape_rid
	return shape_rid


func _clear_visual_runtime() -> void:
	for batch in _batches.values():
		var node: Node3D = batch["node"]
		if is_instance_valid(node):
			node.free()
	_batches.clear()


func _clear_collision_runtime() -> void:
	for body_data in _collision_bodies.values():
		var body_rid: RID = body_data["rid"]
		if body_rid.is_valid():
			PhysicsServer3D.free_rid(body_rid)
	_collision_bodies.clear()
	for shape_rid in _collision_shapes.values():
		if shape_rid.is_valid():
			PhysicsServer3D.free_rid(shape_rid)
	_collision_shapes.clear()


func _definition_for_object(object_data: Dictionary) -> ConstructionDefinition:
	return CONSTRUCTION_CATALOG_SCRIPT.get_definition(str(object_data.get("type_id", "")))


func _object_cell(object_data: Dictionary) -> Vector2i:
	var serialized_cell: Variant = object_data.get("cell", [])
	if serialized_cell is Array and serialized_cell.size() >= 2:
		return Vector2i(int(serialized_cell[0]), int(serialized_cell[1]))
	return Vector2i(-1, -1)


func _object_rotation_step(object_data: Dictionary) -> int:
	return posmod(int(object_data.get("rotation_step", object_data.get("rotation_quarters", 0))), 4)


func _local_base_position(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * _cell_size, float(_document.get_height(cell)), float(cell.y) * _cell_size)


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_size.x and cell.y < _grid_size.y


func _cell_key(cell: Vector2i) -> int:
	return cell.x + cell.y * KEY_STRIDE


func _chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(CHUNK_SAMPLE_STRIDE)), floori(float(cell.y) / float(CHUNK_SAMPLE_STRIDE)))


func _chunk_key(chunk: Vector2i) -> String:
	return "%d:%d" % [chunk.x, chunk.y]


func _batch_key(cell: Vector2i, definition: ConstructionDefinition) -> String:
	return "%s:%s" % [_chunk_key(_chunk_for_cell(cell)), definition.batch_key]
