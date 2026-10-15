extends Node2D
const Media=preload("res://scripts/commentator/commentator_media.gd")
const Booth=preload("res://scripts/commentator/booth_layer.gd")
const Shapes=preload("res://scripts/goal/blockout_shapes.gd")
var media: Node2D
var decoration_time:=0.0

func _ready() -> void:
	media=Media.new()
	media.name="ReplaceableMedia"
	add_child(media)
	var booth:=Booth.new()
	booth.name="BoothForeground"
	add_child(booth)

func _process(delta: float) -> void:
	decoration_time+=delta*App.config.data.commentator_layout.world.decoration_speed
	queue_redraw()

func _draw() -> void:
	var d: Vector2=App.design_size
	var spec: Dictionary=App.config.data.commentator_layout.world
	draw_rect(Rect2(Vector2.ZERO,d),Color(spec.sky))
	for row in 4:
		draw_rect(Rect2(0,d.y*(.20+row*.035),d.x,d.y*.03),Color(spec.stand).lightened(row*.05))
		for col in 42:
			draw_rect(Rect2(d.x*(col+.4)/42,d.y*(.205+row*.035),d.x*.009,d.y*.014),Color(spec.paper) if (row+col)%2 else Color(spec.booth))
	draw_rect(Rect2(0,d.y*.34,d.x,d.y*.30),Color(spec.grass))
	for row in 6:
		if row%2==0:draw_rect(Rect2(0,d.y*(.34+row*.05),d.x,d.y*.05),Color(spec.grass_alt))
	var line:=Color(spec.paper)
	draw_rect(Rect2(d.x*.14,d.y*.37,d.x*.72,d.y*.24),line,false,3)
	draw_line(Vector2(d.x*.5,d.y*.37),Vector2(d.x*.5,d.y*.61),line,3)
	draw_arc(Vector2(d.x*.5,d.y*.49),d.y*.055,0,TAU,40,line,3,true)
	Shapes.goal(self,Rect2(d.x*.10,d.y*.43,d.x*.055,d.y*.07))
	Shapes.goal(self,Rect2(d.x*.845,d.y*.43,d.x*.055,d.y*.07))
	for i in 10:
		var p:=Vector2(d.x*(.25+(i%5)*.12+sin(decoration_time+i)*.015),d.y*(.43+(i/5)*.11+cos(decoration_time+i)*.012))
		Shapes.person(self,p,d.y*spec.player_height_fraction,Color(spec.player_colors[i/5]),false)
	Shapes.ball(self,Vector2(d.x*(.5+sin(decoration_time)*.16),d.y*(.50+cos(decoration_time*.7)*.06)),d.y*.009)
