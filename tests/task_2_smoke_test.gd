extends SceneTree

class TestInput:
	extends "res://scripts/voice/voice_input.gd"
	var requests := 0
	var was_disposed := false
	var measured_rms := 0.0
	func start() -> void:
		requests += 1
		status = "pending"
		error_code = ""
	func poll() -> Dictionary:
		var raw := super.poll()
		raw.rms = measured_rms
		raw.peak = measured_rms
		return raw
	func dispose() -> void:
		was_disposed = true
		super.dispose()

var checks := 0
var failures := 0
var app: Node

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for i in count:
		await process_frame

func make_level() -> Node2D:
	app.open_goal()
	await frames()
	var level: Node2D = current_scene
	level.voice_input.dispose()
	level.voice_input = TestInput.new()
	return level

func _run() -> void:
	app = root.get_node("App")
	var level := await make_level()
	var source: RefCounted = level.voice_input
	var world_id: int = level.world.get_instance_id()
	var ball_position: Vector2 = level.world.ball.position
	check(source.requests == 0, "Entering intro never requests audio")
	level.overlays.popup.action_buttons[0].pressed.emit()
	await frames()
	check(source.requests == 1 and level.state == level.State.MIC_REQUEST, "Start begins one asynchronous permission request")
	check(level.overlays.popup.instruction_items.size() == 3, "Permission waits in the same instruction panel")
	check(level.overlays.popup.action_buttons.is_empty(), "Pending request cannot be double-submitted")
	source.status = "active"
	source.measured_rms = 0.04
	await create_timer(0.5).timeout
	check(level.state == level.State.ACTIVE and not is_instance_valid(level.overlays.popup), "Granted audio closes intro without a new screen")
	check(level.status_banner.visible and level.meter.value > 0, "Active microphone displays measured loudness")
	check(level.voice_frame.rolling_intensity > 0, "Source-independent VoiceFrame is available for the future gameplay stage")
	check(level.world.get_instance_id() == world_id and level.world.ball.position == ball_position, "Task 2 preserves the existing static field")
	check(level.hud.get_node("Attempts").text == app.texts.text("goal.hud.attempts", {"attemptsUsed": 0, "maxAttempts": 6}), "Microphone measurement consumes no attempts")
	source.status = "denied"
	source.error_code = "NotAllowedError"
	await frames()
	check(level.state == level.State.MIC_ERROR, "Permission denial opens a reusable error overlay")
	check(not level.status_banner.visible and level.voice_frame.kick_impulse_strength == 0, "Error gates control and hides active status")
	check(level.overlays.popup.action_buttons[0].text == app.texts.text("common.actions.micRetry"), "Error offers a localized retry")
	var found := false
	for node in level.overlays.popup.get_children():
		if node is Label and node.text == app.texts.text("common.microphone.permissionDenied"):
			found = true
	check(found, "Denied message explains browser site settings")
	level.overlays.popup.action_buttons[0].pressed.emit()
	await frames()
	check(source.requests == 2 and level.state == level.State.MIC_REQUEST, "Retry uses the same source and level")
	check(level.overlays.popup.instruction_items.is_empty(), "Microphone retry does not repeat intro instructions")
	source.status = "active"
	await frames(2)
	check(level.state == level.State.ACTIVE, "Error-profile retry closes in place without an unrelated animation profile")
	source.status = "busy"
	await create_timer(0.4).timeout
	check(level.state == level.State.MIC_ERROR and is_instance_valid(level.overlays.popup), "Device failure after retry reuses the error overlay")
	app.reset()
	await frames()
	check(source.was_disposed and current_scene.name == "MainMenu", "Reset releases an error session")
	level = await make_level()
	source = level.voice_input
	level.overlays.popup.action_buttons[0].pressed.emit()
	app.reset()
	await frames()
	check(source.was_disposed and source.requests == 1 and current_scene.name == "MainMenu", "Reset disposes a still-pending request")
	level = await make_level()
	source = level.voice_input
	level.overlays.popup.action_buttons[0].pressed.emit()
	source.status = "active"
	await frames(2)
	check(level.state == level.State.TRANSITION, "First grant uses the intro exit profile")
	source.status = "busy"
	await create_timer(0.4).timeout
	check(level.state == level.State.MIC_ERROR and is_instance_valid(level.overlays.popup) and not level.status_banner.visible, "Failure during intro exit cancels stale activation")
	level.overlays.popup.action_buttons[0].pressed.emit()
	source.status = "active"
	await create_timer(0.4).timeout
	app.reset()
	await frames()
	check(source.was_disposed and current_scene.name == "MainMenu", "Reset releases an active microphone session")
	print("Task 2 integration checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
