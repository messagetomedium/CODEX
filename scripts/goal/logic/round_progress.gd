extends RefCounted
## One charge on first movement; the sixth ball must resolve before the round ends.

var goals := 0
var attempts_used := 0
var attempts_resolved := 0
var started := false
var resolved := false
var finished := false
var rules: Dictionary

func _init(settings: Dictionary) -> void:
	rules = settings.round

func begin_movement(has_moved: bool) -> bool:
	if not has_moved or started or finished:
		return false
	started = true
	attempts_used += 1
	return true

func resolve(outcome: String) -> bool:
	if not started or resolved or finished or outcome not in ["goal", "intercept", "saved", "caught", "frame"]:
		return false
	resolved = true
	attempts_resolved += 1
	if outcome == "goal":
		goals += 1
	finished = goals >= int(rules.goalTarget) or attempts_resolved >= int(rules.maxAttempts)
	return true

func next_ball() -> bool:
	if not resolved or finished:
		return false
	started = false
	resolved = false
	return true

func values() -> Dictionary:
	return {"round": rules.number, "goalTarget": rules.goalTarget, "maxAttempts": rules.maxAttempts, "goals": goals, "attemptsUsed": attempts_used}
