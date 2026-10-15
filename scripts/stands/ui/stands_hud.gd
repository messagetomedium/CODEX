extends Control
const UI = preload("res://scripts/ui/ui_factory.gd")
const Crest = preload("res://scripts/stands/ui/team_crest.gd")
const Geometry = preload("res://scripts/stands/logic/tug_geometry.gd")
const Tug = preload("res://scripts/stands/ui/tug_bar.gd")
var labels: Dictionary = {}
var plates: Dictionary = {}
var tug: Control
var meter: ProgressBar
var turn_seen := -1
var countdown_seen := -1
var peaks_seen := 0
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
	for id in ["switch","voice_label","peaks","tug_label","score","player_side","opponent_side","footnote"]:
		labels[id]=UI.label(self,"",rect(id),fonts.small if id in ["switch","footnote","player_side","opponent_side"] else fonts.label,UI.PAPER if id not in ["round","time"] else UI.INK)
	panel("player_name","",fonts.team)
	panel("opponent_name","",fonts.team)
	panel("player_turn",App.texts.text("stands.turn.player"),fonts.turn)
	panel("opponent_turn",App.texts.text("stands.turn.opponent"),fonts.turn)
	panel("chant","",fonts.chant)
	tug=Tug.new()
	tug.name="TugBar"
	tug.position=rect("tug").position
	tug.size=rect("tug").size
	tug.target_marker=App.config.data.stands_gameplay.score.visual_player_target_marker
	add_child(tug)
	var target_x: float = Geometry.marker_fraction(tug.target_marker)*tug.size.x
	UI.label(tug,App.texts.text("stands.hud.target_marker"),Rect2(target_x-115,-22,230,18),16,UI.ACCENT)
	meter=ProgressBar.new()
	meter.name="VoiceMeter"
	meter.position=rect("voice_meter").position
	meter.size=rect("voice_meter").size
	meter.show_percentage=false
	meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background",UI.style(Color("#3d604c"),UI.PAPER,5))
	meter.add_theme_stylebox_override("fill",UI.style(UI.ACCENT,Color.TRANSPARENT,5))
	add_child(meter)
	labels.voice_label.text=App.texts.text("stands.hud.voice_label")
	labels.tug_label.text=App.texts.text("stands.hud.tug_label")
	labels.player_side.text=App.texts.text("stands.hud.your_team")
	labels.opponent_side.text=App.texts.text("stands.hud.rival_team")
	labels.footnote.text=App.texts.text("stands.hud.sound_hint")

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
	countdown_seen=-1
	peaks_seen=0
	tug.value=App.config.data.stands_gameplay.score.initial

func present(model: RefCounted, number: int, level: float=0) -> void:
	var is_player: bool=model.player_turn()
	var turn: Dictionary=model.turns[model.turn_index]
	labels.round.text=App.texts.text("stands.hud.level",{"round":number,"levelCount":App.config.data.stands_gameplay.levels.values().filter(func(profile):return profile.enabled).size()})+" · "+App.texts.text(model.difficulty.name_key)
	labels.time.text=App.texts.text("stands.hud.time_left",{"seconds":ceili(maxf(0,model.difficulty.duration_seconds-model.elapsed))})
	labels.score.text=App.texts.text("stands.hud.score",{"score":snappedf(model.score,.1)})
	labels.peaks.text=App.texts.text("stands.hud.peaks",{"peaks":mini(model.peaks_count,int(model.difficulty.target_peaks)),"targetPeaks":model.difficulty.target_peaks})
	var countdown:=ceili(model.turn_remaining())
	labels.switch.text=App.texts.text("stands.turn.switch_in",{"seconds":countdown})+" · "+App.texts.text("stands.hud.turn_number",{"turn":model.turn_index+1,"turnCount":model.turns.size()})
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
	if countdown_seen!=countdown:
		countdown_seen=countdown
		App.animations.play(labels.switch,"stands.turn_countdown_tick")
	if peaks_seen!=model.peaks_count:
		if model.peaks_count>peaks_seen:App.animations.play(labels.peaks,"stands.peak_flash")
		peaks_seen=model.peaks_count
	tug.follow_score(model.score)
	App.animations.follow_value(meter,^"value",level*100 if is_player and not model.finished else 0.0,"stands.voice_meter_response")
