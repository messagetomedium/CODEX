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
	UI.label(self, content.get("title", ""), Rect2(padding, unit.y * layout.titleY, size.x - padding * 2, unit.y * layout.titleHeight), 34)
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
			UI.label(item, item_data.title, Rect2(0, unit.y * layout.itemTitleY, item_width, unit.y * layout.itemTitleHeight), 25)
			UI.label(item, item_data.text, Rect2(0, unit.y * layout.itemTextY, item_width, unit.y * layout.itemTextHeight), 22)
			App.animations.play(item, "intro.instructionItem", "enter", false, i)
			App.animations.play(icon, "intro.visual.icon")
	var actions: Array = content.get("actions", [])
	var action_width: float = unit.x * layout.actionWidth
	var total_width: float = actions.size() * action_width
	for i in actions.size():
		var action: Dictionary = actions[i]
		var button := UI.button(self, action.label, Rect2((size.x - total_width) / 2 + i * action_width, unit.y * layout.actionY, action_width, unit.y * layout.actionHeight), true)
		button.name = action.id.capitalize()
		button.pressed.connect(func(): action_requested.emit(action.id))
		action_buttons.append(button)
