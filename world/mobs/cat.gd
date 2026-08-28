extends CharacterBody3D
class_name Cat
## Mob animal simple (gato). El movimiento lo decide DogAi (Rust) - el mismo
## sistema de estados que el perro (walk/run/idle/sit/lay) - pero el modelo
## del gato SOLO tiene la animacion "walk", asi que este script usa "walk"
## cuando el gato se mueve y se queda quieto (sin animacion) cuando no.
## El modelo visual es el gato real (assets/cat/cat.fbx), cargado y
## normalizado por CatModelUtils.build_model().

const GRAVITY := 20.0
const WANDER_SPEED := 1.6
const TURN_SPEED := 5.0 # que tan rapido gira para mirar hacia donde camina

const ANIM_WALK := "walk"

var _ai = null
var _anim_player: AnimationPlayer = null
var _current_anim := ""


func _ready() -> void:
	if ClassDB.class_exists("DogAi"):
		_ai = ClassDB.instantiate("DogAi")
		_ai.call("set_speed", WANDER_SPEED)
		add_child(_ai)
	else:
		push_warning("[cat] DogAi no esta disponible - compila rust_core (cargo build) y reabre el proyecto.")

	CatModelUtils.build_model(self)
	_find_anim_player()


## Busca el AnimationPlayer dentro del modelo "Model" (hijo de este nodo).
func _find_anim_player() -> void:
	var model := get_node_or_null("Model")
	if model == null:
		return
	_anim_player = _find_anim_player_recursive(model)


func _find_anim_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player_recursive(child)
		if found != null:
			return found
	return null


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	var moving := false
	if _ai != null:
		var result: Dictionary = _ai.call("tick", delta)
		var wander: Vector3 = result.get("velocity", Vector3.ZERO)
		velocity.x = wander.x
		velocity.z = wander.z
		if Vector2(wander.x, wander.z).length() > 0.01:
			moving = true
			# El modelo mira hacia -Z (direccion de avance de Godot). El forward
			# global tras rotar rotation.y=theta es (-sin theta, 0, -cos theta).
			# Para que mire hacia (dx, dz): theta = atan2(-dx, -dz).
			var target_angle := atan2(-wander.x, -wander.z)
			rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

	move_and_slide()

	# El gato solo tiene animacion "walk": se reproduce cuando se mueve, y se
	# detiene (queda quieto) cuando no.
	_update_animation(ANIM_WALK if moving else "")


## Reproduce la animacion "walk" cuando el gato se mueve, o la detiene cuando
## esta quieto. Solo cambia cuando el estado cambia.
func _update_animation(anim: String) -> void:
	if _anim_player == null:
		return
	if anim == _current_anim:
		return
	_current_anim = anim
	if anim.is_empty():
		_anim_player.stop()
		return
	if _anim_player.has_animation(anim):
		var anim_res: Animation = _anim_player.get_animation(anim)
		if anim_res != null:
			anim_res.loop_mode = Animation.LOOP_LINEAR
		_anim_player.play(anim)
	else:
		push_warning("[cat] No existe la animacion '%s'." % anim)
