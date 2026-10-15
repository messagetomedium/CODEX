extends Control
## Deliberately geometric placeholders, never the reference image as a backdrop.

const Shapes = preload("res://scripts/goal/blockout_shapes.gd")
var kind := "goal"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := Color("#183746")
	var cream := Color("#faf6ed")
	match kind:
		"goal":
			draw_style_box(preload("res://scripts/ui/ui_factory.gd").style(Color("#80abb3"), Color.TRANSPARENT, 16), Rect2(Vector2.ZERO, size))
			draw_rect(Rect2(0, h * 0.46, w, h * 0.54), Color("#628a65"))
			Shapes.goal(self, Rect2(w * 0.28, h * 0.25, w * 0.44, h * 0.3))
			draw_line(Vector2(w * 0.26, h * 0.58), Vector2(w * 0.05, h), cream, 2, true)
			draw_line(Vector2(w * 0.74, h * 0.58), Vector2(w * 0.95, h), cream, 2, true)
			Shapes.ball(self, Vector2(w * 0.5, h * 0.78), h * 0.15)
		"stands":
			draw_style_box(preload("res://scripts/ui/ui_factory.gd").style(Color("#76969d"), Color.TRANSPARENT, 16), Rect2(Vector2.ZERO, size))
			for row in 3:
				for col in 6:
					var p := Vector2(w * (0.14 + col * 0.145), h * (0.25 + row * 0.22))
					draw_rect(Rect2(p + Vector2(-w * 0.044, h * 0.035), Vector2(w * 0.088, h * 0.13)), cream if (row + col) % 2 else ink)
					draw_circle(p, h * 0.038, Color("#dfc6a1"))
		"commentator":
			draw_style_box(preload("res://scripts/ui/ui_factory.gd").style(Color("#ad9182"), Color.TRANSPARENT, 16), Rect2(Vector2.ZERO, size))
			draw_arc(Vector2(w * 0.5, h * 0.4), h * 0.2, PI, TAU, 32, cream, h * 0.035, true)
			draw_line(Vector2(w * 0.5 - h * 0.2, h * 0.4), Vector2(w * 0.5 - h * 0.2, h * 0.59), cream, h * 0.08, true)
			draw_line(Vector2(w * 0.5 + h * 0.2, h * 0.4), Vector2(w * 0.5 + h * 0.2, h * 0.59), cream, h * 0.08, true)
			draw_line(Vector2(w * 0.5 + h * 0.2, h * 0.59), Vector2(w * 0.54, h * 0.72), cream, h * 0.025, true)
			draw_circle(Vector2(w * 0.54, h * 0.72), h * 0.045, ink)
		"voice-roll":
			draw_line(Vector2(w * 0.18, h * 0.72), Vector2(w * 0.82, h * 0.72), ink, 3, true)
			Shapes.ball(self, Vector2(w * 0.65, h * 0.48), h * 0.22)
			for i in 3:
				draw_line(Vector2(w * (0.2 + i * 0.07), h * (0.3 + i * 0.13)), Vector2(w * 0.42, h * (0.3 + i * 0.13)), ink, 3, true)
		"turn_wait":
			for side in [-1, 1]:
				draw_circle(Vector2(w * (0.5 + side * 0.13), h * 0.35), h * 0.16, ink)
				draw_rect(Rect2(w * (0.5 + side * 0.13) - h * 0.16, h * 0.54, h * 0.32, h * 0.4), Color("#bc5a48") if side < 0 else Color("#2966ab"))
		"voice_burst":
			for i in 5:
				var height := h * (0.3 + (2 - absi(i - 2)) * 0.25)
				draw_rect(Rect2(w * (0.32 + i * 0.075), (h - height) / 2, w * 0.04, height), ink)
		"tug_marker":
			draw_line(Vector2(w * 0.2, h * 0.6), Vector2(w * 0.8, h * 0.6), ink, 7, true)
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.4, h * 0.12), Vector2(w * 0.35, h * 0.45), Vector2(w * 0.45, h * 0.45)]), Color("#bc5a48"))
		"voice-kick":
			draw_arc(Vector2(w * 0.5, h * 0.85), h * 0.65, PI * 1.1, PI * 1.9, 24, ink, 3, true)
			Shapes.ball(self, Vector2(w * 0.76, h * 0.65), h * 0.17)
		"timing":
			Shapes.goal(self, Rect2(w * 0.2, h * 0.15, w * 0.6, h * 0.68))
			Shapes.person(self, Vector2(w * 0.48, h * 0.85), h * 0.6, Color("#cb7255"), true)
