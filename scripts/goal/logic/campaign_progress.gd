extends RefCounted
## Winning a round unlocks the next. Retry keeps earlier completed rounds.

var number := 1
var results: Array[Dictionary] = []
var total_rounds: int

func _init(config: Dictionary) -> void:
	total_rounds = config.rounds.size()

func record(progress: RefCounted) -> void:
	if not progress.finished or int(progress.rules.number) != number or results.size() >= number:
		return
	results.append({"round": number, "goals": progress.goals, "attempts": progress.attempts_used, "won": progress.goals >= int(progress.rules.goalTarget)})

func can_advance() -> bool:
	return results.size() == number and results.back().won and number < total_rounds

func game_won() -> bool:
	return number == total_rounds and results.size() == total_rounds and results.back().won

func advance() -> bool:
	if not can_advance():
		return false
	number += 1
	return true

func retry_round() -> void:
	if results.size() == number:
		results.pop_back()

func restart() -> void:
	number = 1
	results.clear()

func totals(config: Dictionary) -> Dictionary:
	var goals := 0
	var attempts := 0
	for result in results:
		goals += result.goals
		attempts += result.attempts
	return {"goals": goals, "goalTarget": int(config.round.goalTarget) * total_rounds, "attemptsUsed": attempts, "maxAttempts": int(config.round.maxAttempts) * total_rounds}
