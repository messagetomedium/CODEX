extends SceneTree
## Regressions for real field depth, independent of sprite size and flight height.
const Simulation = preload("res://scripts/goal/logic/goal_simulation.gd")
const RoundSettings = preload("res://scripts/goal/logic/round_settings.gd")
const Collision = preload("res://scripts/goal/logic/screen_collision.gd")
const Voice = preload("res://scripts/voice/voice_frame.gd")
var config: Dictionary
var layout: Dictionary
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func model(lane: float = 0.74) -> RefCounted:
	var sim := Simulation.new(config.duplicate(true), layout)
	sim.spawn_defender(1, lane)
	sim.defenders[0].x = 0.5
	sim.ball.has_moved = true
	return sim

func visible_overlap(sim: RefCounted) -> bool:
	var center: Vector2 = sim.projection.position(sim.ball.progress, sim.ball.height())
	var radius: float = sim.projection.radius(sim.ball.progress) * config.ball.hitboxRadiusFraction
	var rect: Rect2 = sim.projection.defender_rect(sim.defenders[0].x, sim.defenders[0].y)
	return Collision.first_contact(center, center, radius, radius, rect, rect) >= 0

func _init() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/gameplay.json"))
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/ui_layout.json"))
	for number in range(1, 4):
		var settings := RoundSettings.for_round(config, number)
		for lane: float in settings.defender.lanes:
			var sim := Simulation.new(settings, layout)
			sim.spawn_defender(1, lane)
			var depth: float = sim.defenders[0].depth
			check(depth > 0 and depth < 1 and is_equal_approx(sim.projection.ground_y(depth), lane * 1080), "Every configured lane maps to a genuine field depth and back to the same feet position")
			sim.ball.progress = depth
			sim.ball.has_moved = true
			sim.defenders[0].x = 0.5
			sim.step(0.001, Voice.new())
			check(sim.outcome == "intercept", "Rolling central contact works at every lane in every round")

	var sim := model()
	sim.ball.progress = 0.8
	check(visible_overlap(sim), "Regression fixture: distant ball actually overlaps the foreground silhouette")
	sim.step(1, Voice.new())
	check(sim.outcome.is_empty() and sim.ball.progress == 0.8, "A foreground defender cannot intercept a ball that has already passed him")
	sim = model(0.55)
	sim.ball.kick(1)
	sim.ball.progress = 0.5
	sim.ball.flight_fraction = 0.5
	sim.ball.flight_arc = 200
	sim.ball.flight_start = sim.ball.progress - sim.ball.flight_distance * sim.ball.flight_fraction
	check(visible_overlap(sim), "Regression fixture: nearby airborne ball actually overlaps the distant silhouette")
	sim.step(0.001, Voice.new())
	check(sim.outcome.is_empty(), "A distant defender cannot intercept a nearer airborne ball")

	sim = model()
	sim.ball.progress = sim.defenders[0].depth
	sim.ball.kick(1)
	sim.ball.flight_fraction = 0.5
	sim.ball.flight_arc = 500
	sim.ball.flight_start = sim.ball.progress - sim.ball.flight_distance * sim.ball.flight_fraction
	sim.step(0.001, Voice.new())
	check(sim.outcome.is_empty(), "Matching ground depth alone cannot intercept a ball above the entire body")

	# One deliberately huge step crosses the entire depth band between endpoints.
	sim = model()
	sim.settings.simulation.maxStepSeconds = 2
	sim.settings.defender.crossScreenSeconds = 1000000
	sim.ball.progress = 0.4
	var rolling := Voice.new()
	rolling.rolling_intensity = 1
	sim.step(0.8, rolling)
	var contact_depth: float = sim.defenders[0].depth - config.ball.collisionHalfDepthProgress - config.defender.collisionHalfDepthProgress
	check(sim.outcome == "intercept" and is_equal_approx(sim.ball.progress, contact_depth), "Swept contact waits for depth entry, even when screen overlap starts earlier and both endpoints miss the depth band")
	var frozen: float = sim.ball.progress
	sim.step(1, rolling)
	check(sim.ball.progress == frozen, "A depth contact produces one latched outcome")

	# X overlap happens well before the ball arrives at this defender's depth.
	sim = model()
	sim.settings.simulation.maxStepSeconds = 2
	sim.settings.defender.crossScreenSeconds = 0.8
	sim.defenders[0].x = 0.25
	sim.ball.progress = 0.3
	sim.step(1, rolling)
	check(sim.outcome.is_empty(), "Overlapping X and depth at different times is not a collision")

	var coarse := model()
	var fine := model()
	for sample in [coarse, fine]:
		sample.settings.defender.crossScreenSeconds = 1000000
		sample.ball.progress = 0.4
	coarse.settings.simulation.maxStepSeconds = 2
	coarse.step(0.8, rolling)
	for i in 80:
		fine.step(0.01, rolling)
	check(coarse.outcome == fine.outcome and is_equal_approx(coarse.ball.progress, fine.ball.progress), "Coarse and fine updates stop at the same depth contact")

	sim = model()
	sim.settings.defender.crossScreenSeconds = 1000000
	sim.ball.progress = 0.4
	var kick := Voice.new()
	kick.kick_impulse_strength = 1
	sim.step(1.35, kick)
	check(sim.outcome == "intercept" and sim.ball.progress < sim.defenders[0].depth, "A real maximum-speed airborne shot cannot tunnel through a central defender")

	var window := Collision.depth_interval(0.2, 0.8, 0.5, 0.03)
	check(window.is_equal_approx(Vector2(0.45, 0.55)), "Depth sweep finds both entry and exit between endpoints")
	check(Collision.depth_interval(0.8, 0.2, 0.5, 0.03).is_equal_approx(window), "Depth sweep also supports reverse crossings")
	check(Collision.depth_interval(0.5, 0.5, 0.5, 0.03) == Vector2(0, 1), "A stationary ball at matching depth remains touchable")
	check(Collision.depth_interval(0.6, 0.6, 0.5, 0.03).x < 0, "A stationary ball at a different depth remains separate")
	var rect := Rect2(0, 0, 20, 20)
	check(is_equal_approx(Collision.first_contact(Vector2(10, 10), Vector2(10, 10), 1, 1, rect, rect, window), 0.45), "Screen overlap lasting into depth entry contacts at depth entry")
	check(Collision.first_contact(Vector2(-10, 10), Vector2(100, 10), 1, 1, rect, rect, window) < 0, "A screen contact that has ended before depth entry is rejected")
	print("Depth collision checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
