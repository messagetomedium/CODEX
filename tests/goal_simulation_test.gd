extends SceneTree
## Deterministic mechanics and swept-collision checks; no renderer or microphone.
const Simulation = preload("res://scripts/goal/logic/goal_simulation.gd")
const Spawner = preload("res://scripts/goal/logic/defender_spawner.gd")
const Voice = preload("res://scripts/voice/voice_frame.gd")
const Collision = preload("res://scripts/goal/logic/screen_collision.gd")
var config: Dictionary
var layout: Dictionary
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func voice(rolling: float = 0, kick: float = 0) -> RefCounted:
	var result := Voice.new()
	result.rolling_intensity = rolling
	result.kick_impulse_strength = kick
	return result

func model(save: bool = false) -> RefCounted:
	var settings := config.duplicate(true)
	settings.goalkeeper.patrolLeftX = 0.495 if save else 0.37
	settings.goalkeeper.patrolRightX = 0.505 if save else 0.38
	var result := Simulation.new(settings, layout)
	result.keeper_x = (settings.goalkeeper.patrolLeftX + settings.goalkeeper.patrolRightX) / 2
	return result

func _init() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/gameplay.json"))
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/ui_layout.json"))
	var sim := model()
	var start: Vector2 = sim.projection.position(0)
	check(start.is_equal_approx(Vector2(960, 907.2)), "Projection retains the reference start composition")
	check(sim.projection.position(1).y < start.y and sim.projection.radius(1) < sim.projection.radius(0), "Depth moves upward and shrinks without moving the camera")
	check(sim.projection.position(0.5, 200).x == start.x, "Flight never changes ball X")
	sim.step(3.9, voice(1))
	check(sim.outcome.is_empty() and is_equal_approx(sim.ball.progress, 0.975), "Confident quiet rolling takes four seconds to the goal line")
	sim.step(0.2, voice(1))
	check(sim.outcome == "goal" and is_equal_approx(sim.ball.progress, 1), "Rolling alone scores and stops exactly at the swept goal crossing")
	var stopped_keeper: float = sim.keeper_x
	sim.step(30, voice(1, 1))
	check(sim.outcome == "goal" and sim.ball.progress == 1 and sim.keeper_x == stopped_keeper, "One outcome latches; resolved state ignores further input")
	sim = model()
	sim.step(1, voice(1))
	var before_stop: float = sim.ball.progress
	sim.step(0.1, voice())
	check(is_zero_approx(sim.ball.roll_speed) and sim.ball.progress - before_stop <= 0.0126, "Silence stops rolling within 100 ms with very little inertia")
	var resting: float = sim.ball.progress
	sim.step(10, voice())
	check(sim.ball.progress == resting and sim.outcome.is_empty(), "Silence has no timeout, reset or failure")
	sim = model()
	sim.step(0.01, voice(0, 0.05))
	check(sim.ball.flying and sim.ball.height() > 0, "A weak impulse starts a visible flight")
	sim.step(0.8, voice())
	check(not sim.ball.flying and sim.ball.height() == 0 and sim.ball.progress > 0 and sim.ball.progress < 1 and sim.outcome.is_empty(), "Weak kick lands short without resolving the ball")
	resting = sim.ball.progress
	sim.step(1, voice())
	check(sim.ball.progress == resting, "A short landing waits for the same player's next input")
	sim.step(0.2, voice(1))
	check(sim.ball.progress > resting, "A landed ball can roll further in the same play")
	sim.step(0.01, voice(0, 0.1))
	check(sim.ball.flying, "A landed ball accepts another impulse")
	var distance: float = sim.ball.flight_distance
	sim.step(0.01, voice(0, 1))
	check(sim.ball.flight_distance == distance, "An impulse cannot restart a ball already in flight")

	sim = model()
	sim.step(2, voice(0, 1))
	check(sim.outcome == "goal" and sim.ball.progress == 1, "A strong kick reaches the goal without overshooting the line")
	check(sim.ball.height() > 0, "A goal can resolve while the ball is still airborne")
	sim = model(true)
	sim.step(2, voice(0, 1))
	check(sim.outcome == "saved", "Keeper collision checks X at the line even for a high flight")
	sim = model(true)
	sim.step(5, voice(1))
	check(sim.outcome == "saved", "Keeper can save a rolling ball too")

	sim = Simulation.new(config, layout)
	var patrol: Vector2 = sim.patrol(0.5, 1, config.goalkeeper.crossScreenSeconds / 2)
	check(is_equal_approx(patrol.x, 0.63) and patrol.y == -1, "Keeper reflects at the right boundary")
	patrol = sim.patrol(0.37, 1, config.goalkeeper.crossScreenSeconds * 3)
	check(is_equal_approx(patrol.x, 0.63) and patrol.y == -1, "Patrol handles several crossings at constant speed")
	var a: Vector2 = sim.patrol(0.4, 1, 0.1)
	var b: Vector2 = sim.patrol(a.x, int(a.y), 0.1)
	check(is_equal_approx(a.x - 0.4, b.x - a.x), "Patrol speed is linear rather than sinusoidal")
	var whole: Vector2 = sim.patrol(0.5, 1, 17.3)
	var split: Vector2 = sim.patrol(0.5, 1, 7.1)
	split = sim.patrol(split.x, int(split.y), 10.2)
	check(whole.is_equal_approx(split), "Patrol result is independent of frame chunking")

	for direction in [-1, 1]:
		sim = model()
		check(sim.spawn_defender(direction, 0.7), "Spawn a defender from either edge")
		check(not sim.spawn_defender(-direction, 0.5), "An active defender prevents a second spawn")
		var y: float = sim.defender_y
		sim.step(1, voice())
		check(sim.defender_active and sim.defender_y == y, "A crossing keeps its fixed lane Y")
		sim.step(2, voice())
		check(not sim.defender_active and sim.outcome.is_empty(), "Defender fully exits without touching a READY ball")

	sim = model()
	sim.ball.kick(1)
	sim.ball.flight_fraction = 0.5
	sim.ball.progress = 0.6
	sim.ball.has_moved = true
	sim.spawn_defender(1, 0.5)
	sim.defender_x = 0.5
	sim.step(0.01, voice())
	check(sim.outcome == "intercept" and sim.ball.height() > 300, "Defender intercepts visible overlap even high in the air")
	check(is_equal_approx(sim.ball.progress, 0.6), "Intercept freezes at first contact without a bounce")

	sim = model()
	sim.settings.simulation.maxStepSeconds = 2
	sim.ball.progress = 0.4
	sim.ball.has_moved = true
	sim.spawn_defender(1, 0.7)
	sim.defender_x = 0.1
	sim.step(2, voice())
	check(sim.outcome == "intercept" and sim.defender_x < 0.5, "Swept screen collision catches a defender passing between endpoint frames")
	sim = model()
	sim.ball.progress = 0.999
	sim.spawn_defender(1, 0.5)
	sim.defender_x = 0.5
	sim.step(0.1, voice(1))
	check(sim.outcome == "intercept", "Defender takes priority when both events are possible at the goal line")
	sim = model()
	sim.ball.progress = 0.999
	sim.spawn_defender(-1, 0.5)
	sim.defender_x = 0.9
	sim.step(2, voice(1))
	check(sim.outcome == "goal", "A later defender intersection cannot override an earlier goal")

	var contact: float = Collision.first_contact(Vector2(0, 100), Vector2(1000, 100), 10, 10, Rect2(500, 80, 20, 40), Rect2(500, 80, 20, 40))
	check(is_equal_approx(contact, 0.49), "Swept hitbox computes first contact, not only endpoint overlap")
	contact = Collision.first_contact(Vector2(0, 10), Vector2(1000, 10), 10, 10, Rect2(500, 80, 20, 40), Rect2(500, 80, 20, 40))
	check(contact == -1, "Screen-separated objects do not collide")

	sim = model()
	var spawner := Spawner.new(config)
	spawner.rng.seed = 1920
	spawner.step(0.01, sim)
	check(sim.defender_active, "External scheduler supplies an initial crossing")
	var lane: float = sim.defender_y
	spawner.step(50, sim)
	check(sim.defender_y == lane, "Scheduler never replaces a still-active defender")
	sim.step(3, voice())
	spawner.step(0.01, sim)
	check(not sim.defender_active and spawner.wait_seconds >= 0.65 and spawner.wait_seconds <= 1.3, "A new random gap begins only after the previous defender exits")
	spawner.step(0.64, sim)
	check(not sim.defender_active, "Defender does not respawn before the gap")
	spawner.step(1.31, sim)
	check(sim.defender_active and sim.defender_y >= 0.42 and sim.defender_y <= 0.72, "Next crossing uses an allowed randomly selected lane")
	print("Goal simulation checks: ", checks, "; passed: ", checks - failures, "; failed: ", failures)
	quit(0 if failures == 0 else 1)
