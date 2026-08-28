extends RefCounted
class_name ConstructionDefinition

var type_id := ""
var category_id := ""
var display_name := ""
var batch_key := ""
var connection_key := ""


func _init(
	definition_id: String,
	definition_category: String,
	definition_name: String,
	definition_batch_key: String,
	definition_connection_key: String,
) -> void:
	type_id = definition_id
	category_id = definition_category
	display_name = definition_name
	batch_key = definition_batch_key
	connection_key = definition_connection_key


func max_visual_parts() -> int:
	return 0


func build_instance_transforms(
	_connectivity_mask: int,
	_base_position: Vector3,
	_rotation_quarters: int,
) -> Array:
	return []


func collision_bounds(_connectivity_mask: int) -> AABB:
	return AABB()


func can_connect_to(other: ConstructionDefinition) -> bool:
	return other != null and connection_key == other.connection_key
