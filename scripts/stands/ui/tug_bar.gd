extends Control
const Geometry = preload("res://scripts/stands/logic/tug_geometry.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
var player_color := Color("#c64343")
var opponent_color := Color("#2966ab")
var value := 50.0:
	set(next):
		value = clampf(next, 0, 100)
		queue_redraw()
var is_player_turn := false

func set_turn(player: bool) -> void:
	is_player_turn = player
	if has_meta("ui_follow_tween"):
		var tween: Tween = get_meta("ui_follow_tween")
		if tween and tween.is_valid():
			tween.kill()
	set_meta("ui_follow_target", -1.0)

func follow_score(score: float, finished: bool = false) -> void:
	# Smoothing must never reverse the displayed direction at a turn boundary.
	# At completion, show the final score even though no side has an active turn.
	var target := score if finished else (maxf(score, value) if is_player_turn else minf(score, value))
	App.animations.follow_value(self, ^"value", target, "stands.tug_marker_follow")

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_style_box(UI.style(UI.INK, UI.PAPER, 7), Rect2(Vector2(-3,-3), size+Vector2(6,6)))
	for i in 20:
		draw_rect(Rect2(i*w/20+1, 1, w/20-2, h-2), player_color if i<10 else opponent_color)
	# The white segment matches the actual inclusive draw range.
	var scoring: Dictionary = App.config.data.stands_gameplay.score
	var neutral_left := Geometry.marker_fraction(scoring.center+scoring.draw_tolerance)*w
	var neutral_right := Geometry.marker_fraction(scoring.center-scoring.draw_tolerance)*w
	draw_rect(Rect2(neutral_left,1,neutral_right-neutral_left,h-2),Color.WHITE)
	var x := Geometry.marker_fraction(value) * w
	draw_colored_polygon(PackedVector2Array([Vector2(x,-13),Vector2(x+12,h/2),Vector2(x,h+13),Vector2(x-12,h/2)]),UI.PAPER)
	draw_polyline(PackedVector2Array([Vector2(x,-13),Vector2(x+12,h/2),Vector2(x,h+13),Vector2(x-12,h/2),Vector2(x,-13)]),UI.INK,2,true)
