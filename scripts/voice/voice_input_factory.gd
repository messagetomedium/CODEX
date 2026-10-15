extends RefCounted

const BrowserInput = preload("res://scripts/voice/browser_voice_input.gd")
const DebugInput = preload("res://scripts/voice/debug_voice_input.gd")

static func debug_enabled(config: Dictionary) -> bool:
	if not config.options.keyboardDebugModeAllowed:
		return false
	if OS.has_feature("web"):
		var page_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		var search := str(page_window.location.search).trim_prefix("?")
		for field in search.split("&"):
			var pair := field.split("=", true, 1)
			if pair[0].uri_decode() == "debug":
				return pair.size() == 2 and pair[1].uri_decode() == "1"
		return false
	return "--voice-debug" in OS.get_cmdline_user_args()

static func create(config: Dictionary) -> RefCounted:
	if debug_enabled(config):
		return DebugInput.new(config.devTesting)
	return BrowserInput.new(config.microphone)
