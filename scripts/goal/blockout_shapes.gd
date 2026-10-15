extends RefCounted
## Flat primitives shared by the world and replaceable illustration slots.

static func ball(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius, Color("#f5edda"))
	canvas.draw_arc(center, radius, 0, TAU, 64, Color("#183746"), maxf(1, radius * 0.025), true)
	var patches: Array[Vector2] = [Vector2.ZERO]
	for i in 5:
		patches.append(Vector2.from_angle(-PI / 2 + i * TAU / 5) * radius * 0.72)
	for offset in patches:
		var points := PackedVector2Array()
		var patch_radius := radius * (0.3 if offset == Vector2.ZERO else 0.19)
		for i in 5:
			points.append(center + offset + Vector2.from_angle(-PI / 2 + i * TAU / 5) * patch_radius)
		canvas.draw_colored_polygon(points, Color("#183746"))
		if offset != Vector2.ZERO:
			canvas.draw_line(center + offset * 0.38, center + offset * 0.77, Color("#183746"), maxf(1, radius * 0.018), true)

static func person(canvas: CanvasItem, feet: Vector2, height: float, jersey: Color, keeper: bool = false, raised: float = 0, catch_offset: Vector2 = Vector2.ZERO, catch_radius: float = 0) -> void:
	var h := height
	var skin := Color("#d7aa78")
	var ink := Color("#183746")
	var hip := feet + Vector2(0, -h * 0.35)
	canvas.draw_line(hip + Vector2(-h * 0.06, 0), feet + Vector2(-h * 0.2, -h * 0.025), ink, h * 0.09, true)
	canvas.draw_line(hip + Vector2(h * 0.06, 0), feet + Vector2(h * 0.18, -h * 0.025), ink, h * 0.09, true)
	canvas.draw_line(feet + Vector2(-h * 0.24, 0), feet + Vector2(-h * 0.1, 0), ink, h * 0.07, true)
	canvas.draw_line(feet + Vector2(h * 0.13, 0), feet + Vector2(h * 0.26, 0), ink, h * 0.07, true)
	var body := PackedVector2Array([feet + Vector2(-h * 0.15, -h * 0.74), feet + Vector2(h * 0.15, -h * 0.74), feet + Vector2(h * 0.13, -h * 0.4), feet + Vector2(-h * 0.13, -h * 0.4)])
	canvas.draw_colored_polygon(body, jersey)
	canvas.draw_rect(Rect2(feet + Vector2(-h * 0.14, -h * 0.42), Vector2(h * 0.28, h * 0.12)), Color("#f5edda"))
	var arm_y := -h * (0.46 if keeper else 0.51)
	for direction in [-1, 1]:
		var wrist := Vector2(direction * h * 0.28, arm_y).lerp(catch_offset + Vector2(direction * catch_radius, 0), raised)
		canvas.draw_line(feet + Vector2(direction * h * 0.12, -h * 0.68), feet + wrist, jersey, h * 0.09, true)
		canvas.draw_circle(feet + wrist, h * 0.055, Color("#f5edda") if keeper else skin)
	canvas.draw_circle(feet + Vector2(0, -h * 0.85), h * 0.105, skin)
	canvas.draw_arc(feet + Vector2(0, -h * 0.87), h * 0.09, PI, TAU, 12, ink, h * 0.055, true)

static func goal(canvas: CanvasItem, rect: Rect2, frame_width: float = -1, net_scale: Vector2 = Vector2.ONE) -> void:
	canvas.draw_rect(rect, Color(0.07, 0.21, 0.24, 0.4))
	var net := Color(0.98, 0.96, 0.88, 0.45)
	for i in range(1, 15):
		var x := rect.position.x + rect.size.x * i / 15.0
		var center := rect.get_center()
		canvas.draw_polyline(PackedVector2Array([Vector2(x, rect.position.y), Vector2(center.x + (x - center.x) * net_scale.x, center.y), Vector2(x, rect.end.y)]), net, 2, true)
	for i in range(1, 7):
		var y := rect.position.y + rect.size.y * i / 7.0
		var center := rect.get_center()
		canvas.draw_polyline(PackedVector2Array([Vector2(rect.position.x, y), Vector2(center.x, center.y + (y - center.y) * net_scale.y), Vector2(rect.end.x, y)]), net, 2, true)
	canvas.draw_polyline(PackedVector2Array([Vector2(rect.position.x, rect.end.y), rect.position, Vector2(rect.end.x, rect.position.y), rect.end]), Color("#faf6ed"), maxf(4, rect.size.x * 0.022) if frame_width < 0 else frame_width, true)
