extends RefCounted
## Shared projection from logical field depth to flat sprites, at design resolution.

var settings: Dictionary
var layout: Dictionary
var design: Vector2
var start_radius: float

func _init(config: Dictionary, ui_layout: Dictionary) -> void:
	settings = config
	layout = ui_layout
	design = Vector2(layout.baseResolution.width, layout.baseResolution.height)
	start_radius = design.x * layout.refComposition.ballAtStart.diameterFractionOfWidth / 2

func fraction(progress: float) -> float:
	return clampf(inverse_lerp(settings.ball.progressAtStart, settings.ball.progressAtGoalLine, progress), 0, 1)

func ball_scale(progress: float) -> float:
	return lerpf(1, settings.ball.scaleAtGoalLine, fraction(progress))

func radius(progress: float) -> float:
	return start_radius * ball_scale(progress)

func position(progress: float, height: float = 0) -> Vector2:
	var start_y: float = layout.refComposition.ballAtStart.y * design.y
	var end_y: float = layout.refComposition.goal.y * design.y - radius(settings.ball.progressAtGoalLine) * settings.ball.shadowContactRadiusFraction
	return Vector2(settings.ball.xNormalized * design.x, lerpf(start_y, end_y, fraction(progress)) - height)

func ground_y(progress: float) -> float:
	# Compare feet with the ball's ground contact, never with its airborne center.
	return position(progress).y + radius(progress) * settings.ball.shadowContactRadiusFraction

func depth_at_ground_y(lane_y: float) -> float:
	var start: float = settings.ball.progressAtStart
	var finish: float = settings.ball.progressAtGoalLine
	return lerpf(start, finish, inverse_lerp(ground_y(start), ground_y(finish), lane_y * design.y))

func defender_height(lane_y: float) -> float:
	var depth := clampf(inverse_lerp(layout.refComposition.goal.y, settings.defender.laneYNormalizedMax, lane_y), 0, 1)
	return design.y * lerpf(layout.components.world.keeperHeight, layout.components.world.defenderHeight, depth)

func defender_half_width(lane_y: float) -> float:
	return defender_height(lane_y) * settings.defender.hitboxWidthToHeight / 2

func defender_rect(x: float, lane_y: float) -> Rect2:
	var h := defender_height(lane_y)
	var full_size := Vector2(h * settings.defender.hitboxWidthToHeight, h)
	var inset: Vector2 = full_size * settings.defender.hitboxInsetFraction
	return Rect2(Vector2(x * design.x, lane_y * design.y) - Vector2(full_size.x / 2, h) + inset, full_size - inset * 2)

func goal_rect() -> Rect2:
	var goal: Dictionary = layout.refComposition.goal
	var size := Vector2(goal.widthFraction * design.x, layout.components.world.goalHeight * design.y)
	return Rect2(Vector2(goal.x * design.x - size.x / 2, goal.y * design.y - size.y), size)

func frame_width() -> float:
	return maxf(4, goal_rect().size.x * layout.components.world.goalFrameWidthFraction)

func hits_frame(center: Vector2, ball_radius: float) -> bool:
	var rect := goal_rect()
	var half := frame_width() / 2
	# The visible rim may graze the frame and still score. Only the inner core
	# counts as contact; a center outside the mouth is never awarded a goal.
	ball_radius *= float(settings.goalFrame.ballContactRadiusFraction)
	if center.x < rect.position.x - half or center.x > rect.end.x + half or center.y < rect.position.y - half:
		return true
	var parts := [Rect2(rect.position - Vector2(half, half), Vector2(rect.size.x + 2 * half, 2 * half)), Rect2(rect.position - Vector2(half, half), Vector2(2 * half, rect.size.y + half)), Rect2(Vector2(rect.end.x - half, rect.position.y - half), Vector2(2 * half, rect.size.y + half))]
	for part: Rect2 in parts:
		var closest := center.clamp(part.position, part.end)
		if center.distance_squared_to(closest) <= ball_radius * ball_radius:
			return true
	return false
