extends Control
const Geometry = preload("res://scripts/stands/logic/tug_geometry.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
var player_color := Color("#c64343")
var opponent_color := Color("#2966ab")
var target_marker := 55.0
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

func follow_score(score: float) -> void:
	# Smoothing must never reverse the displayed direction at a turn boundary.
	var target := maxf(score, value) if is_player_turn else minf(score, value)
	App.animations.follow_value(self, ^"value", target, "stands.tug_marker_follow")

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_style_box(UI.style(UI.INK, UI.PAPER, 7), Rect2(Vector2(-3,-3), size+Vector2(6,6)))
	for i in 20:
		draw_rect(Rect2(i*w/20+1, 1, w/20-2, h-2), player_color if i<10 else opponent_color)
	draw_line(Vector2(w/2,-9),Vector2(w/2,h+9),UI.PAPER,3,true)
	var target := Geometry.marker_fraction(target_marker) * w
	draw_line(Vector2(target,-7),Vector2(target,h+7),UI.ACCENT,4,true)
	var x := Geometry.marker_fraction(value) * w
	draw_colored_polygon(PackedVector2Array([Vector2(x,-13),Vector2(x+12,h/2),Vector2(x,h+13),Vector2(x-12,h/2)]),UI.PAPER)
	draw_polyline(PackedVector2Array([Vector2(x,-13),Vector2(x+12,h/2),Vector2(x,h+13),Vector2(x-12,h/2),Vector2(x,-13)]),UI.INK,2,true)
