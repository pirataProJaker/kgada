extends ConstructionDefinition
class_name FenceConstructionDefinition

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const MAX_VISUAL_PARTS := 12
const POST_SIZE := Vector3(0.22, 2.0, 0.22)
const RAIL_SIZE := Vector3(2.0, 0.16, 0.16)
const ARM_RAIL_SIZE := Vector3(0.5, 0.16, 0.16)
const TRANSVERSE_RAIL_SIZE := Vector3(0.16, 0.16, 0.5)
const ARM_POST_POSITION := 1.25
const BASE_POST_POSITIONS := [-0.9, 0.0, 0.9]
const RAIL_HEIGHT := 1.05


func _init() -> void:
	super._init(
		"smart_fence",
		"fences",
		"Valla inteligente",
		"fence/smart",
		"fence/smart",
	)


func max_visual_parts() -> int:
	return MAX_VISUAL_PARTS


func build_instance_transforms(
	connectivity_mask: int,
	base_position: Vector3,
	rotation_quarters: int,
) -> Array:
	var transforms: Array = []
	var rotation_basis := Basis(Vector3.UP, deg_to_rad(float(rotation_quarters) * 90.0))

	for local_x in BASE_POST_POSITIONS:
		_append_box(transforms, base_position, rotation_basis, Vector3(local_x, 1.0, 0.0), POST_SIZE)
	_append_box(transforms, base_position, rotation_basis, Vector3.ZERO + Vector3(0.0, RAIL_HEIGHT, 0.0), RAIL_SIZE)

	if connectivity_mask & NORTH:
		_append_box(transforms, base_position, rotation_basis, Vector3(0.0, RAIL_HEIGHT, -1.125), TRANSVERSE_RAIL_SIZE)
		_append_box(transforms, base_position, rotation_basis, Vector3(0.0, 1.0, -ARM_POST_POSITION), POST_SIZE)
	if connectivity_mask & EAST:
		_append_box(transforms, base_position, rotation_basis, Vector3(1.125, RAIL_HEIGHT, 0.0), ARM_RAIL_SIZE)
		_append_box(transforms, base_position, rotation_basis, Vector3(ARM_POST_POSITION, 1.0, 0.0), POST_SIZE)
	if connectivity_mask & SOUTH:
		_append_box(transforms, base_position, rotation_basis, Vector3(0.0, RAIL_HEIGHT, 1.125), TRANSVERSE_RAIL_SIZE)
		_append_box(transforms, base_position, rotation_basis, Vector3(0.0, 1.0, ARM_POST_POSITION), POST_SIZE)
	if connectivity_mask & WEST:
		_append_box(transforms, base_position, rotation_basis, Vector3(-1.125, RAIL_HEIGHT, 0.0), ARM_RAIL_SIZE)
		_append_box(transforms, base_position, rotation_basis, Vector3(-ARM_POST_POSITION, 1.0, 0.0), POST_SIZE)

	return transforms


func collision_bounds(connectivity_mask: int) -> AABB:
	var half_x := 1.10
	var half_z := 0.13
	if connectivity_mask & (EAST | WEST):
		half_x = 1.38
	if connectivity_mask & (NORTH | SOUTH):
		half_z = 1.38
	return AABB(Vector3(-half_x, 0.0, -half_z), Vector3(half_x * 2.0, 2.0, half_z * 2.0))


func _append_box(
	transforms: Array,
	base_position: Vector3,
	rotation_basis: Basis,
	local_position: Vector3,
	size: Vector3,
) -> void:
	var world_position := base_position + rotation_basis * local_position
	transforms.append(Transform3D(rotation_basis.scaled(size), world_position))
