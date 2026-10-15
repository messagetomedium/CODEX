extends RefCounted
const Timeline=preload("res://scripts/commentator/logic/commentator_timeline.gd")
const Scorer=preload("res://scripts/commentator/logic/commentator_word_scorer.gd")
var timeline: RefCounted
var config: Dictionary
var profile: Dictionary
var scorers: Array[RefCounted]=[]
var elapsed:=0.0
var interest:=50.0
var baseline:=0.35
var finished:=false
var finish_count:=0
var result: Dictionary={}
var last_turn:=-1
var armed:=true
var trough:=0.0
var crest:=0.0
var last_onset:=-1000.0

func _init(level: Dictionary, settings: Dictionary) -> void:
	config=settings
	profile=settings.levels[level.id]
	timeline=Timeline.new(level)
	baseline=config.scoring.baseline_initial
	interest=config.interest.initial
	for word in timeline.words:scorers.append(Scorer.new(word,config.scoring,profile))

func reset_input() -> void:
	armed=true
	trough=0
	crest=0

func advance_to(seconds: float, loudness: float=0, envelope: float=-1, input_turn: int=-1) -> void:
	if finished:return
	var target:=clampf(seconds,elapsed,timeline.level.duration_sec)
	var from:=maxf(elapsed,target-config.scoring.max_sample_hold_sec)
	var turn: int=timeline.turn_at(target)
	if input_turn<0:input_turn=turn
	var is_player: bool=timeline.turns[input_turn].speaker=="player"
	if last_turn!=input_turn:
		reset_input()
		last_turn=input_turn
	var level:=clampf(loudness,0,1) if is_finite(loudness) else 0.0
	if is_player:
		for scorer in scorers:
			if scorer.word.turn_index==input_turn:
				scorer.integrate(from,target,level,baseline)
		var active: int=timeline.active_word(target)
		if active>=0 and not timeline.words[active].emphasis and level>=config.scoring.voice_threshold:
			var blend:=1-exp(-(target-from)/config.scoring.baseline_smoothing_sec)
			baseline=clampf(lerpf(baseline,level,blend),config.scoring.baseline_min,config.scoring.baseline_max)
		_observe_onset(target,level if envelope<0 else clampf(envelope,0,1),input_turn)
	for i in scorers.size():
		var scorer: RefCounted=scorers[i]
		var boundary: float=minf(scorer.word.end_sec+profile.lateness_tolerance_sec,timeline.turns[scorer.word.turn_index].end_sec)
		if i+1<scorers.size():boundary=minf(boundary,scorers[i+1].word.start_sec)
		if not scorer.finalized and target>=boundary:
			var assessment: Dictionary=scorer.finish()
			var quality: float=assessment.score/100.0
			interest=clampf(interest+(config.interest.gain_per_word*quality if assessment.score>=config.interest.success_score else -profile.interest_loss_per_word*(1-quality)),0,100)
	elapsed=target
	if elapsed>=float(timeline.level.duration_sec):
		finished=true
		finish_count+=1
		var sum_score:=0.0
		var hits:=0
		for scorer in scorers:
			var assessment: Dictionary=scorer.finish()
			sum_score+=assessment.score
			hits+=int(assessment.hit)
		var average:=sum_score/maxi(1,scorers.size())
		result={"words_hit":hits,"words_total":scorers.size(),"avg_word_score":average,"interest_end":interest,"passed":average>=profile.pass_avg_score}

func _observe_onset(seconds: float, level: float, turn_index: int) -> void:
	crest=maxf(crest,level)
	if crest-level>=config.scoring.onset_fall_delta:
		armed=true
		trough=level
		crest=level
	trough=minf(trough,level)
	if not armed or level<config.scoring.voice_threshold or level-trough<config.scoring.onset_rise_delta or seconds-last_onset<config.scoring.onset_min_gap_sec:return
	armed=false
	last_onset=seconds
	var nearest:=-1
	var distance: float=2*profile.onset_tolerance_sec
	for i in timeline.word_indices(turn_index):
		var offset:=absf(seconds-float(timeline.words[i].start_sec))
		if offset<=distance and not scorers[i].finalized:
			distance=offset
			nearest=i
	if nearest>=0:scorers[nearest].onset(seconds)
