extends Node2D
const Crowd = preload("res://scripts/stands/crowd_visual.gd")
var player: Node2D
var opponent: Node2D

func _ready() -> void:
	player = Crowd.new()
	player.name = "PlayerStand"
	player.side = -1
	add_child(player)
	opponent = Crowd.new()
	opponent.name = "OpponentStand"
	opponent.side = 1
	add_child(opponent)

func set_teams(left: Dictionary, right: Dictionary) -> void:
	player.set_team(left)
	opponent.set_team(right)

func set_turn(is_player: bool, level: float = 0) -> void:
	player.set_state("cheer" if is_player else "idle")
	opponent.set_state("idle" if is_player else "cheer")
	player.set_intensity(level)
	opponent.set_intensity(1)

func idle() -> void:
	player.set_state("idle")
	opponent.set_state("idle")

func _draw() -> void:
	var d: Vector2 = App.design_size
	var w := d.x
	var h := d.y
	var config: Dictionary = App.config.data.stands_layout.world
	draw_rect(Rect2(Vector2.ZERO,d),Color(config.sky))
	for side in [-1,1]:
		var edge := 0.0 if side<0 else w
		draw_colored_polygon(PackedVector2Array([Vector2(edge,h*.16),Vector2(w*.5,h*.36),Vector2(w*.5,h*.55),Vector2(edge,h*.51)]),Color("#d5b09a"))
		var x := w*(.14 if side<0 else .86)
		draw_line(Vector2(x,h*.29),Vector2(x+side*w*.012,h*.055),Color("#597c8e"),10,true)
		var lamp := Rect2(x-w*.035,h*.035,w*.07,h*.07)
		draw_rect(lamp,Color("#597c8e"))
		for col in 3:
			for row in 2:
				draw_circle(lamp.position+Vector2(lamp.size.x*(col+.5)/3,lamp.size.y*(row+.5)/2),h*.011,Color("#faf6ed"))
	draw_rect(Rect2(w*.462,h*.38,w*.076,h*.18),Color("#355764"))
	draw_rect(Rect2(w*.478,h*.40,w*.044,h*.16),Color("#597c8e"))
	draw_rect(Rect2(0,h*config.horizon,w,h*(1-config.horizon)),Color(config.grass))
	for row in 7:
		if row%2==0:
			draw_rect(Rect2(0,h*(config.horizon+row*.07),w,h*.07),Color(config.grass_alt))
	var line := Color("#e7e3c9")
	draw_line(Vector2(w*.5,h*.56),Vector2(w*.5,h),line,6,true)
	draw_line(Vector2(w*.46,h*.56),Vector2(w*.05,h),line,5,true)
	draw_line(Vector2(w*.54,h*.56),Vector2(w*.95,h),line,5,true)
	draw_arc(Vector2(w*.5,h*1.18),w*.23,PI*1.15,PI*1.85,40,line,5,true)
