extends SceneTree
class TestInput:
	extends "res://scripts/voice/voice_input.gd"
	var requests := 0
	var disposed := false
	var rms := 0.0
	var now := 0
	func start() -> void:
		requests += 1
		status = "active"
	func poll() -> Dictionary:
		now += 16
		return {"status": status, "errorCode": error_code, "rms": rms, "peak": rms, "timestamp": now}
	func dispose() -> void:
		disposed = true
		super.dispose()

var app: Node
var checks := 0
var failures := 0
var intro_size := Vector2.ZERO

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in 3:
		await process_frame

func make_level() -> Node2D:
	app.open_goal()
	await frames()
	var level: Node2D = current_scene
	level.set_process(false)
	level.voice_input.dispose()
	level.voice_input = TestInput.new()
	intro_size = level.overlays.popup.size
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(0.016)
	level.spawner.wait_seconds = 10000
	return level

func resolve(level: Node, outcome: String) -> void:
	level.simulation.ball.has_moved = true
	level.simulation.ball.progress = 1 if outcome != "intercept" else 0.4
	level.simulation.outcome = outcome
	level.simulation.keeper_raised = outcome == "caught"
	if outcome == "caught":
		level.simulation.ball.flying = true
		level.simulation.ball.flight_fraction = 0.5
		level.simulation.ball.flight_arc = 160
	level._process(0.016)

func finish_event(level: Node) -> void:
	level._process(float(app.config.data.gameplay.eventFeedback.durationMs) / 1000.0 + 0.01)

func _run() -> void:
	app = root.get_node("App")
	for id in ["intro.panel", "final.panel", "microphoneError.panel"]:
		for phase in ["enter", "exit"]:
			if app.config.data.ui_animations.profiles[id].has(phase):
				app.config.data.ui_animations.profiles[id][phase].durationMs = 0
	var level := await make_level()
	var world_id: int = level.world.get_instance_id()
	check(level.state == level.State.ACTIVE and level.round_progress.attempts_used == 0, "Start alone costs no attempt")
	resolve(level, "frame")
	check(level.state == level.State.EVENT and level.round_progress.attempts_used == 1 and level.round_progress.goals == 0, "Frame contact charges and resolves one failed play")
	var title_found := false
	for node in level.event_notice.get_children():
		if node is Label and node.text == app.texts.text("goal.event.frame.title"):
			title_found = true
	check(title_found, "Frame event says frame contact rather than goalkeeper save")
	var protected: Array[Rect2] = level._protected_rects()
	var target := Rect2(Vector2(level.event_notice.position.x, level.event_notice.get_meta("ui_base_y")), level.event_notice.size)
	var safe := true
	for rect in protected:
		safe = safe and not target.intersects(rect.grow(16))
	check(safe, "Compact event avoids the current goal, players, ball, HUD and Reset")
	var ball_position: Vector2 = level.world.ball.position
	var keeper_position: Vector2 = level.world.keeper.position
	var gap: float = level.spawner.wait_seconds
	level.voice_input.rms = 0.12
	level._process(0.2)
	check(level.world.ball.position == ball_position and level.world.keeper.position == keeper_position and level.spawner.wait_seconds == gap and level.voice_frame.kick_impulse_strength == 0, "Feedback pauses mechanics, spawning and voice controls")
	level.voice_input.status = "busy"
	level._process(0.016)
	var time_left: float = level.event_time_left
	level._process(100)
	check(level.state == level.State.MIC_ERROR and level.event_time_left == time_left, "Microphone error pauses the feedback timer too")
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(0.016)
	check(level.state == level.State.EVENT and level.round_progress.attempts_used == 1 and level.event_time_left < time_left, "Reconnect resumes the same feedback without charging twice")
	finish_event(level)
	check(level.state == level.State.ACTIVE and level.simulation.ball.progress == 0 and level.world.get_instance_id() == world_id, "Feedback automatically prepares the next ball in the same level")
	for i in 40:
		level._process(0.016)
	check(level.round_progress.attempts_used == 1 and not level.simulation.ball.has_moved, "Held loud input from an overlay does not cause a hidden new kick")
	level.voice_input.rms = 0
	for i in 30:
		level._process(0.016)
	resolve(level, "caught")
	ball_position = level.world.ball.position
	check(level.world.keeper.raise_amount == 0, "Raised-hands reaction starts at the standing pose")
	await create_timer(0.15).timeout
	check(is_equal_approx(level.world.keeper.raise_amount, 1) and level.world.ball.position == ball_position, "Hands rapidly reach the caught ball while mechanics stay frozen")
	finish_event(level)
	check(level.world.keeper.raise_amount == 0 and level.round_progress.attempts_used == 2, "Next ball resets the catch pose without losing statistics")
	resolve(level, "goal")
	check(level.round_progress.goals == 1 and level.world.goal.net_scale != Vector2.ONE, "A real goal updates HUD and starts a net deformation")
	await create_timer(0.4).timeout
	check(level.world.goal.net_scale.is_equal_approx(Vector2.ONE), "Goal frame stays fixed while the net settles back")
	app.reset()
	await frames()
	check(current_scene.name == "MainMenu", "Reset remains available during event feedback")

	for goals in 4:
		level = await make_level()
		var limit := 3 if goals == 3 else 6
		for i in limit:
			level.simulation.ball.has_moved = true
			level._process(0)
			check(level.state == level.State.ACTIVE and not level.round_progress.finished, "Even the final moving ball waits for its outcome")
			resolve(level, "goal" if i < goals else "saved")
			check(level.state == level.State.EVENT and not is_instance_valid(level.overlays.popup), "Single-ball feedback remains compact, including the last ball")
			finish_event(level)
			if i < limit - 1:
				check(level.state == level.State.ACTIVE and level.round_progress.attempts_used == i + 1, "Next ball waits for first movement before charging")
		check(level.state == level.State.FINAL and level.round_progress.goals == goals, "The correct 0/1/2/3 tier opens the round final")
		var popup: Control = level.overlays.popup
		check(popup.size.is_equal_approx(intro_size) and popup.get_global_rect().get_center().is_equal_approx(app.design_size / 2), "Final matches instruction size and covers the central zone")
		check(popup.action_buttons.size() == 3 and popup.action_buttons[2].disabled == (goals < 3) and popup.action_buttons[2].pressed.get_connections().size() == (0 if goals < 3 else 1), "Round result unlocks Next only after a win")
		var phrases: Array = app.config.data["ui.ru"].goal.results.tiers[str(goals)].phrases
		if goals == 3:
			phrases = [app.texts.text("goal.results.roundWinTitle", level.round_progress.values())]
		var matching := false
		for node in popup.get_children():
			if node is Label and node.text in phrases:
				matching = true
		check(matching, "Final headline is drawn from the matching score tier")
		var rows := popup.get_node("Statistics").get_children()
		check(rows[0].text == app.texts.text("goal.results.goals", level.round_progress.values()) and rows[1].text == app.texts.text("goal.results.attempts", level.round_progress.values()), "Final statistics show true goals and used attempts")
		level.voice_input.rms = 0.12
		level._process(500)
		check(level.state == level.State.FINAL and level.round_progress.attempts_used == limit, "Final has no silence timeout or extra attempts")
		world_id = level.world.get_instance_id()
		var requests: int = level.voice_input.requests
		popup.action_buttons[0].pressed.emit()
		check(level.state == level.State.ACTIVE and level.round_progress.attempts_used == 0 and level.round_progress.goals == 0 and level.world.get_instance_id() == world_id, "Retry resets the round in place without an intro")
		check(level.voice_input.requests == requests and not is_instance_valid(level.overlays.popup), "Retry reuses an available microphone without another permission request")

	# A final remains actionable after device loss; Retry starts audio in the click.
	level = await make_level()
	for i in 3:
		resolve(level, "goal")
		finish_event(level)
	level.voice_input.status = "busy"
	level._process(0.016)
	check(level.state == level.State.FINAL, "Device loss never replaces an already-open final")
	level.overlays.popup.action_buttons[0].pressed.emit()
	check(level.voice_input.requests == 2 and level.state == level.State.MIC_REQUEST and level.overlays.popup.instruction_items.is_empty(), "Retry after device loss synchronously reconnects without repeating rules")
	level._process(0.016)
	check(level.state == level.State.ACTIVE and level.round_progress.goals == 0, "Reconnected retry starts a fresh round")
	for i in 3:
		resolve(level, "goal")
		finish_event(level)
	level.overlays.popup.action_buttons[1].pressed.emit()
	await frames()
	check(current_scene.name == "MainMenu", "Final Menu action returns to the menu")
	# Shared result template has an intermediate variant, unused by normal play.
	level = await make_level()
	level.overlays.show_info({"kind": "intermediate", "layoutId": "result", "animationProfile": "final.panel", "title": app.texts.text("goal.intermediateResult.title", {"round": 1}), "statistics": [app.texts.text("goal.intermediateResult.goals", {"goals": 1, "goalTarget": 3})], "actions": []}, "final")
	check(level.overlays.popup.has_node("Statistics") and level.overlays.popup.instruction_items.is_empty(), "Common popup can render an intermediate result without another screen")
	app.reset()
	await frames()
	print("Task 4 integration checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
