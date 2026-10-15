extends SceneTree
## Explicit local fixture only; not selected by exported production HTML.
class SilentInput:
	extends "res://scripts/voice/voice_input.gd"
	func _init() -> void:status="active"
var now_ms:=1000

func _init() -> void:_run.call_deferred()
func _run() -> void:
	var app: Node=root.get_node("App")
	app.open_commentator()
	for i in 3:await process_frame
	var level: Node=current_scene
	level.set_process(false)
	level.voice_input.dispose()
	level.voice_input=SilentInput.new()
	level.now_source=func():return now_ms
	var mode:="intro"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commentator-"):mode=arg.trim_prefix("--commentator-")
	if mode!="intro":
		level.overlays.dismiss(level._activate)
		await create_timer(.4).timeout
		if mode in ["level-2","level-3","final"]:
			level.level_index=1 if mode=="level-2" else 2
			level._new_round()
			level._activate()
		if mode in ["result","loss","final"]:
			if mode=="final":
				for i in 2:level.results[level.levels[i].id]={"words_hit":level.levels[i].turns.filter(func(t):return t.speaker=="player").size()*(6+2*i),"words_total":36+12*i,"avg_word_score":94.0,"interest_end":100.0,"passed":true}
			for step in range(1,3001):
				var seconds:=step*.02
				var index: int=level.session.timeline.active_word(seconds)
				var voice:=0.0
				if mode!="loss" and index>=0:
					var word: Dictionary=level.session.timeline.words[index]
					var phase: float=(seconds-word.start_sec)/(word.end_sec-word.start_sec)
					voice=(.72 if word.emphasis else .40) if phase>.04 and phase<.80 else .14
				level.session.advance_to(seconds,voice)
			level._finish(now_ms)
		else:
			now_ms+=3800 if mode=="host" else 7000
			level._process(.02)
			level.hud.present(level.session,level.level_index+1,level.levels.size())
	await create_timer(.7).timeout
	print("COMMENTATOR REVIEW READY: ",mode)
