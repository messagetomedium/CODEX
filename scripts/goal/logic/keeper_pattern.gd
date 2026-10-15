extends RefCounted
## Repeating, piecewise-linear movement with explicit holds and reversals.
## Positions depend on simulation time, never random samples or render frames.

static func duration(settings: Dictionary) -> float:
	var result := 0.0
	var previous := 0.5
	for leg in settings.pattern:
		result += absf(float(leg.to) - previous) * settings.crossScreenSeconds + float(leg.holdMs) / 1000.0
		previous = float(leg.to)
	return result

static func sample(seconds: float, settings: Dictionary) -> Vector2:
	var cycle := duration(settings)
	var phase := fposmod(seconds, cycle)
	var previous := 0.5
	for leg in settings.pattern:
		var target := float(leg.to)
		var travel := absf(target - previous) * float(settings.crossScreenSeconds)
		if travel > 0 and phase < travel:
			return Vector2(lerpf(settings.patrolLeftX, settings.patrolRightX, lerpf(previous, target, phase / travel)), signf(target - previous))
		phase -= travel
		var hold := float(leg.holdMs) / 1000.0
		if phase < hold:
			return Vector2(lerpf(settings.patrolLeftX, settings.patrolRightX, target), 0)
		phase -= hold
		previous = target
	return Vector2(lerpf(settings.patrolLeftX, settings.patrolRightX, 0.5), 1)
