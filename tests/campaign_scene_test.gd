extends SceneTree
class TestInput:
	extends "res://scripts/voice/voice_input.gd"
	var requests := 0
	var pending := false
	var disposed := false
	func start() -> void:
		requests += 1
		status = "pending" if pending else "active"
	func dispose() -> void:
		disposed = true
		super.dispose()

var app: Node
var checks := 0
var failures := 0

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

func resolve(level: Node, outcome: String) -> void:
	level.simulation.ball.has_moved = true
	level.simulation.ball.progress = 1
	level.simulation.outcome = outcome
	level._process(0.016)
	level._process(float(app.config.data.gameplay.eventFeedback.durationMs) / 1000.0 + 0.01)

func win(level: Node) -> void:
	for i in 3:
		resolve(level, "goal")

func title_is(level: Node, text: String) -> bool:
	for child in level.overlays.popup.get_children():
		if child is Label and child.text == text:
			return true
	return false

func _run() -> void:
	app = root.get_node("App")
	for profile in ["intro.panel", "final.panel", "microphoneError.panel"]:
		for phase in ["enter", "exit"]:
			if app.config.data.ui_animations.profiles[profile].has(phase):
				app.config.data.ui_animations.profiles[profile][phase].durationMs = 0
	app.open_goal()
	await frames()
	var level: Node2D = current_scene
	level.set_process(false)
	level.voice_input.dispose()
	var source := TestInput.new()
	level.voice_input = source
	var world_id: int = level.world.get_instance_id()
	var detector_id: int = level.detector.get_instance_id()
	var guide: Control = level.hud.get_node("VoiceGuide")
	check(guide.thresholds == [0.14, 0.52, 0.56] and guide.size.x == level.meter.size.x, "Guide ticks match the real quiet range and attack threshold")
	check(guide.get_child_count() == 2 and guide.get_child(0).text == app.texts.text("goal.hud.quietRange") and guide.get_child(1).text == app.texts.text("goal.hud.kickRange"), "Meter has localized rolling and sharp-kick legends")
	check(level.world.goal.dimensions.x > 1920 * 0.28 and level.world.goal.dimensions.y > 1080 * 0.205, "Goal is visibly larger in both dimensions")
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(0.016)
	check(level.state == level.State.ACTIVE and source.requests == 1, "Campaign starts from one microphone request")
	check(level.round_config.defender.crossScreenSeconds == 4.4 and level.round_config.goalkeeper.crossScreenSeconds == 4.4, "Round one starts with slower players")
	win(level)
	check(level.state == level.State.FINAL and level.campaign.number == 1 and level.campaign.can_advance(), "Round one victory offers an intermediate result")
	check(title_is(level, app.texts.text("goal.results.roundWinTitle", {"round":1})) and not level.overlays.popup.action_buttons[2].disabled, "Intermediate result identifies the completed round and enables Next")
	level.overlays.popup.action_buttons[2].pressed.emit()
	check(level.campaign.number == 2 and level.state == level.State.ACTIVE and level.round_progress.goals == 0 and level.round_progress.attempts_used == 0, "Next starts round two with fresh per-round counters")
	check(level.world.get_instance_id() == world_id and level.detector.get_instance_id() == detector_id and source.requests == 1, "Next reuses the same world, accepted detector and microphone")
	check(level.hud.get_node("Round").text == app.texts.text("goal.hud.round", {"round":2}) and not is_instance_valid(level.overlays.popup), "Round HUD updates without showing intro again")
	level.spawner.step(0.016, level.simulation)
	level.simulation.step(1, level.voice_frame)
	level.world.present(level.simulation)
	check(level.world.defenders.size() == 2 and level.simulation.defenders[0].active and level.simulation.defenders[1].active, "Round two renders both simultaneous defenders")
	check(level.simulation.defenders[0].direction != level.simulation.defenders[1].direction and level.simulation.defenders[0].y != level.simulation.defenders[1].y, "Two defenders meet on different depth lanes")
	var front := true
	for sprite in level.world.defenders:
		front = front and sprite.position.y > level.world.goal.position.y and sprite.z_index > level.world.goal.z_index
	check(front, "Every active defender draws in front of the goal rather than behind the net")
	for i in 6:
		resolve(level, "saved")
	check(level.state == level.State.FINAL and level.campaign.number == 2 and level.overlays.popup.action_buttons[2].disabled, "Failed round two cannot skip to round three")
	var frozen: Array = level.simulation.defenders.duplicate(true)
	var clock: float = level.simulation.keeper_time
	level._process(40)
	check(level.simulation.defenders == frozen and level.simulation.keeper_time == clock, "Round result freezes all defenders and the keeper pattern")
	level._on_action("next")
	check(level.campaign.number == 2 and level.round_progress.attempts_used == 6, "A disabled transition is also rejected by the controller")
	level.overlays.popup.action_buttons[0].pressed.emit()
	check(level.campaign.number == 2 and level.campaign.results.size() == 1 and level.round_progress.attempts_used == 0, "Retry keeps the earlier victory and retries only the failed round")
	win(level)
	level.overlays.popup.action_buttons[2].pressed.emit()
	check(level.campaign.number == 3 and level.round_config.defender.crossScreenSeconds == 2.6 and level.simulation.defenders.size() == 3, "Round three uses three slots and the former hardest defender speed")
	level.spawner.step(0.016, level.simulation)
	level.simulation.step(1, level.voice_frame)
	level.world.present(level.simulation)
	check(level.world.defenders.size() == 3 and level.world.defenders[2].visible, "Third defender has its own visible entity")
	front = true
	for sprite in level.world.defenders:
		front = front and sprite.z_index > level.world.goal.z_index
	check(front, "No round-three sprite can be behind the goal")
	win(level)
	check(level.state == level.State.FINAL and level.campaign.game_won() and title_is(level, app.texts.text("goal.results.gameWinTitle")), "Third victory opens the game-completion window")
	check(level.overlays.popup.action_buttons.size() == 2 and level.overlays.popup.action_buttons[0].text == app.texts.text("common.actions.restartGame"), "Completion offers Play from start and Menu without a fourth round")
	var totals: Dictionary = level.campaign.totals(app.config.data.gameplay)
	var rows: Array = level.overlays.popup.get_node("Statistics").get_children()
	check(rows[0].text == app.texts.text("goal.results.totalGoals", totals) and totals.goals == 9, "Game completion combines all three successful rounds")
	level.overlays.popup.action_buttons[0].pressed.emit()
	check(level.campaign.number == 1 and level.campaign.results.is_empty() and level.world.defenders.size() == 1 and source.requests == 1, "Play from start clears all progress, removes extra defenders and reuses audio")
	win(level)
	source.status = "busy"
	source.pending = true
	level.overlays.popup.action_buttons[2].pressed.emit()
	check(level.campaign.number == 2 and level.state == level.State.MIC_REQUEST and source.requests == 2, "Next after device loss reconnects synchronously from its button")
	check(level.overlays.popup.instruction_items.is_empty(), "Reconnecting on the next round never repeats the rules")
	level._process(10)
	check(level.round_progress.attempts_used == 0 and level.simulation.keeper_time == 0, "Pending permission cannot move the new round")
	source.status = "active"
	level._process(0.016)
	source.status = "busy"
	level._process(0.016)
	frozen = level.simulation.defenders.duplicate(true)
	clock = level.simulation.keeper_time
	var waits: Array = level.spawner.wait_timers.duplicate()
	level._process(50)
	check(level.state == level.State.MIC_ERROR and level.simulation.defenders == frozen and level.simulation.keeper_time == clock and level.spawner.wait_timers == waits, "Microphone errors freeze every slot, clock and respawn timer")
	source.pending = false
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(0.016)
	check(level.state == level.State.ACTIVE and level.campaign.number == 2 and source.requests == 3, "Reconnect resumes the selected difficulty")
	win(level)
	app.config.data.ui_animations.profiles["final.panel"].exit.durationMs = 180
	level.overlays.popup.action_buttons[2].pressed.emit()
	check(level.state == level.State.TRANSITION and level.campaign.number == 3, "Next transition gates voice while the result closes")
	app.reset()
	await frames()
	await create_timer(0.25).timeout
	check(current_scene.name == "MainMenu" and source.disposed, "Reset during a round transition cancels the callback and releases all audio")
	print("Campaign scene checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
