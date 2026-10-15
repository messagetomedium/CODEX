extends Control
## Small code-drawn decoration contained in the safe notification rectangle.

func _draw() -> void:
	for i in 14:
		var x := size.x * (i + 0.5) / 14.0
		var y := size.y * (0.12 if i % 2 == 0 else 0.87)
		var color := Color("#edc55c") if i % 3 else Color("#bc5a48")
		draw_line(Vector2(x - 4, y - 4), Vector2(x + 4, y + 4), color, 4, true)
