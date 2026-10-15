extends Control

const UI = preload("res://scripts/ui/ui_factory.gd")
const Illustration = preload("res://scripts/ui/illustration.gd")
var cards: Array[Button] = []

func _ready() -> void:
	if not App.valid:
		return
	var background := ColorRect.new()
	background.color = Color("#eee9dd")
	background.size = App.design_size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var layout: Dictionary = App.config.data.ui_layout.components.menu
	var catalog: Array = App.config.data["ui.ru"].menu.cards
	for i in catalog.size():
		var card_data: Dictionary = catalog[i]
		var button := Button.new()
		button.name = card_data.id.capitalize() + "Card"
		button.position = App.design_size * Vector2(layout.x + i * (layout.cardWidth + layout.gap), layout.y)
		button.size = App.design_size * Vector2(layout.cardWidth, layout.cardHeight)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not card_data.enabled
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", UI.style(UI.PAPER, UI.INK))
		button.add_theme_stylebox_override("hover", UI.style(Color.WHITE, UI.INK))
		button.add_theme_stylebox_override("pressed", UI.style(Color("#eee4cf"), UI.INK))
		button.add_theme_stylebox_override("disabled", UI.style(UI.PAPER, Color("#7f8c89")))
		add_child(button)
		cards.append(button)
		var inset := App.design_size.x * float(layout.inset)
		var image := Illustration.new()
		image.kind = card_data.id
		image.position = Vector2(inset, inset)
		image.size = Vector2(button.size.x - inset * 2, App.design_size.y * layout.imageHeight)
		button.add_child(image)
		UI.label(button, card_data.title, Rect2(inset, App.design_size.y * layout.titleY, button.size.x - inset * 2, App.design_size.y * layout.titleHeight), 36)
		UI.label(button, card_data.description, Rect2(inset, App.design_size.y * layout.descriptionY, button.size.x - inset * 2, App.design_size.y * layout.descriptionHeight), 23)
		if button.disabled:
			UI.label(button, App.texts.text("menu.disabledLabel"), Rect2(inset, App.design_size.y * layout.badgeY, button.size.x - inset * 2, 32), 20)
		else:
			button.pressed.connect(App.open_stands if card_data.id == "stands" else App.open_goal)
			button.mouse_entered.connect(func(): App.animations.play(button, "menu.card.enabled", "hover"))
			button.mouse_exited.connect(func(): App.animations.play(button, "menu.card.enabled", "hover", true))
		App.animations.play(button, "menu.card.disabled" if button.disabled else "menu.card.enabled")
