extends RefCounted
## Player is on the left: larger support pulls the marker leftward.
static func marker_fraction(score: float) -> float:
	return 1.0 - clampf(score / 100.0, 0, 1)
