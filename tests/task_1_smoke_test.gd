extends SceneTree
## Integration checks for Tasks 0–1 only. No simulated microphone/gameplay.

var checks := 0
var failures: Array[String] = []
var app: Node

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int = 3) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	app = root.get_node("App")
	check(app.valid, "Application configuration must load")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/MainMenu.tscn", "MainMenu must be entry point")
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await frames()
	var menu: Control = current_scene
	check(menu.name == "MainMenu", "Menu loaded")
	check(menu.cards.size() == 3, "Exactly three cards")
	for i in 3:
		check(menu.cards[i].disabled == (i != 0), "Only first card is enabled")
		check(menu.cards[i].focus_mode == Control.FOCUS_NONE, "Mouse-only card selection")
		check(menu.cards[i].pressed.get_connections().size() == (1 if i == 0 else 0), "Disabled cards have no navigation handler")
	check(app.reset_button.get_parent().layer == 100, "Reset sits above all level overlays")
	check(app.reset_button.text == app.texts.text("common.reset"), "Reset uses catalog")
	menu.cards[0].pressed.emit()
	await frames()
	await create_timer(0.6).timeout
	var level: Node2D = current_scene
	check(level.name == "GoalLevel", "Goal card opens GoalLevel")
	check(level.state == level.State.INTRO, "Entry shows instruction state")
	check(level.world.visible, "World exists under overlay")
	check(level.world.get_child_count() == 4, "Independent goal, keeper, defender, ball")
	check(level.world.ball.position.x == app.design_size.x / 2, "Ball centered")
	check(level.world.goal.position.x == app.design_size.x / 2, "Goal centered")
	check(level.world.ball.position.y > level.world.goal.position.y, "Ball in foreground")
	check(level.world.ball.dimensions.x * 2 > app.design_size.x * 0.13, "Large foreground ball")
	var popup: Control = level.overlays.popup
	check(popup.instruction_items.size() == 3, "Exactly three infographic slots")
	check(popup.size.x < app.design_size.x and popup.size.y < app.design_size.y, "Popup only partially covers field")
	check(popup.get_global_rect().get_center().is_equal_approx(app.design_size / 2), "Intro centered using layout")
	for i in 3:
		var item: Control = popup.instruction_items[i]
		check(is_equal_approx(item.position.y, popup.instruction_items[0].position.y), "Infographics occupy one row")
		if i > 0:
			check(item.position.x > popup.instruction_items[i - 1].get_rect().end.x, "Infographic slots do not overlap")
	check(popup.action_buttons[0].text == app.texts.text("common.actions.start"), "Start uses catalog")
	check(level.hud.get_node("VoiceMeter").value == 0, "No fake voice input")
	var ball_position: Vector2 = level.world.ball.position
	var keeper_position: Vector2 = level.world.keeper.position
	popup.action_buttons[0].pressed.emit()
	await create_timer(0.6).timeout
	check(level.state == level.State.WAITING_FOR_TASK_2, "Start explicitly waits for later microphone task")
	check(level.overlays.popup.instruction_items.is_empty(), "Intro replaced within same reusable popup")
	check(level.world.ball.position == ball_position and level.world.keeper.position == keeper_position, "Start does not start gameplay")
	check(level.hud.get_node("Goals").text == app.texts.text("goal.hud.goals", {"goals": 0, "goalTarget": 3}), "No goals simulated")
	check(level.hud.get_node("Attempts").text == app.texts.text("goal.hud.attempts", {"attemptsUsed": 0, "maxAttempts": 6}), "No attempts consumed")
	app.reset_button.pressed.emit()
	await frames()
	check(current_scene.name == "MainMenu", "Reset from diagnostic state")
	app.reset_button.pressed.emit()
	await frames()
	check(current_scene.name == "MainMenu", "Reset from menu")
	app.open_goal()
	app.reset()
	await frames()
	check(current_scene.name == "MainMenu", "Reset overrides queued menu-to-level transition")
	app.open_goal()
	await frames()
	check(current_scene.state == current_scene.State.INTRO, "Fresh menu entry shows intro")
	app.reset_button.pressed.emit()
	await frames()
	check(current_scene.name == "MainMenu", "Reset during intro Tweens")
	app.open_goal()
	await frames()
	current_scene.overlays.popup.action_buttons[0].pressed.emit()
	app.reset_button.pressed.emit()
	await frames()
	await create_timer(0.4).timeout
	check(current_scene.name == "MainMenu", "Reset during exit Tween cancels stale transition")
	# Editing one profile to zero must immediately apply final state, even with delay.
	var animator = load("res://scripts/ui/ui_animation_controller.gd").new({"sample": {"enter": {"durationMs": 0, "delayMs": 1000, "from": {"opacity": 0, "yPx": 12}, "to": {"opacity": 1, "yPx": 0, "scale": 1}}}})
	var target := Control.new()
	target.position.y = 50
	root.add_child(target)
	animator.play(target, "sample")
	check(target.modulate.a == 1 and target.position.y == 50 and target.scale == Vector2.ONE, "Zero-duration profile applies final state immediately")
	var hover_animator = load("res://scripts/ui/ui_animation_controller.gd").new({"card": {"enter": {"durationMs": 200, "from": {"opacity": 0, "yPx": 18}, "to": {"opacity": 1, "yPx": 0}}, "hover": {"durationMs": 140, "from": {"scale": 1}, "to": {"scale": 1.025}}}})
	hover_animator.play(target, "card")
	hover_animator.play(target, "card", "hover")
	check(target.modulate.a == 1 and target.position.y == 50, "Early hover cannot freeze a transparent card")
	target.free()
	check(app.texts.text("goal.hud.round", {"round": 1.0}) == app.texts.text("goal.hud.round", {"round": 1}), "JSON whole numbers have no decimal suffix in UI")
	check(not FileAccess.file_exists("res://web/microphone_bridge.js"), "Task 2 remains unimplemented")
	print("Task 1 integration checks: ", checks, "; passed: ", checks - failures.size(), "; failed: ", failures.size())
	quit(0 if failures.is_empty() else 1)
