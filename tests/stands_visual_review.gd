extends SceneTree
## Explicit local --script fixture only; no production startup or microphone bypass.
class SilentInput:
	extends "res://scripts/voice/voice_input.gd"
	func _init() -> void:status="active"
var level: Node
var review_ms := 1000

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var app: Node=root.get_node("App")
	app.open_stands()
	for i in 3:await process_frame
	level=current_scene
	level.set_process(false)
	level.voice_input.dispose()
	level.voice_input=SilentInput.new()
	level.now_source=func():return review_ms
	var mode:="intro"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stands-"):mode=arg.trim_prefix("--stands-")
	if mode=="intro":
		await create_timer(.7).timeout
	elif mode=="teams":
		level.overlays.popup.action_buttons[0].pressed.emit()
		await create_timer(.7).timeout
	else:
		level._select_team(0)
		level.overlays.dismiss(level._activate)
		await create_timer(.4).timeout
		if mode in ["level-2","level-3","game-win"]:
			level.level_index=2 if mode in ["level-3","game-win"] else 1
			level._new_round()
			level._activate()
		if mode in ["player","level-2","level-3"]:
			var turn: Dictionary=level.match_model.turns[0]
			review_ms+=int(ceil(turn.end*1000))+750
			level._process(.016)
			level.world.player.set_intensity(.9)
			level.hud.present(level.match_model,level.level_index+1)
		elif mode=="opponent":
			review_ms+=2200
			level._process(.016)
		elif mode in ["win","draw","loss","game-win"]:
			while not level.match_model.finished:
				var model: RefCounted=level.match_model
				var turn: Dictionary=model.turns[model.turn_index]
				if mode in ["win","game-win"] and model.player_turn():
					for i in int(model.difficulty.target_peaks):
						model.advance_to(float(turn.start)+.4+i*.4,1)
						model.register_peak(model.elapsed,model.turn_index)
				model.advance_to(turn.end,1 if mode in ["win","game-win"] else 0)
			if mode=="draw":
				level.match_model.score=50
				level.match_model.outcome=level.match_model.result_for_score(50)
			level._finish(review_ms)
	await create_timer(.7).timeout
	print("STANDS REVIEW READY: ",mode," score=",level.match_model.score," audio=",level.audio.playing)
