extends Node2D
const Shapes=preload("res://scripts/goal/blockout_shapes.gd")

func _draw() -> void:
	var d: Vector2=App.design_size
	var spec: Dictionary=App.config.data.commentator_layout.world
	var ink:=Color(spec.booth)
	# Independent foreground layer, in front of optional archive media.
	draw_rect(Rect2(0,0,d.x,d.y*.045),ink)
	for x in [.035,.49,.945]:draw_rect(Rect2(d.x*x,0,d.x*.02,d.y*.67),ink)
	draw_rect(Rect2(0,d.y*.62,d.x,d.y*.055),ink)
	draw_colored_polygon(PackedVector2Array([Vector2(0,d.y*.68),Vector2(d.x,d.y*.68),d,Vector2(0,d.y)]),Color(spec.desk))
	draw_rect(Rect2(0,d.y*.97,d.x,d.y*.03),ink)
	# Microphone and notes are world props, with no extra interactive controls.
	draw_line(Vector2(d.x*.13,d.y*.86),Vector2(d.x*.16,d.y*.66),ink,12,true)
	draw_circle(Vector2(d.x*.16,d.y*.66),d.y*.027,ink)
	draw_rect(Rect2(d.x*.09,d.y*.85,d.x*.08,d.y*.012),ink)
	draw_colored_polygon(PackedVector2Array([Vector2(d.x*.79,d.y*.73),Vector2(d.x*.91,d.y*.74),Vector2(d.x*.89,d.y*.86),Vector2(d.x*.77,d.y*.84)]),Color(spec.paper))
	for row in 4:draw_line(Vector2(d.x*.80,d.y*(.76+row*.018)),Vector2(d.x*.88,d.y*(.76+row*.018)),ink,3)
