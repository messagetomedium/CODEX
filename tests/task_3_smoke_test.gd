extends SceneTree
## Scene integration: pause gates, projection, event latch and microphone recovery.
class TestInput:
	extends "res://scripts/voice/voice_input.gd"
	var rms := 0.0
	var now := 0
	var disposed := false
	func start() -> void:
		status = "active"
	func poll() -> Dictionary:
		now += 16
		return {"status": status, "errorCode": error_code, "rms": rms, "peak": rms, "timestamp": now}
	func dispose() -> void:
		disposed = true
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

func frames() -> void:
	for i in 3:
		await process_frame

func tick(level: Node, count: int) -> void:
	for i in count:
		level._process(0.016)

func _run() -> void:
	app = root.get_node("App")
	app.open_goal()
	await frames()
	var level: Node2D = current_scene
	level.set_process(false)
	level.voice_input.dispose()
	var source := TestInput.new()
	level.voice_input = source
	var world_id: int = level.world.get_instance_id()
	var ball_start: Vector2 = level.world.ball.position
	tick(level, 100)
	check(level.simulation.ball.progress == 0 and level.world.ball.position == ball_start, "Intro freezes the world and never consumes voice input")
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(0.016)
	check(level.state == level.State.TRANSITION and level.simulation.ball.progress == 0, "Intro exit gates simulation until its overlay closes")
	await create_timer(0.4).timeout
	check(level.state == level.State.ACTIVE, "Granted source activates the existing level")
	# Remove random encounters here; their pure scheduling is tested independently.
	level.spawner.wait_seconds = 10000
	tick(level, 15)
	check(level.simulation.ball.progress == 0 and level.simulation.keeper_x != 0.5, "Silence keeps the ball ready while the keeper patrols")
	source.rms = 0.04
	tick(level, 90)
	check(level.world.ball.position.y < ball_start.y and level.world.ball.scale.x < 1, "Voice rolling updates world position and perspective scale")
	check(level.world.ball.position.x == ball_start.x and level.world.goal.position.x == ball_start.x, "Ball and goal stay centered with a fixed camera")
	source.rms = 0
	tick(level, 40)
	var stopped: float = level.simulation.ball.progress
	tick(level, 40)
	check(level.simulation.ball.progress == stopped, "Real detector release stops the integrated ball")
	source.rms = 0.065
	tick(level, 10)
	check(level.simulation.ball.flying and level.world.ball.shadow_drop > 0, "Impulse raises the ball separately from its ground shadow")
	source.rms = 0
	tick(level, 60)
	check(not level.simulation.ball.flying and level.simulation.outcome.is_empty() and level.state == level.State.ACTIVE, "Short landing continues active play without a result")
	check(level.world.ball.shadow_drop == 0, "Ground shadow rejoins the landed ball")

	var progress: float = level.simulation.ball.progress
	var keeper: float = level.simulation.keeper_x
	var spawn_wait: float = level.spawner.wait_seconds
	source.status = "busy"
	level._process(0.016)
	tick(level, 100)
	check(level.state == level.State.MIC_ERROR and level.simulation.ball.progress == progress and level.simulation.keeper_x == keeper, "Microphone failure freezes ball and keeper under the error overlay")
	check(level.spawner.wait_seconds == spawn_wait, "Overlay pause freezes the defender scheduler too")
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(0.016)
	await frames()
	check(level.state == level.State.ACTIVE and level.world.get_instance_id() == world_id and level.simulation.ball.progress == progress, "Microphone retry resumes the same ball and world")

	level.simulation.settings = level.simulation.settings.duplicate(true)
	level.simulation.settings.goalkeeper.patrolLeftX = 0.37
	level.simulation.settings.goalkeeper.patrolRightX = 0.38
	level.simulation.keeper_x = 0.375
	level.simulation.ball.progress = 0.999
	source.rms = 0.04
	tick(level, 20)
	check(level.state == level.State.EVENT and level.simulation.outcome == "goal", "Crossing transitions the same level into a resolved state")
	check(is_instance_valid(level.event_notice) and level.round_progress.goals == 1, "Short event shows the scored outcome with an updated count")
	check(not is_instance_valid(level.overlays.popup), "Task 3 does not introduce the Task 4 result popup")
	var final_position: Vector2 = level.world.ball.position
	keeper = level.simulation.keeper_x
	source.rms = 0.12
	tick(level, 100)
	check(level.world.ball.position == final_position and level.simulation.keeper_x == keeper and level.voice_frame.kick_impulse_strength == 0, "Resolved play freezes the world and locks voice controls")
	check(level.hud.get_node("Attempts").text == app.texts.text("goal.hud.attempts", {"attemptsUsed": 1, "maxAttempts": 6}), "A rolling play plus short kick still consumes one attempt")
	source.status = "busy"
	level._process(0.016)
	level.overlays.popup.action_buttons[0].pressed.emit()
	level._process(0.016)
	await frames()
	check(level.state == level.State.EVENT and level.simulation.outcome == "goal", "Microphone recovery cannot revive a resolved ball")
	app.reset()
	await frames()
	check(current_scene.name == "MainMenu" and source.disposed, "Reset from a resolved play returns to menu and releases audio")
	print("Task 3 integration checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
