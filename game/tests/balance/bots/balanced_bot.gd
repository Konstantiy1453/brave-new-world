extends "res://tests/balance/bots/colony_bot.gd"
## A reasonable human: keeps 30 days of expenses, invests only when it pays back within 120 days.
## The decision logic and its defaults are in colony_bot.gd.

const YEAR_DAYS: int = 360


func _init() -> void:
	uses_services = true
	uses_transfer = true
	uses_commissions = true


## A year past the award tells the harness what it needs about the time after it.
func finished() -> bool:
	return (
		sim.state.status == "success"
		and int(sim.state.day) > int(sim.state.success_day) + YEAR_DAYS
	)
