extends RefCounted
## Compact events avoid current world/HUD bounds. Central results deliberately overlap.

static func choose(size: Vector2, candidates: Array, protected: Array[Rect2], canvas: Vector2, settings: Dictionary) -> Rect2:
	var padding := float(settings.paddingPixels)
	var bounds := Rect2(Vector2.ONE * padding, canvas - Vector2.ONE * padding * 2)
	for factor in settings.shrinkScales:
		for candidate in candidates:
			var rect := Rect2(canvas * Vector2(candidate.x, candidate.y) - size * factor / 2, size * factor)
			if fits(rect, protected, bounds, padding):
				return rect
	# A dense fallback is still checked, never forced over an entity.
	var small: Vector2 = size * settings.shrinkScales.back()
	var step: float = settings.fallbackScanStep
	var y := step
	while y < 1:
		var x := step
		while x < 1:
			var rect := Rect2(canvas * Vector2(x, y) - small / 2, small)
			if fits(rect, protected, bounds, padding):
				return rect
			x += step
		y += step
	return Rect2()

static func fits(rect: Rect2, protected: Array[Rect2], bounds: Rect2, padding: float) -> bool:
	if not bounds.encloses(rect):
		return false
	for object in protected:
		if rect.intersects(object.grow(padding)):
			return false
	return true
