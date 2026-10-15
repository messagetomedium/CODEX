extends Control
## Short non-interactive event over the existing level, with independent profiles.

const UI = preload("res://scripts/ui/ui_factory.gd")
const Positioner = preload("res://scripts/ui/ui_positioner.gd")
const Burst = preload("res://scripts/ui/celebration_burst.gd")
var profile := ""
var closing := false
var celebration: Control

func configure(outcome: String, values: Dictionary, tip: String, protected: Array[Rect2]) -> void:
	var scored := outcome == "goal"
	profile = "goalEvent.panel" if scored else "failEvent.callout"
	var placement: Dictionary = App.config.data.ui_layout.eventPlacement
	var spec: Dictionary = placement.goal if scored else placement.fail
	var desired := App.design_size * Vector2(spec.maxWidthFraction, spec.heightFraction)
	var rect := Positioner.choose(desired, spec.candidates, protected, App.design_size, placement)
	assert(rect.has_area(), "No safe placement available for event notification")
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.style(UI.PAPER, UI.ACCENT if scored else UI.INK))
	add_child(panel)
	var layout: Dictionary = App.config.data.ui_layout.components.notification
	var inset: float = size.y * layout.contentInsetFraction
	var width: float = size.x - inset * 2
	var factor := size.x / desired.x
	if scored:
		celebration = Burst.new()
		celebration.size = size
		celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(celebration)
		App.animations.play(celebration, "world.goalCelebrationUI")
		var title := UI.label(self, App.texts.text("goal.event.goal.title"), Rect2(inset, inset, width, size.y * layout.titleHeightFraction), int(34 * factor))
		App.animations.play(title, "goalEvent.title")
		UI.label(self, App.texts.text("goal.event.goal.goals", values), Rect2(inset, size.y * layout.titleHeightFraction, width, size.y * layout.scoreHeightFraction), int(26 * factor))
		var advice := UI.label(self, tip, Rect2(inset, size.y * (layout.titleHeightFraction + layout.scoreHeightFraction), width, size.y * layout.tipHeightFraction), int(24 * factor))
		App.animations.play(advice, "goalEvent.tip")
	else:
		var title_height: float = size.y * layout.failTitleHeightFraction
		UI.label(self, App.texts.text("goal.event." + outcome + ".title"), Rect2(inset, inset, width, title_height - inset), int(24 * factor))
		UI.label(self, App.texts.text("goal.event." + outcome + ".subtitle"), Rect2(inset, title_height, width, size.y - title_height - inset), int(21 * factor))
	App.animations.play(self, profile)

func exit_seconds() -> float:
	return maxf(float(App.config.data.ui_animations.profiles[profile].exit.durationMs), float(App.config.data.ui_animations.profiles["world.goalCelebrationUI"].exit.durationMs) if is_instance_valid(celebration) else 0) / 1000.0

func begin_exit() -> void:
	if closing:
		return
	closing = true
	App.animations.play(self, profile, "exit")
	if is_instance_valid(celebration):
		App.animations.play(celebration, "world.goalCelebrationUI", "exit")
