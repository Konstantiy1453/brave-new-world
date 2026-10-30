extends "res://tests/balance/bots/colony_bot.gd"
## Builds labs early, trains scientists and picks technologies first, money second.


func _init() -> void:
	reserve_days = 15.0
	payback_limit = 150.0
	science_target = 0.25
	lab_day = 1
	tech_order = [
		"survey", "adaptation", "irrigation", "education", "processing", "logistics", "efficiency"
	]


func finished() -> bool:
	return sim.state.status == "success"
