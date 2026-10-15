extends SceneTree
## Explicit local --script fixture; ordinary Pages startup never selects it.
const Voice = preload("res://scripts/voice/voice_frame.gd")
class SilentInput:
	extends "res://scripts/voice/voice_input.gd"
	func _init() -> void:
		status = "active"

func _init() -> void:
	_run.call_deferred()

func win_round(level: Node) -> void:
	for i in 3:
		var settings: Dictionary = level.simulation.settings.duplicate(true)
		settings.goalkeeper.patrolLeftX = 0.37
		settings.goalkeeper.patrolRightX = 0.38
		settings.goalkeeper.pattern = []
		level.simulation.settings = settings
		level.simulation.keeper_x = 0.375
		var voice := Voice.new()
		voice.kick_impulse_strength = 0.92
		level.simulation.step(2, voice)
		level._process(0.016)
		level._finish_event()

func _run() -> void:
	var app: Node = root.get_node("App")
	app.open_goal()
	for i in 3:
		await process_frame
	var level: Node2D = current_scene
	level.set_process(false)
	level.voice_input.dispose()
	level.voice_input = SilentInput.new()
	level.overlays.dismiss(level._activate_input)
	await create_timer(0.4).timeout
	var mode := "catch"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-"):
			mode = argument.trim_prefix("--review-")
	if mode in ["final-win", "game-win", "round-2", "round-3"]:
		var rounds := 3 if mode == "game-win" else (2 if mode == "round-3" else 1)
		for i in rounds:
			win_round(level)
			if mode in ["round-2", "round-3"] or (mode == "game-win" and i < 2):
				level.overlays.popup.action_buttons[2].pressed.emit()
				await create_timer(0.3).timeout
		if mode in ["round-2", "round-3"]:
			level.spawner.rng.seed = 452
			level.spawner.step(0.016, level.simulation)
			level.simulation.step(1, Voice.new())
			level.world.present(level.simulation)
	else:
		var settings: Dictionary = level.simulation.settings.duplicate(true)
		settings.goalkeeper.patrolLeftX = 0.495 if mode == "catch" else 0.37
		settings.goalkeeper.patrolRightX = 0.505 if mode == "catch" else 0.38
		level.simulation.settings = settings
		level.simulation.keeper_x = 0.5 if mode == "catch" else 0.375
		if mode == "frame":
			level.simulation.ball.progress = 0.5
		var voice := Voice.new()
		voice.kick_impulse_strength = 0.98 if mode == "catch" else (1.0 if mode == "frame" else 0.92)
		level.simulation.step(2, voice)
		level._process(0.016)
	print("VISUAL REVIEW READY: ", mode)
