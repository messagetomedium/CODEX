extends SceneTree
const Session=preload("res://scripts/commentator/logic/commentator_session.gd")
const Scorer=preload("res://scripts/commentator/logic/commentator_word_scorer.gd")
var checks:=0
var failures:=0
var config: Dictionary
var levels: Array

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func trace(model: RefCounted, mode: String) -> void:
	for step in range(1,3001):
		var seconds:=step*.02
		var index: int=model.timeline.active_word(seconds)
		var voice_level:=0.0
		if mode=="host":voice_level=1.0 if model.timeline.turns[model.timeline.turn_at(seconds)].speaker=="host" else 0.0
		elif mode=="held":voice_level=.35
		elif index>=0:
			var word: Dictionary=model.timeline.words[index]
			var phase: float=(seconds-word.start_sec)/(word.end_sec-word.start_sec)
			if mode=="ideal":voice_level=(.72 if word.emphasis else .40) if phase>.04 and phase<.80 else .14
			elif mode=="spike":voice_level=1.0 if index==0 and phase<.03 else 0.0
		model.advance_to(seconds,voice_level)

func score_word(emphasis: bool, volume: float, baseline: float, offset: float=0, coverage: float=1) -> Dictionary:
	var scorer:=Scorer.new({"start_sec":1.0,"end_sec":2.0,"emphasis":emphasis},config.scoring,config.levels.level_1)
	scorer.integrate(1,1+coverage,volume,baseline)
	scorer.onset(1+offset)
	return scorer.finish()

func _init() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/config/commentator_gameplay.json"))
	levels=JSON.parse_string(FileAccess.get_file_as_string("res://data/config/commentator_levels.json")).levels
	for data in levels:
		var model:=Session.new(data,config)
		check(model.timeline.turns.size()==12 and model.timeline.words.size()==[36,48,60][int(data.number)-1],"Every level has six host/player pairs and its own complete word schedule")
		var active: int=model.timeline.active_word(5.21)
		check(active==0 and model.timeline.active_word(6.1)>active,"Highlight advances by author times without any voice")
		trace(model,"silent")
		check(model.finished and model.elapsed==60 and model.result.avg_word_score==0 and not model.result.passed,"Silence completes the full level honestly with no successful words")
		check(model.result.words_total==model.timeline.words.size() and model.result.words_hit==0,"Every word is finalized once, even when missed")
		var frozen: Dictionary=model.result.duplicate(true)
		model.advance_to(999,1)
		check(model.finish_count==1 and model.result==frozen,"Results latch once and cannot be altered by later input")
		model=Session.new(data,config)
		trace(model,"ideal")
		print("Commentator ideal level ",data.number,": ",model.result)
		check(model.result.passed and model.result.avg_word_score>85 and model.result.words_hit>=model.result.words_total*.85,"Rhythmic continuous speech with emphasis can comfortably pass every level")
		check(model.interest>config.interest.initial,"Successful words raise interest")
		var repeat:=Session.new(data,config)
		trace(repeat,"ideal")
		check(repeat.result==model.result,"Identical virtual input yields identical final results")
		model=Session.new(data,config)
		trace(model,"held")
		check(model.result.avg_word_score<50 and not model.result.passed,"Monotone continuous humming cannot pass by merely keeping a loud voice_level")
		model=Session.new(data,config)
		trace(model,"host")
		check(model.result.avg_word_score==0 and model.result.words_hit==0,"Loud host audio cannot score player words")
		model=Session.new(data,config)
		trace(model,"spike")
		check(model.result.words_hit==0 and model.result.avg_word_score<2,"One aggressive spike cannot earn full credit for the phrase")
		model=Session.new(data,config)
		model.advance_to(60,1)
		check(not model.result.passed and model.result.words_hit==0,"A stalled frame cannot project a single microphone sample across missed words")
	var strong:=score_word(true,.60,.35)
	var weak:=score_word(true,.35,.35)
	check(strong.score>95 and weak.score<=58 and strong.score>weak.score,"An emphasized word needs a boost above the player's voice baseline")
	check(is_equal_approx(score_word(true,.30,.20).score,score_word(true,.75,.50).score),"Relative emphasis gives quiet and loud speakers the same opportunity")
	check(score_word(false,.35,.35).score>score_word(false,.35,.35,.60).score,"Late entry loses timing credit")
	check(score_word(false,.35,.35,-.5).timing_status=="early" and score_word(false,.35,.35,.5).timing_status=="late" and score_word(false,.35,.35).timing_status=="on_time","Early/on-time/late remain internal assessment states")
	check(score_word(false,1,.35,0,.05).score<=25,"Very weak coverage caps even a powerful transient")
	var scorer:=Scorer.new({"start_sec":1.0,"end_sec":2.0,"emphasis":false},config.scoring,config.levels.level_1)
	scorer.integrate(1,2,.35,.35)
	var first: Dictionary=scorer.finish().duplicate()
	scorer.onset(1)
	check(scorer.finish()==first,"A finalized word cannot be scored twice")
	print("Commentator mechanics checks: ",checks,"; passed: ",checks-failures,"; failed: ",failures)
	quit(0 if failures==0 else 1)
