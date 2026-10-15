extends Control
## Replaceable content slots within one panel; never a full-screen scene.

signal action_requested(action_id: String)
const UI = preload("res://scripts/ui/ui_factory.gd")
const Illustration = preload("res://scripts/ui/illustration.gd")
var instruction_items: Array[Control] = []
var action_buttons: Array[Button] = []

func configure(content: Dictionary) -> void:
	var panel := Panel.new()
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.style(UI.PAPER, UI.INK, 24))
	add_child(panel)
	var compact: bool = content.get("instructionItems", []).is_empty()
	var layout_id: String = content.get("layoutId", "diagnostic" if compact else "popup")
	var layout: Dictionary = App.config.data.ui_layout.components[layout_id]
	var unit: Vector2 = App.design_size
	var padding: float = unit.x * layout.paddingFraction
	var result: bool = content.get("kind", "") in ["final", "intermediate"]
	var title := UI.label(self, content.get("title", ""), Rect2(padding, unit.y * layout.titleY, size.x - padding * 2, unit.y * layout.titleHeight), 44 if result else 34)
	if result:
		App.animations.play(title, content.get("headlineProfile", "final.headline"))
		var rows: Array = content.get("statistics", [])
		var statistics := Control.new()
		statistics.name = "Statistics"
		statistics.position = Vector2(padding, unit.y * layout.statsY)
		statistics.size = Vector2(size.x - padding * 2, unit.y * (layout.statHeight * maxi(1, rows.size()) + layout.statGap * maxi(0, rows.size() - 1)))
		statistics.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(statistics)
		for i in rows.size():
			UI.label(statistics, rows[i], Rect2(0, unit.y * i * (layout.statHeight + layout.statGap), statistics.size.x, unit.y * layout.statHeight), 32)
		App.animations.play(statistics, content.get("statsProfile", "final.stats"))
	UI.label(self, content.get("description", ""), Rect2(padding, unit.y * layout.objectiveY, size.x - padding * 2, unit.y * layout.objectiveHeight), 28)
	if not compact:
		var instructions: Array = content.instructionItems
		var gap: float = unit.x * layout.itemGapFraction
		var item_width := (size.x - padding * 2 - gap * (instructions.size() - 1)) / instructions.size()
		for i in instructions.size():
			var item_data: Dictionary = instructions[i]
			var item := Control.new()
			item.name = item_data.id.capitalize()
			item.position = Vector2(padding + i * (item_width + gap), unit.y * layout.rowY)
			item.size = Vector2(item_width, unit.y * layout.rowHeight)
			item.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(item)
			instruction_items.append(item)
			var icon := Illustration.new()
			icon.name = "VisualSlot"
			icon.kind = item_data.visual.iconId
			icon.size = Vector2(item_width, unit.y * layout.iconHeight)
			item.add_child(icon)
			UI.label(item, item_data.title, Rect2(0, unit.y * layout.itemTitleY, item_width, unit.y * layout.itemTitleHeight), content.get("instructionTitleFontSize", 25))
			UI.label(item, item_data.text, Rect2(0, unit.y * layout.itemTextY, item_width, unit.y * layout.itemTextHeight), 22)
			App.animations.play(item, content.get("instructionProfile", "intro.instructionItem"), "enter", false, i)
			App.animations.play(icon, content.get("iconProfile", "intro.visual.icon"))
	var extra: Control = content.get("extraContent")
	if extra != null:
		add_child(extra)
	var actions: Array = content.get("actions", [])
	var action_width: float = unit.x * layout.actionWidth
	var gap: float = unit.x * layout.get("actionGapFraction", 0)
	var total_width: float = actions.size() * action_width + max(0, actions.size() - 1) * gap
	var action_group := Control.new()
	action_group.name = "Actions"
	action_group.position = Vector2((size.x - total_width) / 2, unit.y * layout.actionY)
	action_group.size = Vector2(total_width, unit.y * layout.actionHeight)
	add_child(action_group)
	for i in actions.size():
		var action: Dictionary = actions[i]
		var button := UI.button(action_group, action.label, Rect2(i * (action_width + gap), 0, action_width, unit.y * layout.actionHeight), i == 0)
		button.name = action.id.capitalize()
		button.disabled = action.get("disabled", false)
		if button.disabled:
			button.modulate.a = 0.48
		else:
			button.pressed.connect(func(): action_requested.emit(action.id))
		action_buttons.append(button)
	if result:
		App.animations.play(action_group, content.get("actionsProfile", "final.actions"))
