extends Camera3D
class_name FreeFlyCamera
## Camara libre simple para escenas de prueba (sin gravedad/colision):
## WASD + mouse para mirar (mismo patron que player.gd usa con InputManager),
## Q/E para subir/bajar. ESC libera el mouse, click izquierdo lo vuelve a
## capturar.

const MOVE_SPEED := 12.0
const LOOK_PITCH_LIMIT := 1.4 # radianes, ~80 grados


func _ready() -> void:
	current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	InputManager.look_input.connect(_apply_look)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	var mouse_delta := InputManager.get_mouse_look_delta(event)
	if mouse_delta != Vector2.ZERO:
		_apply_look(mouse_delta)


func _process(delta: float) -> void:
	var move_input := InputManager.get_movement_vector()
	var move_dir := Vector3.ZERO
	if move_input.length() > 0.0:
		move_dir = (transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()

	var vertical := 0.0
	if Input.is_physical_key_pressed(KEY_E):
		vertical += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		vertical -= 1.0

	global_position += (move_dir * MOVE_SPEED + Vector3.UP * vertical * MOVE_SPEED) * delta


func _apply_look(mouse_delta: Vector2) -> void:
	rotate_y(-mouse_delta.x)
	rotation.x = clamp(rotation.x - mouse_delta.y, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
