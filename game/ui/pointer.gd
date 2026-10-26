## Touch and mouse treated alike. Mouse is for PC testing; touch and mouse
## emulation are both off in project settings so each tap arrives once.
extends RefCounted


static func is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.is_pressed()
	var mb := event as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT


static func is_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not event.is_pressed()
	var mb := event as InputEventMouseButton
	return mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT


static func is_drag(event: InputEvent) -> bool:
	if event is InputEventScreenDrag:
		return true
	var mm := event as InputEventMouseMotion
	return mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0


## The event position in the canvas item's local coordinates.
static func local_pos(ci: CanvasItem, event: InputEvent) -> Vector2:
	var e = ci.make_input_local(event)
	return e.position
