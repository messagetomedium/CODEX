extends RefCounted
## Swept depth interval plus square hitbox against a translating rectangle.
## Returns first contact fraction, or -1. Endpoints alone would miss fast crossings.

static func depth_interval(from: float, to: float, depth: float, half_depth: float) -> Vector2:
	if from == to:
		return Vector2(0, 1) if absf(from - depth) <= half_depth else Vector2(-1, -1)
	var a := (depth - half_depth - from) / (to - from)
	var b := (depth + half_depth - from) / (to - from)
	var enter := maxf(0, minf(a, b))
	var leave := minf(1, maxf(a, b))
	return Vector2(enter, leave) if enter <= leave else Vector2(-1, -1)

static func first_contact(from: Vector2, to: Vector2, radius_from: float, radius_to: float, rect_from: Rect2, rect_to: Rect2, depth_window: Vector2 = Vector2(0, 1)) -> float:
	if depth_window.x < 0:
		return -1
	var enter := depth_window.x
	var leave := depth_window.y
	var a := [from.x + radius_from - rect_from.position.x, rect_from.end.x - from.x + radius_from, from.y + radius_from - rect_from.position.y, rect_from.end.y - from.y + radius_from]
	var b := [to.x + radius_to - rect_to.position.x, rect_to.end.x - to.x + radius_to, to.y + radius_to - rect_to.position.y, rect_to.end.y - to.y + radius_to]
	for i in 4:
		if a[i] < 0 and b[i] < 0:
			return -1
		var change: float = b[i] - a[i]
		if change > 0 and a[i] < 0:
			enter = maxf(enter, -a[i] / change)
		elif change < 0 and b[i] < 0:
			leave = minf(leave, -a[i] / change)
	return enter if enter <= leave else -1.0
