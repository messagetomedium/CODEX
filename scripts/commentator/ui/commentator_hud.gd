extends Control
const UI=preload("res://scripts/ui/ui_factory.gd")
const Karaoke=preload("res://scripts/commentator/ui/commentator_karaoke.gd")
var labels: Dictionary={}
var karaoke: Control
var interest: ProgressBar
var turn_text:=""

func rect(id: String) -> Rect2:
	var a: Array=App.config.data.commentator_layout.hud[id]
	return Rect2(Vector2(a[0],a[1])*App.design_size,Vector2(a[2],a[3])*App.design_size)

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for id in ["level","timer","turn","interest_label"]:
		labels[id]=UI.label(self,"",rect(id),30 if id!="turn" else 36,UI.PAPER)
		labels[id].add_theme_color_override("font_outline_color",UI.INK)
		labels[id].add_theme_constant_override("outline_size",6)
	labels.interest_label.text=App.texts.text("commentator.hud.interest")
	karaoke=Karaoke.new()
	karaoke.position=rect("karaoke").position
	karaoke.size=rect("karaoke").size
	add_child(karaoke)
	interest=ProgressBar.new()
	interest.position=rect("interest").position
	interest.size=rect("interest").size
	interest.show_percentage=false
	interest.mouse_filter=Control.MOUSE_FILTER_IGNORE
	interest.add_theme_stylebox_override("background",UI.style(UI.INK,UI.PAPER,5))
	interest.add_theme_stylebox_override("fill",UI.style(UI.ACCENT,Color.TRANSPARENT,5))
	add_child(interest)

func reset_round(model: RefCounted) -> void:
	karaoke.turn_seen=-1
	interest.set_meta("ui_follow_target",-1.0)
	if interest.has_meta("ui_follow_tween"):
		var tween: Tween=interest.get_meta("ui_follow_tween")
		if tween and tween.is_valid():tween.kill()
	interest.value=model.interest

func present(model: RefCounted, number: int, count: int) -> void:
	labels.level.text=App.texts.text("commentator.hud.level",{"round":number,"levelCount":count})+" · "+App.texts.text(model.timeline.level.name_key)
	labels.timer.text=App.texts.text("commentator.hud.time",{"seconds":ceili(maxf(0,model.timeline.level.duration_sec-model.elapsed))})
	var turn: Dictionary=model.timeline.turns[model.timeline.turn_at(model.elapsed)]
	var text: String=App.texts.text("commentator.hud.player" if turn.speaker=="player" else "commentator.hud.host")
	if turn.speaker=="host" and turn.end_sec-model.elapsed<=model.profile.warning_sec:
		text=App.texts.text("commentator.hud.countdown",{"seconds":ceili(turn.end_sec-model.elapsed)})
	if text!=turn_text:
		turn_text=text
		labels.turn.text=text
		App.animations.play(labels.turn,"commentator.turn")
	karaoke.present(model)
	App.animations.follow_value(interest,^"value",model.interest,"commentator.interest")
