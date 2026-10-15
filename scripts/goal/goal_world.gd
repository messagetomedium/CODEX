extends Node2D
## Fixed camera and replaceable flat entities; mechanics live in the pure model.

const Entity = preload("res://scripts/goal/world_entity.gd")
var ball: Node2D
var keeper: Node2D
var defender: Node2D
var goal: Node2D
var feedback_tweens: Array[Tween] = []

func _ready() -> void:
	var composition: Dictionary = App.config.data.ui_layout.refComposition
	var layout: Dictionary = App.config.data.ui_layout.components.world
	var design: Vector2 = App.design_size
	goal = _entity("GoalMouth", "goal", design * Vector2(composition.goal.x, composition.goal.y), Vector2(design.x * composition.goal.widthFraction, design.y * layout.goalHeight))
	goal.frame_width = maxf(4, goal.dimensions.x * layout.goalFrameWidthFraction)
	keeper = _entity("Goalkeeper", "keeper", goal.position, Vector2(0, design.y * layout.keeperHeight))
	defender = _entity("Defender", "defender", design * Vector2(layout.defenderX, layout.defenderY), Vector2(0, design.y * layout.defenderHeight))
	ball = _entity("Ball", "ball", design * Vector2(composition.ballAtStart.x, composition.ballAtStart.y), Vector2(design.x * composition.ballAtStart.diameterFractionOfWidth / 2, 0))
	ball.shadow_contact = App.config.data.gameplay.ball.shadowContactRadiusFraction

func present(simulation: RefCounted) -> void:
	var projection: RefCounted = simulation.projection
	ball.position = projection.position(simulation.ball.progress, simulation.ball.height())
	ball.scale = Vector2.ONE * projection.ball_scale(simulation.ball.progress)
	ball.shadow_drop = simulation.ball.height() / ball.scale.y
	ball.queue_redraw()
	keeper.position.x = simulation.keeper_x * App.design_size.x
	defender.visible = simulation.defender_active
	defender.position = Vector2(simulation.defender_x, simulation.defender_y) * App.design_size
	defender.dimensions.y = projection.defender_height(simulation.defender_y)
	defender.queue_redraw()
	# Occlusion follows ground depth, independent of the visual flight height.
	goal.z_index = int(goal.position.y) - 1
	keeper.z_index = int(keeper.position.y)
	defender.z_index = int(defender.position.y)
	ball.z_index = int(projection.position(simulation.ball.progress).y + projection.radius(simulation.ball.progress) * ball.shadow_contact)
	if simulation.keeper_raised:
		keeper.z_index = ball.z_index + 1
		keeper.catch_offset = ball.position - keeper.position
		keeper.catch_radius = projection.radius(simulation.ball.progress) * App.config.data.gameplay.goalkeeper.raisedHandsWidthRadiusFraction

func react(outcome: String) -> void:
	if outcome == "goal":
		var spec: Dictionary = App.config.data.ui_animations.profiles["world.goalNet"].impact
		feedback_tweens.append(App.animations.animate_property(goal, ^"net_scale", Vector2(spec.from.scaleX, spec.from.scaleY), Vector2(spec.to.scaleX, spec.to.scaleY), "world.goalNet", "impact"))
	elif outcome == "caught":
		var spec: Dictionary = App.config.data.ui_animations.profiles["world.goalkeeperCatch"].impact
		feedback_tweens.append(App.animations.animate_property(keeper, ^"raise_amount", spec.from.value, spec.to.value, "world.goalkeeperCatch", "impact"))

func reset_feedback() -> void:
	for tween in feedback_tweens:
		if tween and tween.is_valid():
			tween.kill()
	feedback_tweens.clear()
	goal.net_scale = Vector2.ONE
	keeper.raise_amount = 0

func protected_rects(simulation: RefCounted) -> Array[Rect2]:
	var projection: RefCounted = simulation.projection
	var result: Array[Rect2] = [projection.goal_rect().grow(projection.frame_width() / 2)]
	var keeper_size := Vector2(keeper.dimensions.y * App.config.data.gameplay.defender.hitboxWidthToHeight, keeper.dimensions.y)
	result.append(Rect2(keeper.position - Vector2(keeper_size.x / 2, keeper_size.y), keeper_size))
	if defender.visible:
		var defender_size := Vector2(defender.dimensions.y * App.config.data.gameplay.defender.hitboxWidthToHeight, defender.dimensions.y)
		result.append(Rect2(defender.position - Vector2(defender_size.x / 2, defender_size.y), defender_size))
	var radius: float = projection.radius(simulation.ball.progress)
	result.append(Rect2(ball.position - Vector2.ONE * radius, Vector2.ONE * radius * 2))
	return result

func _entity(id: String, kind: String, location: Vector2, dimensions: Vector2) -> Node2D:
	var entity := Entity.new()
	entity.name = id
	entity.kind = kind
	entity.position = location
	entity.dimensions = dimensions
	add_child(entity)
	return entity

func _draw() -> void:
	var w: float = App.design_size.x
	var h: float = App.design_size.y
	var horizon: float = App.config.data.ui_layout.components.world.horizonY * h
	draw_rect(Rect2(0, 0, w, h), Color("#83b4c4"))
	# Solid, flat stadium tiers approximate the reference's bowl, not its artwork.
	for side in [-1, 1]:
		var edge := 0.0 if side == -1 else w
		draw_colored_polygon(PackedVector2Array([Vector2(edge, h * 0.15), Vector2(w * 0.5, h * 0.36), Vector2(w * 0.5, horizon), Vector2(edge, horizon)]), Color("#d5b09a"))
		for row in 3:
			var y := h * (0.23 + row * 0.075)
			var middle_y := h * (0.39 + row * 0.022)
			draw_line(Vector2(edge, y), Vector2(w * 0.5, middle_y), Color("#597c8e") if row % 2 == 0 else Color("#bc6655"), 35, true)
	for row in 3:
		for col in 30:
			var x := w * (col + 0.5) / 30.0
			var edge_distance := absf(x - w / 2) / (w / 2)
			var y := h * (0.36 - edge_distance * 0.13 + row * 0.045)
			draw_circle(Vector2(x, y), 7, Color("#e6c8a5"))
			draw_line(Vector2(x, y + 9), Vector2(x, y + 23), Color("#eee9dd") if (col + row) % 3 else Color("#b85144"), 12, true)
	draw_rect(Rect2(0, horizon - 45, w, 45), Color("#355764"))
	draw_rect(Rect2(0, horizon, w, h - horizon), Color("#62895d"))
	for i in 7:
		var top := horizon + pow(i / 7.0, 1.7) * (h - horizon)
		var bottom := horizon + pow((i + 1) / 7.0, 1.7) * (h - horizon)
		if i % 2 == 0:
			draw_rect(Rect2(0, top, w, bottom - top), Color("#6c9464"))
	var line_color := Color("#e7e3c9")
	draw_line(Vector2(w * 0.34, horizon), Vector2(-w * 0.1, h), line_color, 5, true)
	draw_line(Vector2(w * 0.66, horizon), Vector2(w * 1.1, h), line_color, 5, true)
	draw_polyline(PackedVector2Array([Vector2(w * 0.3, horizon + h * 0.02), Vector2(w * 0.19, h * 0.64), Vector2(w * 0.81, h * 0.64), Vector2(w * 0.7, horizon + h * 0.02)]), line_color, 4, true)
	draw_polyline(PackedVector2Array([Vector2(w * 0.39, horizon + h * 0.01), Vector2(w * 0.35, h * 0.55), Vector2(w * 0.65, h * 0.55), Vector2(w * 0.61, horizon + h * 0.01)]), line_color, 3, true)
