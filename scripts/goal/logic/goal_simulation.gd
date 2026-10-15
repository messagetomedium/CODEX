extends RefCounted
## Pure simulation: multiple independent crossings and one earliest, latched outcome.
const Ball = preload("res://scripts/goal/logic/ball_motion.gd")
const FieldProjection = preload("res://scripts/goal/logic/field_projection.gd")
const Collision = preload("res://scripts/goal/logic/screen_collision.gd")
const KeeperPattern = preload("res://scripts/goal/logic/keeper_pattern.gd")
var settings: Dictionary
var projection: RefCounted
var ball: RefCounted
var keeper_x := 0.5
var keeper_direction := 1
var keeper_time := 0.0
var defenders: Array[Dictionary] = []
var outcome := ""
var keeper_raised := false
var intercepted_by := -1

func _init(config: Dictionary, layout: Dictionary) -> void:
	settings = config
	projection = FieldProjection.new(config, layout)
	reset_ball()
	keeper_x = layout.refComposition.goal.x
	for i in int(config.defender.maxSimultaneous):
		defenders.append({"active": false, "x": 0.0, "y": 0.0, "depth": 0.0, "direction": 1})

func reset_ball() -> void:
	ball = Ball.new(settings)
	ball.projection = projection
	outcome = ""
	keeper_raised = false
	intercepted_by = -1

func goal_line_outcome(x: float, center: Vector2) -> String:
	var line: float = settings.ball.progressAtGoalLine
	var radius: float = projection.radius(line)
	if projection.hits_frame(center, radius):
		return "frame"
	var keeper_half_width: float = settings.goalkeeper.hitboxWidthFractionOfCanvas * projection.design.x / 2
	var distance: float = absf(x * projection.design.x - center.x)
	if distance >= keeper_half_width + radius * settings.goalkeeper.ballContactRadiusFraction:
		return "goal"
	var head_top: float = projection.goal_rect().end.y - projection.layout.components.world.keeperHeight * projection.design.y * settings.goalkeeper.headTopHeightFraction
	return "caught" if center.y + radius <= head_top else "saved"

func spawn_defender(direction: int, lane_y: float, slot: int = -1) -> bool:
	if not outcome.is_empty():
		return false
	if slot < 0:
		for i in defenders.size():
			if not defenders[i].active:
				slot = i
				break
	if slot < 0 or slot >= defenders.size() or defenders[slot].active:
		return false
	var min_y: float = maxf(settings.defender.laneYNormalizedMin, projection.layout.refComposition.goal.y + settings.defender.minDepthAheadOfGoal)
	lane_y = clampf(lane_y, min_y, settings.defender.laneYNormalizedMax)
	for body in defenders:
		if body.active and absf(float(body.y) - lane_y) < settings.defender.minimumLaneSeparation:
			return false
	var margin: float = projection.defender_half_width(lane_y) / projection.design.x
	# Y identifies the configured lane; depth governs contacts and projection.
	defenders[slot] = {"active": true, "x": -margin if direction >= 0 else 1 + margin, "y": lane_y, "depth": projection.depth_at_ground_y(lane_y), "direction": 1 if direction >= 0 else -1}
	return true

func patrol(x: float, direction: int, seconds: float) -> Vector2:
	var left: float = settings.goalkeeper.patrolLeftX
	var right: float = settings.goalkeeper.patrolRightX
	var span := right - left
	if span <= 0:
		return Vector2(left, 1)
	var phase := x - left if direction > 0 else 2 * span - (x - left)
	phase = fposmod(phase + span * seconds / settings.goalkeeper.crossScreenSeconds, 2 * span)
	return Vector2(left + (phase if phase < span else 2 * span - phase), 1 if phase < span else -1)

func _keeper_at(x: float, direction: int, start_time: float, delta: float) -> Vector2:
	if not settings.goalkeeper.pattern.is_empty():
		return KeeperPattern.sample(start_time + delta, settings.goalkeeper)
	return patrol(x, direction, delta)

func step(delta: float, voice: RefCounted) -> void:
	if not outcome.is_empty() or delta <= 0:
		return
	ball.kick(voice.kick_impulse_strength)
	var remaining := delta
	while remaining > 0 and outcome.is_empty():
		var dt := minf(remaining, settings.simulation.maxStepSeconds)
		if ball.flying:
			dt = minf(dt, maxf(0.000000001, (1 - ball.flight_fraction) * ball.flight_seconds))
		_advance(dt, voice.rolling_intensity)
		remaining -= dt

func _advance(dt: float, rolling: float) -> void:
	var previous_progress: float = ball.progress
	var previous_fraction: float = ball.flight_fraction
	var previous_arc: float = ball.flight_arc
	var was_flying: bool = ball.flying
	var old_position: Vector2 = projection.position(previous_progress, ball.height())
	var old_radius: float = projection.radius(previous_progress) * settings.ball.hitboxRadiusFraction
	var old_keeper := keeper_x
	var old_direction := keeper_direction
	var old_time := keeper_time
	var old_x: Array[float] = []
	for body in defenders:
		old_x.append(body.x)
	ball.advance(dt, rolling)
	var moved_keeper := _keeper_at(keeper_x, keeper_direction, keeper_time, dt)
	keeper_x = moved_keeper.x
	keeper_direction = int(moved_keeper.y)
	keeper_time += dt
	for body in defenders:
		if body.active:
			var margin: float = projection.defender_half_width(body.y) / projection.design.x
			body.x += body.direction * (1 + 2 * margin) * dt / settings.defender.crossScreenSeconds
	var line: float = settings.ball.progressAtGoalLine
	var crossing: float = (line - previous_progress) / (ball.progress - previous_progress) if previous_progress < line and ball.progress >= line else -1.0
	var contact := -1.0
	if ball.has_moved:
		var limit := crossing if crossing >= 0 else 1.0
		var end_progress := lerpf(previous_progress, ball.progress, limit)
		var end_height: float = previous_arc * sin(PI * lerpf(previous_fraction, ball.flight_fraction, limit)) if was_flying else 0.0
		for i in defenders.size():
			var body: Dictionary = defenders[i]
			if not body.active:
				continue
			var half_depth: float = settings.ball.collisionHalfDepthProgress + settings.defender.collisionHalfDepthProgress
			var depth_window := Collision.depth_interval(previous_progress, end_progress, body.depth, half_depth)
			if depth_window.x < 0:
				continue
			var lane_y: float = projection.ground_y(body.depth) / projection.design.y
			var hit: float = Collision.first_contact(old_position, projection.position(end_progress, end_height), old_radius, projection.radius(end_progress) * settings.ball.hitboxRadiusFraction, projection.defender_rect(old_x[i], lane_y), projection.defender_rect(lerpf(old_x[i], body.x, limit), lane_y), depth_window)
			if hit >= 0:
				hit *= limit
				if contact < 0 or hit < contact:
					contact = hit
					intercepted_by = i
	var stop_at := -1.0
	if contact >= 0 and (crossing < 0 or contact <= crossing + 0.000001):
		outcome = "intercept"
		stop_at = contact
	elif crossing >= 0:
		stop_at = crossing
		var at_line := _keeper_at(old_keeper, old_direction, old_time, dt * crossing)
		var height_at_line := previous_arc * sin(PI * lerpf(previous_fraction, ball.flight_fraction, crossing)) if was_flying else 0.0
		outcome = goal_line_outcome(at_line.x, projection.position(line, height_at_line))
		keeper_raised = outcome == "caught"
	if stop_at >= 0:
		ball.progress = lerpf(previous_progress, ball.progress, stop_at)
		if was_flying:
			ball.flight_fraction = lerpf(previous_fraction, ball.flight_fraction, stop_at)
			ball.flight_arc = previous_arc
			ball.flying = ball.flight_fraction < 1
		var stopped_keeper := _keeper_at(old_keeper, old_direction, old_time, dt * stop_at)
		keeper_x = stopped_keeper.x
		keeper_direction = int(stopped_keeper.y)
		keeper_time = old_time + dt * stop_at
		for i in defenders.size():
			defenders[i].x = lerpf(old_x[i], defenders[i].x, stop_at)
		ball.roll_speed = 0
	for body in defenders:
		var margin: float = projection.defender_half_width(body.y) / projection.design.x
		if body.active and (body.x > 1 + margin or body.x < -margin):
			body.active = false
