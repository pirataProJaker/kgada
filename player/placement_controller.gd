extends Node
class_name PlacementController
## Sistema de "fantasma" de colocacion (estilo Rust): mientras el hotbar
## tiene seleccionado un objeto colocable, muestra un modelo
## semitransparente pegado a donde apunta la camara, respetando colisiones
## (no lo atraviesa - se pega EXACTO sobre la superficie que golpea el
## rayo). Verde si se puede colocar ahi, rojo si no. Con click izquierdo (y
## el fantasma en verde) se coloca de verdad y se consume del inventario.

const PLACEMENT_MAX_DISTANCE := 6.0
const OVERLAP_CHECK_SIZE := Vector3(0.7, 0.5, 0.7)
const OVERLAP_SURFACE_GAP := 0.08 # separa la caja de prueba de la superficie para no chocar contra el propio piso
const MIN_SURFACE_NORMAL_Y := 0.3 # evita colocar en paredes/techos muy inclinados

var _ghost: Node3D = null
var _ghost_definition: ObjectDefinition = null
var _is_valid_placement := false
var _player: Node3D = null
var _inventory: Inventory = null


func _ready() -> void:
	_player = get_parent()
	if not _player.is_multiplayer_authority():
		# Solo el dueño local de este Player coloca objetos - en otros peers
		# este nodo no hace nada.
		set_process(false)
		return
	_inventory = _player.get_node("Inventory")


func _process(_delta: float) -> void:
	var definition := _inventory.get_selected_definition()
	if definition != _ghost_definition:
		_rebuild_ghost(definition)

	if _ghost == null:
		return
	_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if _ghost == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _is_valid_placement:
			_place()


func _rebuild_ghost(definition: ObjectDefinition) -> void:
	_clear_ghost()
	_ghost_definition = definition
	if definition == null:
		return

	var model := ContentLoader.load_model_for_definition(definition)
	if model == null:
		model = MeshInstance3D.new()
		model.mesh = BoxMesh.new()
		model.scale = Vector3.ONE * definition.model_scale

	_ghost = Node3D.new()
	_ghost.name = "PlacementGhost"
	_ghost.add_child(model)
	_ghost.visible = false
	get_tree().current_scene.add_child(_ghost)


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_definition = null
	_is_valid_placement = false


func _update_ghost() -> void:
	var camera: Camera3D = _player.camera
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * PLACEMENT_MAX_DISTANCE

	var space_state := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player.get_rid()]
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		_ghost.visible = false
		_is_valid_placement = false
		return

	var hit_pos: Vector3 = result.position
	var hit_normal: Vector3 = result.normal

	# Se posiciona EXACTO en el punto donde el rayo golpeo la superficie, asi
	# que si miras al piso el fantasma queda sobre el piso y no lo atraviesa.
	_ghost.visible = true
	_ghost.global_position = hit_pos
	_ghost.global_transform.basis = _basis_from_normal(hit_normal)

	_is_valid_placement = _check_valid(hit_pos, hit_normal)
	_tint_ghost(Color(0, 1, 0, 0.5) if _is_valid_placement else Color(1, 0, 0, 0.5))


func _basis_from_normal(normal: Vector3) -> Basis:
	var reference := Vector3.FORWARD
	if abs(normal.dot(reference)) > 0.95:
		reference = Vector3.RIGHT
	var basis := Basis()
	basis.y = normal
	basis.x = reference.cross(normal).normalized()
	basis.z = basis.x.cross(normal).normalized()
	return basis.orthonormalized()


func _check_valid(hit_pos: Vector3, hit_normal: Vector3) -> bool:
	if hit_normal.y < MIN_SURFACE_NORMAL_Y:
		return false

	var shape := BoxShape3D.new()
	shape.size = OVERLAP_CHECK_SIZE

	# La caja de prueba se levanta un poco sobre la superficie (gap) para que
	# NO toque el propio suelo/terreno que acabamos de golpear con el rayo -
	# si tocara, intersect_shape siempre reportaria un "choque" contra el piso
	# mismo y nunca dejaria colocar nada.
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), hit_pos + hit_normal * (OVERLAP_CHECK_SIZE.y * 0.5 + OVERLAP_SURFACE_GAP))
	params.exclude = [_player.get_rid()]

	var space_state := _player.get_world_3d().direct_space_state
	var overlaps := space_state.intersect_shape(params, 4)
	return overlaps.is_empty()


func _tint_ghost(color: Color) -> void:
	_apply_material_recursive(_ghost, color)


func _apply_material_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, color)


func _place() -> void:
	# "Huevo de invocacion": en vez de crear un objeto estatico, invoca la
	# entidad real (con IA/fisica) registrada en EntityTypes.
	if _ghost_definition is SpawnEggDefinition:
		_place_entity(_ghost_definition as SpawnEggDefinition)
		return

	var behavior_script_path := BehaviorTypes.behavior_script_for_config(_ghost_definition.get_script().resource_path)
	if behavior_script_path.is_empty():
		push_warning("[PlacementController] No hay comportamiento registrado para '%s'." % _ghost_definition.id)
		return

	var behavior_script: Script = load(behavior_script_path)
	var instance = behavior_script.new()
	instance.config = _ghost_definition
	get_tree().current_scene.add_child(instance)
	instance.global_transform = _ghost.global_transform

	# Se consume del inventario; si aun quedan unidades del mismo objeto en
	# el slot, _process() detecta que la definicion seleccionada sigue
	# siendo la misma y deja el fantasma listo para seguir colocando.
	_inventory.consume_selected()


func _place_entity(egg: SpawnEggDefinition) -> void:
	var entity_data: Dictionary = EntityTypes.TYPES.get(egg.entity_key, {})
	if entity_data.is_empty():
		push_warning("[PlacementController] Entidad desconocida en huevo: '%s'." % egg.entity_key)
		return

	var scene: PackedScene = load(entity_data["scene"])
	if scene == null:
		push_warning("[PlacementController] No se pudo cargar la escena de '%s'." % egg.entity_key)
		return

	var instance: Node3D = scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = _ghost.global_position

	_inventory.consume_selected()
