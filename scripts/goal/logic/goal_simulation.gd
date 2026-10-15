extends RefCounted
## Deterministic mechanics. Outcomes latch once; a UI pause simply stops step().
## Spawns are supplied externally; this model never samples randomness.

const Ball = preload("res://scripts/goal/logic/ball_motion.gd")
const FieldProjection = preload("res://scripts/goal/logic/field_projection.gd")
const Collision = preload("res://scripts/goal/logic/screen_collision.gd")
var settings: Dictionary
var projection: RefCounted
var ball: RefCounted
var keeper_x := 0.5
var keeper_direction := 1
var defender_active := false
var defender_x := 0.0
var defender_y := 0.0
var defender_direction := 1
var outcome := ""

func _init(config: Dictionary, layout: Dictionary) -> void:
	settings = config
	projection = FieldProjection.new(config, layout)
	ball = Ball.new(config)
	keeper_x = layout.refComposition.goal.x

func spawn_defender(direction: int, lane_y: float) -> bool:
	if defender_active or not outcome.is_empty():
		return false
	defender_direction = 1 if direction >= 0 else -1
	defender_y = clampf(lane_y, settings.defender.laneYNormalizedMin, settings.defender.laneYNormalizedMax)
	var margin: float = projection.defender_half_width(defender_y) / projection.design.x
	defender_x = -margin if defender_direction > 0 else 1 + margin
	defender_active = true
	return true

func patrol(x: float, direction: int, seconds: float) -> Vector2:
	var left: float = settings.goalkeeper.patrolLeftX
	var right: float = settings.goalkeeper.patrolRightX
	var span := right - left
	# Unfold/refold a triangle wave: exact reflection at constant speed, any delta.
	var phase := x - left if direction > 0 else 2 * span - (x - left)
	phase = fposmod(phase + span * seconds / settings.goalkeeper.crossScreenSeconds, 2 * span)
	return Vector2(left + (phase if phase < span else 2 * span - phase), 1 if phase < span else -1)

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
	var previous_height: float = ball.height()
	var previous_arc: float = ball.flight_arc
	var was_flying: bool = ball.flying
	var old_position: Vector2 = projection.position(previous_progress, previous_height)
	var old_radius: float = projection.radius(previous_progress)
	var old_keeper := keeper_x
	var old_direction := keeper_direction
	var old_defender := defender_x
	ball.advance(dt, rolling)
	var moved_keeper := patrol(keeper_x, keeper_direction, dt)
	keeper_x = moved_keeper.x
	keeper_direction = int(moved_keeper.y)
	var margin: float = projection.defender_half_width(defender_y) / projection.design.x
	if defender_active:
		defender_x += defender_direction * (1 + 2 * margin) * dt / settings.defender.crossScreenSeconds
	var line: float = settings.ball.progressAtGoalLine
	var crossing: float = (line - previous_progress) / (ball.progress - previous_progress) if previous_progress < line and ball.progress >= line else -1.0
	var contact := -1.0
	# READY is indefinite: an untouched ball does not resolve an attempt.
	if defender_active and ball.has_moved:
		# Clip the sweep to the goal crossing; projection clamps beyond the line.
		var limit := crossing if crossing >= 0 else 1.0
		var end_progress := lerpf(previous_progress, ball.progress, limit)
		var end_height: float = ball.height()
		if was_flying:
			end_height = previous_arc * sin(PI * lerpf(previous_fraction, ball.flight_fraction, limit))
		contact = Collision.first_contact(old_position, projection.position(end_progress, end_height), old_radius, projection.radius(end_progress), projection.defender_rect(old_defender, defender_y), projection.defender_rect(lerpf(old_defender, defender_x, limit), defender_y))
		if contact >= 0:
			contact *= limit
	var stop_at := -1.0
	if contact >= 0 and (crossing < 0 or contact <= crossing + 0.000001):
		outcome = "intercept"
		stop_at = contact
	elif crossing >= 0:
		stop_at = crossing
		var at_line := patrol(old_keeper, old_direction, dt * crossing)
		var keeper_half_width: float = settings.goalkeeper.hitboxWidthFractionOfCanvas * projection.design.x / 2
		var distance: float = absf(at_line.x - settings.ball.xNormalized) * projection.design.x
		outcome = "saved" if distance <= keeper_half_width + projection.radius(line) else "goal"
	if stop_at >= 0:
		# Freeze all entities at the first event, not at the end of the render frame.
		ball.progress = lerpf(previous_progress, ball.progress, stop_at)
		if was_flying:
			ball.flight_fraction = lerpf(previous_fraction, ball.flight_fraction, stop_at)
			ball.flight_arc = previous_arc
			ball.flying = ball.flight_fraction < 1
		var stopped_keeper := patrol(old_keeper, old_direction, dt * stop_at)
		keeper_x = stopped_keeper.x
		keeper_direction = int(stopped_keeper.y)
		defender_x = lerpf(old_defender, defender_x, stop_at)
		ball.roll_speed = 0
	if defender_active and (defender_x > 1 + margin or defender_x < -margin):
		defender_active = false
