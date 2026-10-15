extends Control
signal team_selected(index: int)
const UI = preload("res://scripts/ui/ui_factory.gd")
const Crest = preload("res://scripts/stands/ui/team_crest.gd")
var selected := 0
var cards: Array[Button] = []
var teams: Array

func configure(initial: int) -> void:
	selected = initial

func _ready() -> void:
	teams = App.config.data.stands_teams.teams
	var layout: Dictionary = App.config.data.stands_layout.intro
	var unit: Vector2 = App.design_size
	var p: Array = layout.picker_rect
	position = Vector2(p[0], p[1]) * unit
	size = Vector2(p[2], p[3]) * unit
	UI.label(self, App.texts.text("stands.intro.team_picker_title"), Rect2(0, 0, size.x, unit.y * layout.title_height), 28)
	UI.label(self, App.texts.text("stands.intro.fictional_teams"), Rect2(0, unit.y * layout.hint_y, size.x, unit.y * layout.hint_height), 21)
	var gap: float = layout.gap * unit.x
	var w := (size.x - gap * (teams.size() - 1)) / teams.size()
	for i in teams.size():
		var team: Dictionary = teams[i]
		var button := UI.button(self, "", Rect2(i * (w + gap), unit.y * layout.cards_y, w, unit.y * layout.cards_height))
		button.name = team.id
		cards.append(button)
		var crest := Crest.new()
		crest.team = team
		crest.size = Vector2(w, unit.y * layout.crest_height)
		button.add_child(crest)
		var padding: float = layout.padding * unit.x
		UI.label(button, App.texts.text(team.name_key), Rect2(padding, unit.y * layout.name_y, w-padding*2, unit.y*layout.name_height), App.config.data.stands_layout.fonts.team_card_name)
		UI.label(button, team.era, Rect2(padding, unit.y*layout.era_y, w-padding*2, unit.y*layout.era_height), 22)
		var description := UI.label(button, App.texts.text(team.description_key), Rect2(padding, unit.y*layout.description_y, w-padding*2, unit.y*layout.description_height), App.config.data.stands_layout.fonts.team_card_description)
		description.name = "Description"
		description.size = Vector2(w-padding*2, unit.y*layout.description_height)
		description.clip_text = true
		button.pressed.connect(_select.bind(i))
		button.mouse_entered.connect(func(): App.animations.play(button, "stands.team_card_hover", "hover"))
		button.mouse_exited.connect(func(): App.animations.play(button, "stands.team_card_hover", "hover", true))
		App.animations.play(button, "stands.team_card_enter", "enter", false, i)
	UI.label(self, App.texts.text("stands.intro.campaign_hint"), Rect2(0,unit.y*layout.campaign_y,size.x,unit.y*layout.campaign_height),20)
	_refresh()

func _select(index: int) -> void:
	selected = index
	_refresh()
	App.animations.play(cards[index], "stands.team_card_selected", "hover")
	team_selected.emit(index)

func _refresh() -> void:
	for i in cards.size():
		var color := Color(teams[i].primary_color)
		var background := UI.PAPER.lerp(color, 0.12 if i == selected else 0.025)
		var style := UI.style(background, color if i == selected else Color("#b4beb6"), 15)
		style.set_border_width_all(5 if i == selected else 2)
		cards[i].add_theme_stylebox_override("normal", style)
