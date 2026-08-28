extends Camera3D
## Camara libre simple (WASD + mouse + Q/E para subir/bajar, Shift para
## acelerar) solo para recorrer la escena de inspeccion de modelos urbanos.

@export var move_speed: float = 12.0
@export var fast_multiplier: float = 4.0
@export var mouse_sensitivity: float = 0.0025

var _yaw: float = 0.0
var _pitch: float = 0.0
var _mouse_captured: bool = true


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var rot := rotation
	_yaw = rot.y
	_pitch = rot.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_mouse_captured = not _mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and _mouse_captured:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	if Input.is_key_pressed(KEY_E):
		input_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		input_dir += Vector3.DOWN

	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		var speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= fast_multiplier
		position += input_dir * speed * delta
