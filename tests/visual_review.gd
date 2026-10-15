extends SceneTree
## Browser-only review fixture launched explicitly with --script by a local test
## HTML response. Normal Pages startup never loads it or bypasses the microphone.
const Voice = preload("res://scripts/voice/voice_frame.gd")

class SilentInput:
	extends "res://scripts/voice/voice_input.gd"
	func _init() -> void:
		status = "active"

func _init() -> void:
	_run.call_deferred()

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
	var voice := Voice.new()
	var count := 3 if mode == "final-win" else 1
	for i in count:
		var settings: Dictionary = level.simulation.settings.duplicate(true)
		settings.goalkeeper.patrolLeftX = 0.495 if mode == "catch" else 0.37
		settings.goalkeeper.patrolRightX = 0.505 if mode == "catch" else 0.38
		level.simulation.settings = settings
		level.simulation.keeper_x = 0.5 if mode == "catch" else 0.375
		voice.kick_impulse_strength = 0.98 if mode == "catch" else 0.92
		level.simulation.step(2, voice)
		level._process(0.016)
		if mode == "final-win":
			level._finish_event()
	print("VISUAL REVIEW READY: ", mode)
