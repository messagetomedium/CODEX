extends Node2D

const Shapes = preload("res://scripts/goal/blockout_shapes.gd")
var kind := "ball"
var dimensions := Vector2.ZERO

func _draw() -> void:
	match kind:
		"ball":
			draw_set_transform(Vector2(0, dimensions.x * 0.88), 0, Vector2(1, 0.16))
			draw_circle(Vector2.ZERO, dimensions.x * 1.1, Color(0.06, 0.15, 0.12, 0.24))
			draw_set_transform(Vector2.ZERO)
			Shapes.ball(self, Vector2.ZERO, dimensions.x)
		"goal":
			Shapes.goal(self, Rect2(Vector2(-dimensions.x / 2, -dimensions.y), dimensions))
		"keeper", "defender":
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.2))
			draw_circle(Vector2.ZERO, dimensions.y * 0.28, Color(0.06, 0.15, 0.12, 0.2))
			draw_set_transform(Vector2.ZERO)
			Shapes.person(self, Vector2.ZERO, dimensions.y, Color("#e6b94f") if kind == "keeper" else Color("#bc5a48"), kind == "keeper")
