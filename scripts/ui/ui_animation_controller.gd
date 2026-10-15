extends RefCounted
## Each Control owns its Tween: freeing a screen also cancels its animations.

var profiles: Dictionary

func _init(source: Dictionary) -> void:
	profiles = source

func play(node: Control, profile_id: String, phase: String = "enter", reverse: bool = false, index: int = 0) -> Tween:
	if not profiles.has(profile_id) or not profiles[profile_id].has(phase):
		push_error("Missing animation: " + profile_id + "." + phase)
		return null
	var spec: Dictionary = profiles[profile_id][phase]
	if node.has_meta("ui_tween"):
		var previous: Tween = node.get_meta("ui_tween")
		if previous and previous.is_valid():
			# Hover must not freeze a partially transparent entrance.
			if phase == "hover" and node.get_meta("ui_phase", "") == "enter":
				_apply(node, node.get_meta("ui_enter_end", {}))
			previous.kill()
	node.set_meta("ui_phase", phase)
	if phase == "enter":
		node.set_meta("ui_enter_end", spec.get("to", {}))
	if not node.has_meta("ui_base_y"):
		node.set_meta("ui_base_y", node.position.y)
	node.pivot_offset = node.size * 0.5
	var start: Dictionary = spec.get("from", {})
	var finish: Dictionary = spec.get("to", {})
	if reverse:
		finish = start
	else:
		_apply(node, start)
	var duration := float(spec.get("durationMs", 0)) / 1000.0
	if duration <= 0.0:
		_apply(node, finish)
		return null
	var tween := node.create_tween().set_parallel(true)
	node.set_meta("ui_tween", tween)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(_ease(spec.get("easing", "ease-out")))
	var delay := (float(spec.get("delayMs", 0)) + index * float(spec.get("staggerMs", 0))) / 1000.0
	for property in _properties(node, finish):
		tween.tween_property(node, property, _properties(node, finish)[property], duration).set_delay(delay)
	return tween

func _ease(value: String) -> Tween.EaseType:
	return {"ease-in": Tween.EASE_IN, "ease-out": Tween.EASE_OUT, "ease-in-out": Tween.EASE_IN_OUT}.get(value, Tween.EASE_OUT)

func _properties(node: Control, state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if state.has("opacity"):
		result["modulate:a"] = float(state.opacity)
	if state.has("scale") or state.has("scaleX") or state.has("scaleY"):
		result["scale"] = Vector2(float(state.get("scaleX", state.get("scale", 1))), float(state.get("scaleY", state.get("scale", 1))))
	if state.has("yPx"):
		result["position:y"] = float(node.get_meta("ui_base_y")) + float(state.yPx)
	return result

func _apply(node: Control, state: Dictionary) -> void:
	var properties := _properties(node, state)
	for property in properties:
		node.set_indexed(NodePath(property), properties[property])
