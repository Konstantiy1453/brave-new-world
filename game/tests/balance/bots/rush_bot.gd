extends "res://tests/balance/bots/colony_bot.gd"
## The shortest path to the contract: spends everything, recruits as fast as beds allow, starts
## research at once and stops at the award. Guards the floor in §5.2.


func _init() -> void:
	reserve_days = 5.0
	payback_limit = 200.0
	recruit_batch = 20
	recruit_buffer = 0.0
	science_target = 0.06
	population_goal = 240
	lab_day = 1
	tech_order = ["adaptation", "survey"]


func finished() -> bool:
	return sim.state.status == "success"
