extends "res://tests/balance/bots/colony_bot.gd"
## The shortest path to the contract: spends everything, recruits as fast as beds allow, starts
## research at once and stops at the award. Guards the floor in §5.2.


func _init() -> void:
	uses_services = true
	uses_transfer = true
	uses_commissions = true
	uses_great_works = true
	uses_shuttle = true
	commission_all = true
	reserve_days = 2.0
	payback_limit = 700.0
	recruit_batch = 20
	recruit_buffer = 0.0
	science_target = 0.08
	lab_day = 1
	tech_order = ["adaptation", "survey", "education", "community_admin", "green_spaces"]


func finished() -> bool:
	return sim.state.status == "success"
