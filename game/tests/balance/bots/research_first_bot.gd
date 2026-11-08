extends "res://tests/balance/bots/colony_bot.gd"
## Builds labs early, trains scientists and picks technologies first, money second.


func _init() -> void:
	uses_services = true
	uses_transfer = true
	reserve_days = 5.0
	payback_limit = 500.0
	science_target = 0.2
	research_full_income = 400.0
	lab_day = 1
	tech_order = [
		"education",
		"field_notes",
		"research_network",
		"lab_automation",
		"scientific_method",
		"research_institutes",
		"survey",
		"adaptation",
		"irrigation",
		"medicine",
		"processing",
		"logistics",
		"deep_mining",
		"electronics",
		"efficiency",
		"university",
		"deep_research"
	]


func finished() -> bool:
	return sim.state.status == "success"
