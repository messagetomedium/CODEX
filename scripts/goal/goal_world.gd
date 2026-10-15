extends Node2D
## Static 2.5D composition. Individual entities can be replaced independently.

const Entity = preload("res://scripts/goal/world_entity.gd")
var ball: Node2D
var keeper: Node2D
var defender: Node2D
var goal: Node2D

func _ready() -> void:
	var composition: Dictionary = App.config.data.ui_layout.refComposition
	var layout: Dictionary = App.config.data.ui_layout.components.world
	var design: Vector2 = App.design_size
	goal = _entity("GoalMouth", "goal", design * Vector2(composition.goal.x, composition.goal.y), Vector2(design.x * composition.goal.widthFraction, design.y * layout.goalHeight))
	keeper = _entity("Goalkeeper", "keeper", goal.position, Vector2(0, design.y * layout.keeperHeight))
	defender = _entity("Defender", "defender", design * Vector2(layout.defenderX, layout.defenderY), Vector2(0, design.y * layout.defenderHeight))
	ball = _entity("Ball", "ball", design * Vector2(composition.ballAtStart.x, composition.ballAtStart.y), Vector2(design.x * composition.ballAtStart.diameterFractionOfWidth / 2, 0))

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
