extends RefCounted
## Deterministic 60-second tug-of-war. No renderer, audio, devices or wall clock.
var settings: Dictionary
var difficulty: Dictionary
var turns: Array[Dictionary] = []
var elapsed := 0.0
var turn_index := 0
var score := 50.0
var score_base := 50.0
var accumulated_loudness := 0.0
var peaks_count := 0
var total_peaks := 0
var last_peak_at := -1000.0
var finished := false
var finish_count := 0
var outcome := ""

func _init(config: Dictionary, level_id: String = "level_1", seed_value: int = 1) -> void:
	settings = config
	difficulty = config.levels[level_id]
	score = settings.score.initial
	score_base = score
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var duration: float = difficulty.duration_seconds
	var count: int = difficulty.get("turn_count",2*ceili(settings.timing.turn_count*duration/settings.round_duration_seconds/2))
	if difficulty.turn_mode == "fixed":
		count = ceili(duration / float(difficulty.turn_seconds))
	var budgets := [duration / 2, duration / 2]
	var at := 0.0
	for i in count:
		var seconds: float = difficulty.get("turn_seconds", settings.timing.fixed_turn_seconds)
		if difficulty.turn_mode == "random":
			# Independent lengths, equal total time per side. No impossible draw
			# caused by one side randomly receiving much more microphone time.
			var side := i % 2
			var after := (count - i - 1) / 2
			var low: float = maxf(difficulty.turn_seconds_min, budgets[side] - after * difficulty.turn_seconds_max)
			var high: float = minf(difficulty.turn_seconds_max, budgets[side] - after * difficulty.turn_seconds_min)
			seconds = rng.randf_range(low, high)
			budgets[side] -= seconds
		seconds = minf(seconds,duration-at)
		turns.append({"speaker": "opponent" if i % 2 == 0 else "player", "start": at, "end": at + seconds, "duration": seconds})
		at += seconds
	turns[-1].end = duration

func player_turn() -> bool:
	return not finished and turns[turn_index].speaker == "player"

func turn_remaining() -> float:
	return 0.0 if finished else maxf(0, turns[turn_index].end - elapsed)

func advance_to(target_seconds: float, loudness: float = 0, input_turn: int = -1) -> void:
	if finished:
		return
	var target: float = clampf(target_seconds, elapsed, difficulty.duration_seconds)
	while elapsed < target and not finished:
		var turn: Dictionary = turns[turn_index]
		var until: float = minf(target, turn.end)
		var dt := maxf(0, until - elapsed)
		if player_turn():
			# A stale pre-stall reading may only score in the turn it came from.
			if input_turn < 0 or input_turn == turn_index:
				accumulated_loudness += clampf(loudness, 0, 1) * dt / turn.duration
			_refresh_player_score()
		else:
			var nominal: float = settings.timing.fixed_turn_seconds
			score = _clamp(score_base - difficulty.opponent_loss_per_full_turn * (until - float(turn.start)) / nominal)
		elapsed = until
		if elapsed >= float(turn.end) - 0.00000001:
			score_base = score
			if turn_index == turns.size() - 1:
				finished = true
				finish_count += 1
				outcome = result_for_score(score)
			else:
				turn_index += 1
				accumulated_loudness = 0
				peaks_count = 0

func register_peak(at_seconds: float, input_turn: int) -> bool:
	if not player_turn() or input_turn != turn_index or not is_equal_approx(at_seconds, elapsed):
		return false
	if at_seconds - last_peak_at + 0.000000001 < settings.input.distinct_peak_min_gap_ms / 1000.0:
		return false
	last_peak_at = at_seconds
	peaks_count += 1
	total_peaks += 1
	_refresh_player_score()
	return true

func _refresh_player_score() -> void:
	var q_l := clampf(accumulated_loudness, 0, 1)
	var q_p := clampf(float(peaks_count) / difficulty.target_peaks, 0, 1)
	var full_gain: float = difficulty.player_gain_max_per_turn * turns[turn_index].duration / settings.timing.fixed_turn_seconds
	score = _clamp(score_base + full_gain * (settings.score.loudness_weight * q_l + settings.score.distinct_peak_weight * q_p))

func result_for_score(value: float) -> String:
	if value > settings.score.center + settings.score.draw_tolerance:
		return "win"
	if value < settings.score.center - settings.score.draw_tolerance:
		return "loss"
	return "draw"

func _clamp(value: float) -> float:
	return clampf(value, settings.score.min, settings.score.max)
