extends Node
## Shared menu/level navigation; microphone ownership stays inside the active level.

const ConfigService = preload("res://scripts/app/config_service.gd")
const TextCatalog = preload("res://scripts/app/text_catalog.gd")
const AnimationController = preload("res://scripts/ui/ui_animation_controller.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")

var config = ConfigService.new()
var texts: RefCounted
var animations: RefCounted
var design_size := Vector2.ZERO
var valid := false
var changing_scene := false
var pending_scene := ""
var reset_button: Button

func _ready() -> void:
	valid = config.load_all()
	if not valid:
		var message := "Configuration error:\n" + "\n".join(config.errors)
		push_error(message)
		UI.label(self, message, Rect2(60, 60, 1600, 600), 28, Color.WHITE)
		return
	texts = TextCatalog.new(config.data["ui.ru"])
	animations = AnimationController.new(config.data.ui_animations.profiles)
	var resolution: Dictionary = config.data.ui_layout.baseResolution
	design_size = Vector2(resolution.width, resolution.height)
	var global_ui := CanvasLayer.new()
	global_ui.name = "GlobalUI"
	global_ui.layer = 100
	add_child(global_ui)
	var placement: Dictionary = config.data.ui_layout.positions["common.reset"]
	var dimensions: Dictionary = config.data.ui_layout.components.reset
	var button_size := design_size * Vector2(dimensions.widthFraction, dimensions.heightFraction)
	reset_button = UI.button(global_ui, texts.text("common.reset"), Rect2(design_size * Vector2(placement.x, placement.y) - Vector2(button_size.x, 0), button_size))
	reset_button.name = "Reset"
	reset_button.modulate.a = config.data.ui_animations.profiles["global.reset"].hover.from.opacity
	reset_button.pressed.connect(reset)
	reset_button.mouse_entered.connect(func(): animations.play(reset_button, "global.reset", "hover"))
	reset_button.mouse_exited.connect(func(): animations.play(reset_button, "global.reset", "hover", true))

func open_goal() -> void:
	_navigate("res://scenes/GoalLevel.tscn")

func reveal_level_hud(hud: Control) -> void:
	if not hud.visible:
		hud.show()
		animations.play(hud, "level.hud_enter")

func open_stands() -> void:
	_navigate("res://scenes/StandsLevel.tscn")

func reset() -> void:
	_navigate("res://scenes/MainMenu.tscn")

func _navigate(path: String) -> void:
	if not valid:
		return
	pending_scene = path
	if changing_scene:
		return
	changing_scene = true
	_change_scene.call_deferred()

func _change_scene() -> void:
	var path := pending_scene
	pending_scene = ""
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Scene change failed: " + path)
	changing_scene = false
