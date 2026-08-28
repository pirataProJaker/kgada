extends Node
class_name MeleeController
## Ataque cuerpo a cuerpo simple (estilo Rust, pero simplificado): con las
## manos vacias (ningun objeto colocable seleccionado en el hotbar), click
## izquierdo lanza un golpe. Reproduce una animacion de golpe en
## FirstPersonArms (jab_L/jab_R, alternando para que se sienta como un
## combo) y, un poco despues (cuando la animacion "llega" al punto de
## impacto), lanza un raycast corto desde la camara - si golpea algo con un
## metodo take_damage() (arboles talables via ChoppableTree, zombies, etc.)
## le hace daño.
##
## Convive con PlacementController: PlacementController solo actua cuando
## hay un objeto COLOCABLE seleccionado en el hotbar; este controlador solo
## actua cuando NO hay nada seleccionado (manos vacias) - asi el click
## izquierdo nunca hace las dos cosas a la vez.

const ATTACK_RANGE := 3.0
const ATTACK_DAMAGE := 12.0
const ATTACK_COOLDOWN := 0.6 # segundos entre golpes
const IMPACT_DELAY := 0.18 # cuanto tarda la animacion en "llegar" al golpe antes de aplicar el daño
const SWING_ANIMS := ["ArmsRig|jab_R", "ArmsRig|jab_L"] # alterna de mano

var _player: Node3D = null
var _inventory: Inventory = null
var _arms: FirstPersonArms = null
var _cooldown := 0.0
var _swing_index := 0


func _ready() -> void:
	_player = get_parent()
	if not _player.is_multiplayer_authority():
		# Solo el dueño local de este Player ataca - en otros peers este
		# nodo no hace nada (mismo patron que PlacementController).
		set_process(false)
		return
	_inventory = _player.get_node("Inventory")
	_arms = _player.get_node_or_null("Head/Camera3D/FirstPersonArms")


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _cooldown > 0.0:
		return
	# Manos vacias unicamente: si hay algo colocable seleccionado, ese click
	# lo maneja PlacementController (colocar el objeto), no este ataque.
	if _inventory.get_selected_definition() != null:
		return

	_attack()


func _attack() -> void:
	_cooldown = ATTACK_COOLDOWN
	if _player.has_method("emit_noise"):
		_player.emit_noise(1.0)
	if _arms != null:
		_arms.play_action_animation(SWING_ANIMS[_swing_index])
		_swing_index = (_swing_index + 1) % SWING_ANIMS.size()

	get_tree().create_timer(IMPACT_DELAY).timeout.connect(_apply_hit)


func _apply_hit() -> void:
	if not is_instance_valid(_player):
		return
	var camera: Camera3D = _player.camera
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * ATTACK_RANGE

	var space_state := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player.get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider = result["collider"]
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(ATTACK_DAMAGE)
