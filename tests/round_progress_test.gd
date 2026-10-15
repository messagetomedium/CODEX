extends SceneTree
const RoundProgress = preload("res://scripts/goal/logic/round_progress.gd")
const Simulation = preload("res://scripts/goal/logic/goal_simulation.gd")
const Positioner = preload("res://scripts/ui/ui_positioner.gd")
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
	var progress := RoundProgress.new(config)
	check(not progress.begin_movement(false) and progress.attempts_used == 0, "Waiting in silence costs no attempt")
	check(not progress.resolve("saved") and not progress.next_ball(), "A READY ball cannot resolve or advance")
	check(progress.begin_movement(true) and not progress.begin_movement(true) and progress.attempts_used == 1, "Only the first movement charges an attempt")
	check(not progress.resolve("unknown") and not progress.finished, "Only real outcomes can resolve a play")
	check(progress.resolve("frame") and not progress.resolve("goal") and progress.goals == 0, "Frame is one failure and cannot turn into a second result")
	check(progress.next_ball() and not progress.started, "Resolved play can prepare a fresh ball")
	for goals in 3:
		progress = RoundProgress.new(config)
		for i in 6:
			progress.begin_movement(true)
			check(not progress.finished and progress.attempts_used == i + 1, "The moving sixth ball does not trigger an early final")
			progress.resolve("goal" if i < goals else ["saved", "caught", "frame", "intercept"][i % 4])
			check(progress.finished == (i == 5), "A losing round ends only on resolution six")
			if i < 5:
				progress.next_ball()
		check(progress.goals == goals and progress.attempts_used == 6 and progress.attempts_resolved == 6, "Loss tiers preserve their true 0/1/2 score")
		check(not progress.begin_movement(true) and not progress.next_ball(), "A finished round accepts no seventh attempt")
	progress = RoundProgress.new(config)
	for i in 3:
		progress.begin_movement(true)
		progress.resolve("goal")
		if i < 2:
			progress.next_ball()
	check(progress.finished and progress.goals == 3 and progress.attempts_used == 3, "The third goal wins without spending remaining attempts")
	progress = RoundProgress.new(config)
	for i in 6:
		progress.begin_movement(true)
		progress.resolve("goal" if i in [0, 1, 5] else "saved")
		if i < 5:
			progress.next_ball()
	check(progress.finished and progress.goals == 3 and progress.attempts_used == 6, "The third goal on ball six wins correctly")

	var sim := Simulation.new(config, layout)
	var rect: Rect2 = sim.projection.goal_rect()
	var radius: float = sim.projection.radius(1)
	var bar_bottom: float = rect.position.y + sim.projection.frame_width() / 2
	check(sim.goal_line_outcome(0.5, Vector2(960, rect.position.y)) == "frame", "Crossbar takes precedence over goalkeeper")
	check(sim.goal_line_outcome(0.37, Vector2(rect.position.x, 450)) == "frame", "Left post is a frame contact")
	check(sim.goal_line_outcome(0.63, Vector2(rect.end.x, 450)) == "frame", "Right post is a frame contact")
	check(sim.goal_line_outcome(0.5, Vector2(960, bar_bottom + radius * config.goalFrame.ballContactRadiusFraction - 0.1)) == "frame", "Inner core touching the bar is not called a save")
	check(sim.goal_line_outcome(0.5, Vector2(960, bar_bottom + radius + 1)) == "caught", "A ball wholly below the bar and above the head is caught with raised hands")
	check(sim.goal_line_outcome(0.37, Vector2(960, bar_bottom + radius + 1)) == "goal", "An overhead ball scores when the goalkeeper is away")
	check(sim.goal_line_outcome(0.5, sim.projection.position(1)) == "saved", "A body-height rolling save keeps the ordinary save message")
	check(sim.goal_line_outcome(0.5, Vector2(960, 375)) == "saved", "A ball still overlapping the head is not mistaken for a clear overhead catch")
	var voice = load("res://scripts/voice/voice_frame.gd").new()
	voice.kick_impulse_strength = 1
	sim.step(2, voice)
	check(sim.outcome == "goal" and sim.ball.progress == 1 and not sim.keeper_raised, "The larger goal admits a strong starting kick when the keeper is away")
	sim = Simulation.new(config, layout)
	sim.ball.progress = 0.5
	sim.step(2, voice)
	check(sim.outcome == "frame" and sim.projection.hits_frame(sim.projection.position(1, sim.ball.height()), radius), "Close high kick meets the visible frame instead of disappearing above the goal")
	sim = Simulation.new(config, layout)
	var settings: Dictionary = config.duplicate(true)
	settings.goalkeeper.patrolLeftX = 0.495
	settings.goalkeeper.patrolRightX = 0.505
	sim = Simulation.new(settings, layout)
	voice.kick_impulse_strength = 0.98
	sim.step(2, voice)
	check(sim.outcome == "caught" and sim.keeper_raised and not sim.projection.hits_frame(sim.projection.position(1, sim.ball.height()), radius), "A real flight under the crossbar triggers the raised-hands catch")
	var keeper: float = sim.keeper_x
	sim.step(20, voice)
	check(sim.outcome == "caught" and sim.keeper_x == keeper, "Catch resolves once and freezes mechanics")

	var protected: Array[Rect2] = [Rect2(350, 50, 300, 200)]
	var placement: Dictionary = layout.eventPlacement
	var candidate: Rect2 = Positioner.choose(Vector2(250, 100), [{"x": 0.5, "y": 0.15}, {"x": 0.2, "y": 0.7}], protected, Vector2(1000, 1000), placement)
	check(candidate.has_area() and not candidate.intersects(protected[0].grow(16)) and candidate.get_center().y == 700, "Notification skips occupied first anchor")
	protected = [Rect2(0, 0, 1000, 1000)]
	check(not Positioner.choose(Vector2(250, 100), [{"x": 0.5, "y": 0.15}], protected, Vector2(1000, 1000), placement).has_area(), "Positioner never forces text over protected objects")
	print("Round/frame checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
