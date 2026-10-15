extends Control
var team: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if team.is_empty():
		return
	var r := minf(size.x, size.y) * 0.44
	var c := size / 2
	var color := Color(team.primary_color)
	var outline := Color(team.text_color)
	var points := PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r * .8, r * .5), c + Vector2(0, r), c + Vector2(-r * .8, r * .5)])
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, outline, 3, true)
	match str(team.id):
		"sokoly_1960":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r*.7,-r*.4),c+Vector2(0,r*.4),c+Vector2(r*.7,-r*.4),c+Vector2(0,-r*.1)]), outline)
		"volna_1980":
			for i in 2:
				draw_polyline(PackedVector2Array([c+Vector2(-r*.65,r*(i*.3-.2)),c+Vector2(-r*.2,r*(i*.3-.4)),c+Vector2(r*.2,r*(i*.3-.1)),c+Vector2(r*.65,r*(i*.3-.3))]),outline,4,true)
		"impuls_2000":
			draw_colored_polygon(PackedVector2Array([c+Vector2(r*.2,-r*.7),c+Vector2(-r*.4,r*.1),c+Vector2(0,r*.1),c+Vector2(-r*.1,r*.6),c+Vector2(r*.45,-r*.2),c+Vector2(r*.1,-r*.2)]),outline)
		_:
			for i in 3:
				draw_rect(Rect2(c + Vector2(r*(i*.4-.55),-r*(.25+i*.13)),Vector2(r*.22,r*(.5+i*.22))),outline)
