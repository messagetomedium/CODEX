extends RefCounted
## Swept square ball hitbox against a translating rectangle, including radius change.
## Returns first contact fraction, or -1. Endpoints alone would miss fast crossings.

static func first_contact(from: Vector2, to: Vector2, radius_from: float, radius_to: float, rect_from: Rect2, rect_to: Rect2) -> float:
	var enter := 0.0
	var leave := 1.0
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
