extends Node
## Autoload singleton (register as "InputManager") that abstracts input across
## PC (keyboard/mouse/gamepad) and mobile (touch), so gameplay code never has
## to branch on platform directly.

signal look_input(delta: Vector2)

const TOUCH_JOYSTICK_MAX_RADIUS := 80.0
const MOUSE_LOOK_SENSITIVITY := 0.005
const TOUCH_LOOK_SENSITIVITY := 0.01

var is_touch_mode: bool = DisplayServer.is_touchscreen_available()

var _movement_touch_index: int = -1
var _movement_touch_origin: Vector2 = Vector2.ZERO
var _movement_touch_current: Vector2 = Vector2.ZERO

var _look_touch_index: int = -1
var _look_touch_last: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_touch_mode:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var is_left_half := event.position.x < get_viewport().get_visible_rect().size.x * 0.5

	if event.pressed:
		if is_left_half and _movement_touch_index == -1:
			_movement_touch_index = event.index
			_movement_touch_origin = event.position
			_movement_touch_current = event.position
		elif not is_left_half and _look_touch_index == -1:
			_look_touch_index = event.index
			_look_touch_last = event.position
	else:
		if event.index == _movement_touch_index:
			_movement_touch_index = -1
			_movement_touch_current = _movement_touch_origin
		elif event.index == _look_touch_index:
			_look_touch_index = -1


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _movement_touch_index:
		_movement_touch_current = event.position
	elif event.index == _look_touch_index:
		var delta := (event.position - _look_touch_last) * TOUCH_LOOK_SENSITIVITY
		_look_touch_last = event.position
		look_input.emit(delta)


## Returns a movement vector (x = strafe, y = forward/back) in the [-1, 1]
## range, sourced from keyboard (WASD/arrows), gamepad left stick, or the
## on-screen virtual joystick (left half of the screen) on touch devices.
func get_movement_vector() -> Vector2:
	if is_touch_mode:
		if _movement_touch_index == -1:
			return Vector2.ZERO
		var offset := _movement_touch_current - _movement_touch_origin
		return offset.limit_length(TOUCH_JOYSTICK_MAX_RADIUS) / TOUCH_JOYSTICK_MAX_RADIUS

	var vec := Vector2.ZERO
	vec.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right")) \
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"))
	vec.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down")) \
		- float(Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"))

	vec.x += Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	vec.y += Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

	return vec.limit_length(1.0)


## Call from gameplay code's own `_unhandled_input(event)` to get PC mouse-look
## deltas. Mobile look deltas arrive via the `look_input` signal instead
## (right half of the screen, drag-to-look).
func get_mouse_look_delta(event: InputEvent) -> Vector2:
	if not is_touch_mode and event is InputEventMouseMotion:
		return event.relative * MOUSE_LOOK_SENSITIVITY
	return Vector2.ZERO
