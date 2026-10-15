extends SceneTree
const RoundSettings = preload("res://scripts/goal/logic/round_settings.gd")
const RoundProgress = preload("res://scripts/goal/logic/round_progress.gd")
const Campaign = preload("res://scripts/goal/logic/campaign_progress.gd")
const Simulation = preload("res://scripts/goal/logic/goal_simulation.gd")
const Spawner = preload("res://scripts/goal/logic/defender_spawner.gd")
const KeeperPattern = preload("res://scripts/goal/logic/keeper_pattern.gd")
const Voice = preload("res://scripts/voice/voice_frame.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _init() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/gameplay.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/ui_layout.json"))
	var voice := Voice.new()
	var campaign := Campaign.new(config)
	check(not campaign.advance() and not campaign.game_won(), "A new game cannot skip the first round")
	for number in range(1, 4):
		var settings := RoundSettings.for_round(config, number)
		check(settings.round.number == number and settings.defender.maxSimultaneous == number, "Round difficulty selects one/two/three defender slots")
		check(settings.microphone == config.microphone and settings.kick.cooldownMs == config.kick.cooldownMs, "Difficulty preserves accepted microphone timing")
		var progress := RoundProgress.new(settings)
		for i in 3:
			progress.begin_movement(true)
			progress.resolve("goal")
			if i < 2:
				progress.next_ball()
		campaign.record(progress)
		campaign.record(progress)
		check(campaign.results.size() == number, "An outcome can only be recorded once per round")
		if number < 3:
			check(campaign.can_advance() and campaign.advance() and campaign.number == number + 1, "Winning unlocks exactly the next round")
		else:
			check(campaign.game_won() and not campaign.advance(), "Third victory completes the game with no fourth round")
	check(campaign.totals(config).goals == 9 and campaign.totals(config).attemptsUsed == 9, "Completion totals combine the three completed rounds")
	campaign.retry_round()
	check(campaign.number == 3 and campaign.results.size() == 2 and not campaign.game_won(), "Retry keeps earlier rounds and removes only the current result")
	var failed := RoundProgress.new(RoundSettings.for_round(config, 3))
	for i in 6:
		failed.begin_movement(true)
		failed.resolve("saved")
		if i < 5:
			failed.next_ball()
	campaign.record(failed)
	check(not campaign.game_won() and not campaign.can_advance(), "Losing round three cannot unlock completion")
	campaign.restart()
	check(campaign.number == 1 and campaign.results.is_empty(), "Play again starts at round one with no stale totals")
	var isolated := RoundSettings.for_round(config, 2)
	isolated.defender.lanes[0] = 0.9
	check(config.rounds[1].defender.lanes[0] != 0.9 and config.round.number == 1, "Round configuration is a fully isolated copy")
	check(config.rounds[0].defender.crossScreenSeconds > config.rounds[1].defender.crossScreenSeconds and config.rounds[1].defender.crossScreenSeconds > config.rounds[2].defender.crossScreenSeconds and config.rounds[2].defender.crossScreenSeconds == 2.6, "Defenders speed up gradually to the former speed only in round three")

	for number in range(1, 4):
		var settings := RoundSettings.for_round(config, number)
		var sim := Simulation.new(settings, layout)
		var spawner := Spawner.new(settings)
		spawner.rng.seed = 452 + number
		spawner.step(0.016, sim)
		var correct := true
		var directions: Array[int] = []
		for body in sim.defenders:
			correct = correct and body.active and body.y >= layout.refComposition.goal.y + settings.defender.minDepthAheadOfGoal
			directions.append(body.direction)
		check(correct, "All slots can appear simultaneously, strictly in front of the goal")
		check(number == 1 or (1 in directions and -1 in directions), "Simultaneous defenders run toward one another")
		var safe := true
		var replacements := 0
		for i in 700:
			var was_active: bool = sim.defenders[0].active
			sim.step(0.02, voice)
			spawner.step(0.02, sim)
			if not was_active and sim.defenders[0].active:
				replacements += 1
			for a in sim.defenders.size():
				var body: Dictionary = sim.defenders[a]
				if not body.active:
					continue
				safe = safe and body.y >= layout.refComposition.goal.y + settings.defender.minDepthAheadOfGoal
				for b in range(a + 1, sim.defenders.size()):
					if sim.defenders[b].active:
						safe = safe and absf(body.y - sim.defenders[b].y) >= settings.defender.minimumLaneSeparation
		check(safe and replacements > 0 and sim.outcome.is_empty(), "Repeated waves keep distinct lanes and never resolve an untouched ball")
		check(not sim.spawn_defender(1, 0.9, sim.defenders.size()), "A round cannot spawn beyond its slot limit")
		if number > 1:
			var keeper: Dictionary = settings.goalkeeper
			var cycle := KeeperPattern.duration(keeper)
			var bounded := true
			var repeats := true
			var held := false
			var reversals := 0
			var last_direction := 1
			for i in 1000:
				var t := cycle * i / 1000.0
				var point := KeeperPattern.sample(t, keeper)
				bounded = bounded and point.x >= keeper.patrolLeftX and point.x <= keeper.patrolRightX
				repeats = repeats and point.is_equal_approx(KeeperPattern.sample(t + cycle, keeper))
				held = held or point.y == 0
				if point.y != 0 and point.y != last_direction:
					reversals += 1
					last_direction = int(point.y)
			check(bounded and repeats and held and reversals >= 4, "Keeper follows a bounded repeatable pattern with holds and reversals")
			var hold_time: float = absf(float(keeper.pattern[0].to) - 0.5) * keeper.crossScreenSeconds
			var hold_a := KeeperPattern.sample(hold_time + 0.02, keeper)
			var hold_b := KeeperPattern.sample(hold_time + 0.1, keeper)
			check(hold_a.is_equal_approx(hold_b) and hold_a.y == 0, "A hold is a real stationary interval")
			var whole := Simulation.new(settings, layout)
			var split := Simulation.new(settings, layout)
			whole.step(cycle + 0.73, voice)
			for i in 127:
				split.step((cycle + 0.73) / 127, voice)
			check(is_equal_approx(whole.keeper_x, split.keeper_x) and is_equal_approx(whole.keeper_time, split.keeper_time), "Keeper phase does not depend on render-frame chunking")

	var sim := Simulation.new(config, layout)
	var radius: float = sim.projection.radius(1)
	var center: Vector2 = sim.projection.position(1)
	var half_width: float = config.goalkeeper.hitboxWidthFractionOfCanvas * 1920 / 2
	check(sim.goal_line_outcome(0.5 + (half_width + radius * 0.8) / 1920, center) == "goal", "A visible edge graze past the goalkeeper is awarded a goal")
	check(sim.goal_line_outcome(0.5, center) == "saved", "A direct central goalkeeper contact still saves")
	var rect: Rect2 = sim.projection.goal_rect()
	var half_frame: float = sim.projection.frame_width() / 2
	check(sim.goal_line_outcome(0.37, Vector2(960, rect.position.y + half_frame + radius * 0.8)) == "goal", "The ball rim may graze the crossbar from inside and still score")
	check(sim.goal_line_outcome(0.63, Vector2(rect.position.x + half_frame + radius * 0.8, 450)) == "goal", "A post graze from inside the mouth remains a goal")
	check(sim.goal_line_outcome(0.37, Vector2(rect.position.x, 450)) == "frame", "Nearly central ball contact with the frame remains a failure")
	check(sim.goal_line_outcome(0.37, Vector2(960, rect.position.y - radius)) == "frame", "A center outside the mouth above the bar cannot be called a goal")
	check(sim.goal_line_outcome(0.37, Vector2(rect.position.x - radius, 450)) == "frame", "A center outside either post cannot be called a goal")

	var settings := RoundSettings.for_round(config, 3)
	sim = Simulation.new(settings, layout)
	sim.spawn_defender(1, 0.55)
	sim.spawn_defender(-1, 0.645)
	sim.spawn_defender(1, 0.74)
	sim.ball.progress = 0.72
	sim.ball.has_moved = true
	sim.defenders[0].x = 0.1
	sim.defenders[1].x = 0.9
	sim.defenders[2].x = 0.45
	sim.step(1, voice)
	check(sim.outcome == "intercept" and sim.intercepted_by == 2 and sim.defenders[1].x > 0.85, "Earliest contact across all defenders wins and freezes every other body at that instant")
	var frozen: Array = sim.defenders.duplicate(true)
	var frozen_time: float = sim.keeper_time
	sim.step(10, voice)
	check(sim.defenders == frozen and sim.keeper_time == frozen_time, "An overlay outcome freezes every defender and the patterned keeper")
	sim = Simulation.new(config, layout)
	sim.spawn_defender(1, 0.74)
	sim.ball.progress = 0.72
	sim.ball.has_moved = true
	var full_half_width: float = sim.projection.defender_half_width(0.74)
	sim.defenders[0].x = 0.5 + (full_half_width + sim.projection.radius(0.72) - 1) / 1920
	sim.step(0.001, voice)
	check(sim.outcome.is_empty(), "A barely grazing defender silhouette does not intercept the ball core")
	sim.defenders[0].x = 0.5
	sim.step(0.001, voice)
	check(sim.outcome == "intercept", "A direct body overlap still intercepts")
	print("Campaign mechanics checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
