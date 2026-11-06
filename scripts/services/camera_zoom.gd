extends RefCounted
## A shared scale for wheel ticks and macOS continuous trackpad gestures.
static func accepts(event: InputEvent) -> bool:
	if event is InputEventPanGesture:return is_finite(event.delta.y) and not is_zero_approx(event.delta.y)
	if event is InputEventMagnifyGesture:return is_finite(event.factor) and event.factor>0.
	return event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]
static func distance_for(event: InputEvent,distance: float,step: float,minimum: float,maximum: float) -> float:
	if not accepts(event):return distance
	if event is InputEventMagnifyGesture:return clampf(distance/event.factor,minimum,maximum)
	var delta: float=event.delta.y if event is InputEventPanGesture else (1. if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1.)*(event.factor if is_finite(event.factor) and event.factor>0. else 1.)
	return clampf(distance+delta*step,minimum,maximum)
