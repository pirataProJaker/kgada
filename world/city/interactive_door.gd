extends Node3D
class_name InteractiveDoor
## Puerta interactiva generada proceduralmente por HouseGenerator._place_door.
##
## Este nodo ES el pivote/bisagra: vive en el BORDE del hueco de la puerta
## (no en el centro, como una puerta real) y gira sobre su propio eje Y para
## simular el giro. La hoja (`_slab`, un StaticBody3D hijo con colision) es
## la que efectivamente se mueve al rotar este nodo.
##
## Comportamiento pedido por diseño:
## - Tecla E (ver player/interact_controller.gd) hace toggle abrir/cerrar,
##   con una velocidad angular fija.
## - Es "dinamica": si algo bloquea el giro (mueble, el propio jugador,
##   otra puerta, etc.) se detiene exactamente ahi, no se teletransporta.
## - Abre preferentemente hacia el lado "de adentro" que calcula
##   HouseGenerator._place_door (ver `open_sign` en setup()) - una puerta
##   de entrada nunca deberia abrirse hacia la calle. Si ese lado preferido
##   esta bloqueado (por ejemplo una pared divisoria interior muy cerca del
##   vano) se intenta automaticamente el lado contrario antes de rendirse,
##   para no dejar al jugador "encerrado" por una puerta que nunca abre del
##   todo.
## - NO tiene interaccion por contacto con el cuerpo (a proposito, ver
##   pedido explicito de diseño) - solo la tecla E la mueve.

const MAX_OPEN_ANGLE_DEG := 105.0
const ANGULAR_SPEED_DEG := 160.0 # grados/seg al abrir o cerrar con E

var current_angle := 0.0

var _target_angle := 0.0
## Angulo (con signo) al que se apunta al abrir del todo - su signo decide
## hacia que lado gira la puerta. Ver setup().
var _open_target_deg := MAX_OPEN_ANGLE_DEG
var _base_rotation_degrees := 0.0
var _slab: StaticBody3D = null
var _collision_shape: CollisionShape3D = null
## RIDs que ya estaban tocando la caja de colision de la hoja en el
## momento de generarse (p. ej. el piso o una jamba rozando por precision
## de la malla/escala) - se capturan una sola vez en el primer frame de
## fisica y se excluyen para siempre de _is_obstructed, para que un
## contacto de fabrica no deje la puerta "obstruida" desde el principio.
var _baseline_exclude: Array = []
var _baseline_captured := false


## Llamado una sola vez por HouseGenerator justo despues de armar el arbol
## de nodos (hoja + colision). `open_sign` (+1 o -1) decide hacia que lado
## gira la puerta al abrirse del todo - HouseGenerator lo calcula para que
## las puertas de entrada siempre abran hacia adentro de la casa.
func setup(slab: StaticBody3D, collision_shape: CollisionShape3D, open_sign: float = 1.0) -> void:
	_slab = slab
	_collision_shape = collision_shape
	_base_rotation_degrees = rotation_degrees.y
	_open_target_deg = MAX_OPEN_ANGLE_DEG * (-1.0 if open_sign < 0.0 else 1.0)


func _physics_process(delta: float) -> void:
	if _slab == null:
		return
	if not _baseline_captured:
		_capture_baseline_exclude()
	var diff := _target_angle - current_angle
	if absf(diff) > 0.05:
		var step := clampf(diff, -ANGULAR_SPEED_DEG * delta, ANGULAR_SPEED_DEG * delta)
		_try_advance_angle(step)


## Punto de interaccion para la tecla E (ver InteractController). Alterna
## entre completamente abierta y completamente cerrada. Si el lado
## preferido (`_open_target_deg`) esta bloqueado en este momento pero el
## lado opuesto esta libre, abre hacia ese lado opuesto en su lugar.
func interact(interactor: Node) -> void:
	if not is_zero_approx(_target_angle):
		_target_angle = 0.0
		return
	var target := _open_target_deg
	if not _angle_is_clear(target) and _angle_is_clear(-target):
		target = -target
	_target_angle = target
	_play_push_animation(interactor)


func _play_push_animation(interactor: Node) -> void:
	if interactor == null:
		return
	var arms := interactor.get_node_or_null("Head/Camera3D/FirstPersonArms")
	if arms == null:
		return
	var anim_name := "ArmsRig|push_L" if randi() % 2 == 0 else "ArmsRig|push_R"
	arms.play_action_animation(anim_name)


func _try_advance_angle(delta_deg: float) -> bool:
	var previous_angle := current_angle
	var low := minf(0.0, _open_target_deg)
	var high := maxf(0.0, _open_target_deg)
	var candidate := clampf(current_angle + delta_deg, low, high)
	if is_equal_approx(candidate, previous_angle):
		return false
	current_angle = candidate
	rotation_degrees.y = _base_rotation_degrees + current_angle
	if _is_obstructed():
		current_angle = previous_angle
		rotation_degrees.y = _base_rotation_degrees + current_angle
		return false
	return true


func _is_obstructed() -> bool:
	if _collision_shape == null or _collision_shape.shape == null or _slab == null:
		return false
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return false
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _collision_shape.shape
	params.transform = _collision_shape.global_transform
	params.exclude = [_slab.get_rid()] + _baseline_exclude
	var overlaps := space_state.intersect_shape(params, 4)
	return not overlaps.is_empty()


## Prueba "que pasaria si" la hoja terminara girada `angle_deg` grados
## (relativo a la posicion de reposo, mismo signo que _target_angle) SIN
## mover el nodo real: rota la transformada GLOBAL actual del shape de
## colision alrededor del propio origen del pivote (bisagra) el angulo
## extra necesario para llegar ahi desde el angulo actual. Sirve para
## decidir, antes de comprometerse, si conviene abrir hacia el lado
## preferido o hacia el opuesto (ver interact()).
func _angle_is_clear(angle_deg: float) -> bool:
	if _collision_shape == null or _collision_shape.shape == null or _slab == null:
		return true
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return true
	var delta_deg := angle_deg - current_angle
	var pivot_origin := global_transform.origin
	var delta_basis := Basis(Vector3.UP, deg_to_rad(delta_deg))
	var current_shape_transform := _collision_shape.global_transform
	var relative := current_shape_transform.origin - pivot_origin
	var hypothetical_origin := pivot_origin + delta_basis * relative
	var hypothetical_transform := Transform3D(delta_basis * current_shape_transform.basis, hypothetical_origin)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _collision_shape.shape
	params.transform = hypothetical_transform
	params.exclude = [_slab.get_rid()] + _baseline_exclude
	var overlaps := space_state.intersect_shape(params, 4)
	return overlaps.is_empty()


## Se llama una sola vez, en el primer _physics_process (para asegurar que
## el espacio fisico ya reconoce toda la geometria recien generada de la
## casa). Cualquier cosa que ya este tocando la hoja en su posicion de
## reposo (cerrada) queda excluida para siempre de _is_obstructed - ver
## comentario de _baseline_exclude arriba.
func _capture_baseline_exclude() -> void:
	_baseline_captured = true
	if _collision_shape == null or _collision_shape.shape == null or _slab == null:
		return
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _collision_shape.shape
	params.transform = _collision_shape.global_transform
	params.exclude = [_slab.get_rid()]
	var overlaps := space_state.intersect_shape(params, 8)
	for o in overlaps:
		var collider = o.get("collider")
		if collider is CollisionObject3D:
			_baseline_exclude.append(collider.get_rid())
