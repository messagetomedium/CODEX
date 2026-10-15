extends Control
const UI = preload("res://scripts/ui/ui_factory.gd")
const Tug = preload("res://scripts/stands/ui/tug_bar.gd")
var labels: Dictionary = {}
var plates: Dictionary = {}
var tug: Control
var turn_seen := -1
var left_team: Dictionary
var right_team: Dictionary

func rect(id: String) -> Rect2:
	var a: Array = App.config.data.stands_layout.hud[id]
	return Rect2(Vector2(a[0],a[1])*App.design_size,Vector2(a[2],a[3])*App.design_size)

func panel(id: String, text: String, font: int) -> Label:
	var box := Panel.new()
	box.position=rect(id).position
	box.size=rect(id).size
	box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel",UI.style(UI.PAPER,UI.INK,12))
	add_child(box)
	plates[id]=box
	var label := UI.label(box,text,Rect2(Vector2.ZERO,box.size),font)
	labels[id]=label
	return label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fonts: Dictionary = App.config.data.stands_layout.fonts
	panel("banner",App.texts.text("stands.hud.top_banner"),fonts.banner)
	panel("round","",fonts.round)
	panel("time","",fonts.round)
	panel("player_name","",fonts.team)
	panel("opponent_name","",fonts.team)
	panel("player_turn",App.texts.text("stands.turn.player"),fonts.turn)
	panel("opponent_turn",App.texts.text("stands.turn.opponent"),fonts.turn)
	panel("chant","",fonts.chant)
	tug=Tug.new()
	tug.name="TugBar"
	tug.position=rect("tug").position
	tug.size=rect("tug").size
	add_child(tug)

func set_teams(left: Dictionary, right: Dictionary) -> void:
	left_team=left
	right_team=right
	tug.player_color=Color(left.primary_color)
	tug.opponent_color=Color(right.primary_color)
	for id in ["player_name","opponent_name"]:
		var team: Dictionary = left if id=="player_name" else right
		labels[id].text=App.texts.text(team.name_key)+" · "+str(team.era)
		labels[id].add_theme_color_override("font_color",Color(team.text_color))
		plates[id].add_theme_stylebox_override("panel",UI.style(Color(team.primary_color),UI.PAPER,12))

func reset_round() -> void:
	turn_seen=-1
	tug.value=App.config.data.stands_gameplay.score.initial

func present(model: RefCounted, number: int) -> void:
	var is_player: bool=model.player_turn()
	labels.round.text=App.texts.text("stands.hud.level",{"round":number,"levelCount":App.config.data.stands_gameplay.levels.values().filter(func(profile):return profile.enabled).size()})+" · "+App.texts.text(model.difficulty.name_key)
	labels.time.text=App.texts.text("stands.hud.time_left",{"seconds":ceili(maxf(0,model.difficulty.duration_seconds-model.elapsed))})
	if turn_seen!=model.turn_index:
		turn_seen=model.turn_index
		tug.set_turn(is_player)
		for id in ["player_turn","opponent_turn"]:
			var active: bool=is_player==(id=="player_turn")
			var team: Dictionary=left_team if id=="player_turn" else right_team
			plates[id].add_theme_stylebox_override("panel",UI.style(Color(team.primary_color) if active else UI.PAPER,UI.ACCENT if active else UI.INK,12))
			labels[id].add_theme_color_override("font_color",Color(team.text_color) if active else UI.INK)
			if active:App.animations.play(plates[id],"stands.turn_banner_swap")
			else:App.animations.animate_property(plates[id],^"modulate:a",plates[id].modulate.a,App.config.data.ui_animations.profiles["stands.inactive_stand_dim"].sourceSettings.target_opacity,"stands.inactive_stand_dim","enter")
		var chants: Array=App.config.data["ui.ru"].stands.chants
		labels.chant.text=str(chants[(model.turn_index/2) % chants.size()]) if is_player else App.texts.text("stands.turn.wait_caption")
		labels.chant.add_theme_font_size_override("font_size",App.config.data.stands_layout.fonts.chant if is_player else 28)
		App.animations.play(plates.chant,"stands.chant_caption_enter")
	tug.follow_score(model.score,model.finished)
