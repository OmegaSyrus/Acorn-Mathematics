## Registers the input actions in code so they are easy to read and port.
## Touch is handled per screen; these are the controller and keyboard actions.
extends RefCounted

const DEADZONE := 0.5


static func register() -> void:
	_action("pick", [JOY_BUTTON_A], [KEY_SPACE, KEY_ENTER])
	_action("back", [JOY_BUTTON_B], [KEY_ESCAPE, KEY_BACKSPACE])
	_action("repeat", [JOY_BUTTON_Y], [KEY_R])
	_action("debug", [JOY_BUTTON_BACK], [KEY_F1])
	_action("fullscreen", [], [KEY_F11])
	_action("move_left", [JOY_BUTTON_DPAD_LEFT], [KEY_LEFT, KEY_A], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [JOY_BUTTON_DPAD_RIGHT], [KEY_RIGHT, KEY_D], JOY_AXIS_LEFT_X, 1.0)
	_action("move_up", [JOY_BUTTON_DPAD_UP], [KEY_UP, KEY_W], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_down", [JOY_BUTTON_DPAD_DOWN], [KEY_DOWN, KEY_S], JOY_AXIS_LEFT_Y, 1.0)


static func _action(name: StringName, buttons: Array, keys: Array, axis := -1, axis_dir := 0.0) -> void:
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, DEADZONE)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(name, e)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	if axis >= 0:
		var e := InputEventJoypadMotion.new()
		e.axis = axis
		e.axis_value = axis_dir
		InputMap.action_add_event(name, e)
