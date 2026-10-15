extends Control

signal action_requested(action_id: String)
const PopupScene = preload("res://ui/GameInfoPopup.tscn")
var popup: Control
var closing := false

func show_info(content: Dictionary, placement_id: String = "intro") -> void:
	if is_instance_valid(popup):
		remove_child(popup)
		popup.queue_free()
	closing = false
	var placement: Dictionary = App.config.data.ui_layout.positions[placement_id]
	popup = PopupScene.instantiate()
	popup.size = App.design_size * Vector2(placement.maxWidthFraction, minf(placement.maxHeightFraction, App.config.data.ui_layout.components.popup.heightFraction))
	popup.position = App.design_size * Vector2(placement.centerX, placement.centerY) - popup.size / 2
	add_child(popup)
	popup.configure(content)
	popup.action_requested.connect(func(id: String): action_requested.emit(id))
	App.animations.play(popup, "intro.panel")

func dismiss(on_closed: Callable) -> void:
	if closing or not is_instance_valid(popup):
		return
	closing = true
	for button in popup.action_buttons:
		button.disabled = true
	var tween: Tween = App.animations.play(popup, "intro.panel", "exit")
	if tween:
		tween.chain().tween_callback(_finish_dismiss.bind(on_closed))
	else:
		_finish_dismiss(on_closed)

func _finish_dismiss(on_closed: Callable) -> void:
	if is_instance_valid(popup):
		remove_child(popup)
		popup.queue_free()
		popup = null
	closing = false
	if on_closed.is_valid():
		on_closed.call()
