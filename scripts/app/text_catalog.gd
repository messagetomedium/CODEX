extends RefCounted

var catalog: Dictionary

func _init(source: Dictionary) -> void:
	catalog = source

func text(key: String, values: Dictionary = {}) -> String:
	var current: Variant = catalog
	for part in key.split("."):
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			push_error("Missing UI text: " + key)
			return "[" + key + "]"
	if not current is String:
		push_error("UI text is not a string: " + key)
		return "[" + key + "]"
	var formatted := values.duplicate()
	for parameter in formatted:
		var value: Variant = formatted[parameter]
		if value is float and value == floor(value):
			formatted[parameter] = int(value)
	return current.format(formatted)
