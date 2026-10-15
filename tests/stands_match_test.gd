extends SceneTree
const Match = preload("res://scripts/stands/logic/stands_match.gd")
const Clock = preload("res://scripts/stands/logic/session_clock.gd")
const Bursts = preload("res://scripts/stands/logic/voice_bursts.gd")
const Tug = preload("res://scripts/stands/logic/tug_geometry.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func ideal(model: RefCounted) -> void:
	while not model.finished:
		var turn: Dictionary = model.turns[model.turn_index]
		if model.player_turn():
			for peak in int(model.difficulty.target_peaks):
				model.advance_to(float(turn.start)+.4+peak*.4,1)
				model.register_peak(model.elapsed,model.turn_index)
			model.advance_to(turn.end,1)
		else:model.advance_to(turn.end,1)

func _init() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/stands_gameplay.json"))
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/gameplay.json"))
	var model := Match.new(config)
	check(model.turns.size()==6 and model.score==50,"First round starts centered with exactly six turns")
	var correct := true
	for i in 6:
		var turn: Dictionary = model.turns[i]
		correct=correct and turn.start==i*5 and turn.end==(i+1)*5 and turn.speaker==("opponent" if i%2==0 else "player")
	check(correct,"First round strictly alternates opponent/player in five-second turns")
	model.advance_to(29.999)
	check(not model.finished,"The round does not finish before thirty seconds")
	model.advance_to(100)
	check(model.finished and model.elapsed==30 and is_equal_approx(model.score,35) and model.outcome=="loss","Silence ends at exactly thirty seconds with score thirty-five, even across a stall")
	model.advance_to(1000,1)
	check(model.finish_count==1 and is_equal_approx(model.score,35),"Completion is latched once and freezes score")
	model=Match.new(config)
	ideal(model)
	check(is_equal_approx(model.score,77) and model.total_peaks==6 and model.outcome=="win","Ideal normalized voice and two distinct peaks in all three player turns produce seventy-seven")
	for score in [49.5,50.0,50.5]:
		check(model.result_for_score(score)=="draw","The inclusive tolerance band is a draw")
	check(model.result_for_score(50.50001)=="win" and model.result_for_score(49.49999)=="loss","Formal victory uses the displayed center tolerance")
	check(Tug.marker_fraction(80)<Tug.marker_fraction(50) and Tug.marker_fraction(20)>Tug.marker_fraction(50),"Higher support physically moves the marker toward the player on the left")
	model=Match.new(config)
	model.advance_to(5,1)
	check(model.score==45 and model.peaks_count==0,"Microphone volume during the opponent turn earns nothing")
	check(not model.register_peak(5,0),"An opponent or stale-turn peak cannot enter the player score")
	model.advance_to(6,1)
	model.register_peak(6,1)
	var earned: float = model.score
	model.advance_to(7,0)
	check(model.score==earned,"Silence never removes support earned in the player's turn")
	check(not model.register_peak(7,0) and not model.register_peak(6,1),"Wrong-turn and out-of-time peak reports are rejected")
	check(model.register_peak(7,1) and not model.register_peak(7.1,1),"Only current-time distinct peak events are accepted")
	model.advance_to(7.2)
	check(not model.register_peak(7.2,1),"Peaks less than three hundred fifty milliseconds apart are rejected")
	model.advance_to(7.35)
	check(model.register_peak(7.35,1),"A new peak can count at the configured gap")
	model=Match.new(config)
	model.advance_to(6.4,1)
	check(is_equal_approx(model.score,45+14*.25*1.4/5),"A frame crossing a turn boundary integrates only the player segment")
	model=Match.new(config)
	model.advance_to(9.9,1,0)
	check(model.score==45,"A pre-stall opponent reading cannot score in a skipped player turn")
	var burst := Bursts.new(base.microphone,config.input)
	check(not burst.sample(1,0),"Loud audio inherited from the opponent cannot become a peak without release")
	burst.sample(0,.1)
	check(burst.sample(1,.2) and not burst.sample(1,.7),"Held voice is one rising burst")
	burst.sample(0,.75)
	check(burst.sample(1,.8),"Releasing and rising creates a new distinct burst")
	burst.reset()
	check(not burst.sample(1,1.2),"Reset disarms peaks across turn boundaries")
	burst.sample(0,1.3)
	check(burst.sample(.47,1.6) and .47<base.microphone.kickLevelMinNormalized,"Stands accepts a moderate peak below Goal's kick threshold without changing Goal input")
	var held := Match.new(config)
	held.advance_to(10,1)
	var pulsed := Match.new(config)
	pulsed.advance_to(5.5)
	pulsed.register_peak(5.5,1)
	var one_peak: float = pulsed.score
	pulsed.advance_to(6)
	pulsed.register_peak(6,1)
	check(one_peak>held.score and pulsed.score>one_peak,"A short peak contributes more than sustained volume alone; a second peak adds support")
	for number in range(1,4):
		var moderate := Match.new(config,"level_"+str(number),452)
		while not moderate.finished:
			var turn: Dictionary = moderate.turns[moderate.turn_index]
			if moderate.player_turn():
				for i in number:
					moderate.advance_to(float(turn.start)+.4+i*.4)
					moderate.register_peak(moderate.elapsed,moderate.turn_index)
			moderate.advance_to(turn.end)
		check(moderate.outcome=="win","One/two/three clear peaks per player turn can win the respective level without ideal sustained loudness")
	var clock := Clock.new()
	check(clock.seconds(99999)==0,"Clock waits for microphone readiness")
	clock.start(1000)
	check(clock.seconds(61234)==60.234,"Clock follows monotonic elapsed time, not frame accumulation")
	clock.pause(6500)
	check(clock.seconds(100000)==5.5,"Error popup pauses the session clock")
	clock.resume(100000)
	check(clock.seconds(101000)==6.5,"Microphone recovery excludes the whole paused interval")
	clock.start(200000)
	check(clock.seconds(200000)==0,"Restart clears prior elapsed and pause durations")
	for number in range(2,4):
		var level_id := "level_"+str(number)
		var all_valid := true
		var varied := false
		for seed_value in 20:
			model=Match.new(config,level_id,seed_value)
			var player_time := 0.0
			var opponent_time := 0.0
			for i in model.turns.size():
				var turn: Dictionary=model.turns[i]
				all_valid=all_valid and turn.duration>=3-.000001 and turn.duration<=6+.000001 and turn.speaker==("opponent" if i%2==0 else "player")
				if turn.speaker=="player":player_time+=turn.duration
				else:opponent_time+=turn.duration
			var same := Match.new(config,level_id,seed_value)
			all_valid=all_valid and same.turns==model.turns and is_equal_approx(player_time,15) and is_equal_approx(opponent_time,15) and is_equal_approx(model.turns[-1].end,30)
			var other := Match.new(config,level_id,seed_value+1)
			varied=varied or other.turns!=model.turns
		check(all_valid and varied,"Higher levels have seeded, varied three-to-six-second turns, alternate speakers, and give each side fifteen seconds")
		model=Match.new(config,level_id,452)
		ideal(model)
		check(is_equal_approx(model.score,77-(number-1)*3) and model.outcome=="win","Every difficulty is winnable with ideal input; stronger opponents reduce the final support")
		model=Match.new(config,level_id,452)
		model.advance_to(30)
		check(is_equal_approx(model.score,35-(number-1)*3),"Silence loses faster at each higher difficulty")
	var extended:=config.duplicate(true)
	extended.levels.level_4=extended.levels.level_3.duplicate(true)
	model=Match.new(extended,"level_4",452)
	ideal(model)
	check(model.finished and model.outcome=="win","An additional configured difficulty reuses the same mechanics")
	extended.levels.level_4.duration_seconds=40
	extended.levels.level_4.turn_mode="fixed"
	extended.levels.level_4.turn_seconds=5
	model=Match.new(extended,"level_4",452)
	ideal(model)
	check(model.finished and model.elapsed==40 and model.turns.size()==8,"Configured duration changes schedule and finish time without code changes")
	var extreme:=config.duplicate(true)
	extreme.levels.level_1.opponent_loss_per_full_turn=200
	extreme.levels.level_1.player_gain_max_per_turn=400
	model=Match.new(extreme)
	model.advance_to(5)
	check(model.score==0,"Support clamps at zero under an extreme opponent")
	model.advance_to(10,1)
	check(model.score==100,"Support clamps at one hundred under extreme recovery")
	print("Stands mechanics checks: ",checks,"; passed: ",checks-failures,"; failed: ",failures)
	quit(0 if failures==0 else 1)
